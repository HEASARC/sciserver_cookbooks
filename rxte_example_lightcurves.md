---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.15.2
  kernelspec:
    display_name: (heasoft)
    language: python
    name: heasoft
---

# RXTE example

This notebook demonstrates an analysis of 16 years of RXTE data, which would be difficult outside of SciServer.  We extract all of the standard product lightcurves, but then we decide that we need different channel boundaries.  So we re-exctract light curves following the RXTE documentation and using the heasoftpy wrappers.  

```python
import sys,os, shutil
import pyvo as vo
import numpy as np
from astropy.io import fits
import matplotlib.pyplot as plt
%matplotlib inline  
import astropy.io.fits as pyfits
import datetime

# Ignore unimportant warnings
import warnings
warnings.filterwarnings('ignore', '.*Unknown element mirrorURL.*', 
                        vo.utils.xml.elements.UnknownElementWarning)
```

```python
import subprocess as subp
from packaging import version
import importlib
import heasoftpy as hsp
print(hsp.__file__)
```

### Step 1:  find the data

We can use the Virtual Observatory interfaces to the HEASARC to find the data we're  interested in.  Specifically, we want to look at the observation tables.  So first we get a list of all the tables HEASARC serves and then look for the ones related to RXTE:

```python
tap_services=vo.regsearch(servicetype='tap',keywords=['heasarc'])
heasarc_tables=tap_services[0].service.tables
```

```python
for tablename in heasarc_tables.keys():
    if "xte" in tablename:  
        print(" {:20s} {}".format(tablename,heasarc_tables[tablename].description))

```

The "xtemaster" catalog is the one that we're interested in.  

Let's see what this table has in it.  Alternatively, we can google it and find the same information here:

https://heasarc.gsfc.nasa.gov/W3Browse/all/xtemaster.html


```python
for c in heasarc_tables['xtemaster'].columns:
    print("{:20s} {}".format(c.name,c.description))
```

We're interested in Eta Carinae, and we want to get the RXTE cycle, proposal, and observation ID etc. for every observation it took of this source based on its position.  (Just in case the name has been entered differently, which can happen.)  This constructs a query in the ADQL language to select the columns (target_name, cycle, prnb, obsid, time, exposure, ra, dec) where the point defined by the observation's RA and DEC lies inside a circle defined by our chosen source position.  The results will be sorted by time.  See the [NAVO website](https://heasarc.gsfc.nasa.gov/vo/summary/python.html) for more information on how to use these services with python and how to construct ADQL queries for catalog searches.

```python
# Get the coordinate for Eta Car
import astropy.coordinates as coord
pos=coord.SkyCoord.from_name("eta car")
query="""SELECT target_name, cycle, prnb, obsid, time, exposure, ra, dec 
    FROM public.xtemaster as cat 
    where 
    contains(point('ICRS',cat.ra,cat.dec),circle('ICRS',{},{},0.1))=1 
    and 
    cat.exposure > 0 order by cat.time
    """.format(pos.ra.deg, pos.dec.deg)
```

```python
results=tap_services[0].search(query).to_table()
results
```

Let's just see how long these observations are:

```python
plt.plot(results['time'],results['exposure'])
```

###  Step 2:  combine standard products and plot

Let's collect all the standard product light curves for RXTE.  (These are described on the [RXTE analysis pages](https://heasarc.gsfc.nasa.gov/docs/xte/recipes/cook_book.html).)

```python
## Need cycle number as well, since after AO9, 
##  no longer 1st digit of proposal number
ids=np.unique( results['cycle','prnb','obsid','time'])
ids.sort(order='time')
ids
```

```python
## Construct a file list.
##  In this case, the name changes
import glob
# Though Jupyter Lab container
rootdir="/FTP"
# Through batch it shows up differently:  
#rootdir="/home/idies/workspace/HEASARC\ data"
rxtedata="rxte/data/archive"
filenames=[]
for (k,val) in enumerate(ids['obsid']):
    fname="{}/{}/AO{}/P{}/{}/stdprod/xp{}_n2a.lc.gz".format(
        rootdir,
        rxtedata,
        ids['cycle'][k],
        ids['prnb'][k],
        ids['obsid'][k],
        ids['obsid'][k].replace('-',''))
    #print(fname)
    f=glob.glob(fname)
    if (len(f) > 0):
        filenames.append(f[0])
print("Found {} out of {} files".format(len(filenames),len(ids)))
```

Let's collect them all into one light curve:

```python
hdul = fits.open(filenames.pop(0))
data = hdul[1].data
cnt=0
lcs=[]
for f in filenames:
    if cnt % 100 == 0:
        print("On file {}".format(f))
    hdul = fits.open(f)
    d = hdul[1].data
    data=np.hstack([data,d])
    plt.plot(d['TIME'],d['RATE'])
    lcs.append(d)
    cnt+=1
```

```python
hdul = fits.open(filenames.pop(0))
data = hdul[1].data
cnt=0
for f in filenames:
    hdul = fits.open(f)
    d = hdul[1].data
    data=np.hstack([data,d])
    if cnt % 100 == 0:
        print("On file {}".format(f))
        print("   adding {} rows from TSTART={}".format(d.shape[0],hdul[1].header['TSTARTI']))
    cnt+=1
## The above LCs are merged per proposal.  You can see that some proposals
##  had data added later, after other proposals, so you need to sort:
data.sort(order='TIME')

```

```python
plt.plot(data['TIME'],data['RATE'])

```

### Step 3:  Re-extract a light-curve

Now we go out and read about how to analyze RXTE data, and we decide that we need different channel boundaries than were used in the standard products.  We can write a little function that does the RXTE data analysis steps for every observation to extract a lightcurve and read it into memory to recreate the above dataset.  This function may look complicated, but it only calls three RXTE executables:

* pcaprepobsid
* maketime
* pcaextlc2

which extracts the Standard mode 2 data (not to be confused with the "standard products") for the channels you're interested in.  It has a bit of error checking that'll help when launching a long job.

Note that each call to this function will take 10-20 seconds to complete.  So when we run a whole proposal, we'll have to wait a while. 

```python

class XlcError( Exception ):
    pass


#  Define a function that, given an ObsID, does the rxte light curve extraction
def rxte_lc( obsid=None, ao=None , chmin=None, chmax=None, cleanup=True):
    rootdir="/home/idies/workspace/headata/FTP"
    rxtedata="rxte/data/archive"
    obsdir="{}/{}/AO{}/P{}/{}/".format(
        rootdir,
        rxtedata,
        ao,
        obsid[0:5],
        obsid
    )
    #print("Looking for obsdir={}".format(obsdir))
    outdir="tmp.{}".format(obsid)
    if (not os.path.isdir(outdir)):
        os.mkdir(outdir)

    if cleanup and os.path.isdir(outdir):
        shutil.rmtree(outdir,ignore_errors=True)

    try:
        #print("Running pcaprepobsid")
        result=hsp.pcaprepobsid(indir=obsdir,
                                outdir=outdir
                               )
        print(result.stdout)
        #  This one doesn't seem to return correctly, so this doesn't trap!
        if result.returncode != 0:
            raise XlcError("pcaprepobsid returned status {}".format(result.returncode))
    except:
        raise
    # Recommended filter from RTE Cookbook pages:
    filt_expr = "(ELV > 4) && (OFFSET < 0.1) && (NUM_PCU_ON > 0) && .NOT. ISNULL(ELV) && (NUM_PCU_ON < 6)"
    try:
        filt_file=glob.glob(outdir+"/FP_*.xfl")[0]
    except:
        raise XlcError("pcaprepobsid doesn't seem to have made a filter file!")

    try:
        #print("Running maketime")
        result=hsp.maketime(infile=filt_file, 
                            outfile=os.path.join(outdir,'rxte_example.gti'),
                            expr=filt_expr, name='NAME', 
                            value='VALUE', 
                            time='TIME', 
                            compact='NO')
        #print(result.stdout)
        if result.returncode != 0:
            raise XlcError("maketime returned status {}".format(result.returncode))
    except:
        raise
      
    try:
        #print("Running pcaextlc2")
        result=hsp.pcaextlc2(src_infile="@{}/FP_dtstd2.lis".format(outdir),
                             bkg_infile="@{}/FP_dtbkg2.lis".format(outdir),
                             outfile=os.path.join(outdir,'rxte_example.lc'), 
                             gtiandfile=os.path.join(outdir,'rxte_example.gti'),
                             chmin=chmin,
                             chmax=chmax,
                             pculist='ALL', layerlist='ALL', binsz=16)
        #print(result.stdout)
        if result.returncode != 0:
            raise XlcError("pcaextlc2 returned status {}".format(result.returncode))
    except:
        raise

    with pyfits.open(os.path.join(outdir,'rxte_example.lc'),memmap=False) as hdul:
        lc=hdul[1].data
    if cleanup:
        shutil.rmtree(outdir,ignore_errors=True)
    return lc

```

Let's look just at a small part of the time range, and look at only the first few for speed:

```python
break_at=10
for (k,val) in enumerate(ids):
    if k>break_at:  break
    l=rxte_lc(ao=val['cycle'], obsid=val['obsid'], chmin="5",chmax="10")    
    try:
        lc=np.hstack([lc,l])
    except:
        lc=l
        
```

```python
# Because the obsids won't necessarily be processed in time order
lc.sort(order='TIME')
```

```python
plt.plot(lc['TIME'],lc['RATE'])
```

```python
hdu = pyfits.BinTableHDU(lc)
pyfits.HDUList([pyfits.PrimaryHDU(),hdu]).writeto('eta_car.lc',overwrite=True)

```

You could then remove the break in the above loop and submit this job to the [batch queue](https://apps.sciserver.org/compute/jobs).

```python

```
