---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.16.0
  kernelspec:
    display_name: (heasoft)
    language: python
    name: conda-env-heasoft-py
---

# RXTE Lightcurve Exctraction On Sciserver with Parallelization
<hr style="border: 2px solid #fadbac" />

- **Description:** Finding data and extracting light curves from RXTE data, with an example of running tasks in parallel.
- **Level:** Advanced.
- **Data:** RXTE observations of **eta car** taken over 16 years.
- **Requirements:** `heasoftpy`, `pyvo`, `matplotlib`, `tqdm`
- **Credit:** Tess Jaffe (Sep 2021). Parallelization by Abdu Zoghbi (Jan 2024)
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 02/28/2024.

<hr style="border: 2px solid #fadbac" />


## 1. Introduction

This notebook demonstrates an analysis of 16 years of RXTE data, which would be difficult outside of SciServer. 

The RXTE archive contain standard data product that can be used without re-processing the data. These are described in details in the [RXTE ABC guide](https://heasarc.gsfc.nasa.gov/docs/xte/abc/front_page.html).

We first find all of the standard product light curves. Then, realizing that the channel boundaries in the standard data products do not address our science question, we re-extract light curves following the RXTE documentation and using `heasoftpy`.

As we will see, a single run on one observations takes about 20 seconds, which means that extracting all observations takes about a week. We will show an example of how this can be overcome by parallizing the analysis, reducing the run time from weeks to a few hours.

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br>
Also, this notebook requires <code>heasoftpy</code>, which is available in the (heasoft) conda environment. You should see (heasoft) at the top right of the notebook. If not, click there and select it.

<b>Running Outside Sciserver:</b><br>
If running outside Sciserver, some changes will be needed, including:<br>
&bull; Make sure heasoftpy and heasoft are installed (<a href='https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/'>Download and Install heasoft</a>).<br>
&bull; Unlike on Sciserver, where the data is available locally, you will need to download the data to your machine.<br>
</div>


## 2. Module Imports
We need the following python modules:


```python
import sys, os, shutil
import glob
import pyvo as vo
import numpy as np
from astropy.io import fits
from astropy.coordinates import SkyCoord
import matplotlib.pyplot as plt
import datetime

# tqdm is needed to show progress
from tqdm import tqdm

import heasoftpy as hsp

# for prallelization
import multiprocessing as mp
```

## 3. Find the Data

To find the relevent data, we can use [Xamin](https://heasarc.gsfc.nasa.gov/xamin/), the HEASARC web portal, or the Virtual Observatory (VO) python client `pyvo`. Here, we use the latter so it is all in one notebook.

You can also see the [Getting Started](getting-started.md), [Data Access](data-access.md) and  [Finding and Downloading Data](data-find-download.md) tutorials for examples using `pyVO` to find the data.

Specifically, we want to look at the observation tables.  So first we get a list of all the tables HEASARC serves and then look for the ones related to RXTE:

```python
tap_services = vo.regsearch(servicetype='tap', keywords=['heasarc'])
heasarc_tables = tap_services[0].service.tables
```

```python
for tablename in heasarc_tables.keys():
    if "xte" in tablename:  
        print(" {:20s} {}".format(tablename,heasarc_tables[tablename].description))

```

The `xtemaster` catalog is the one that we are interested in.  

Let's see what this table has in it.  Alternatively, we can google it and find the same information here:

https://heasarc.gsfc.nasa.gov/W3Browse/all/xtemaster.html


```python
for c in heasarc_tables['xtemaster'].columns:
    print("{:20s} {}".format(c.name,c.description))
```

We're interested in Eta Carinae, and we want to get the RXTE `cycle`, `proposal`, and `obsid`. for every observation it took of this source based on its position.  We use the source positoin instead of the name in case the name has been entered differently in the table, which can happen. 

We construct a query in the ADQL language to select the columns (`target_name`, `cycle`, `prnb`, `obsid`, `time`, `exposure`, `ra` and `dec`) where the point defined by the observation's RA and DEC lies inside a circle defined by our chosen source position.

For more example on how to use these powerful VO services, see the [Data Access](data-access.md) and  [Finding and Downloading Data](data-find-download.md) tutorials, or the [NAVO](https://heasarc.gsfc.nasa.gov/vo/summary/python.html) [workshop tutorials](https://nasa-navo.github.io/navo-workshop/).

```python
# Get the coordinate for Eta Car
pos = SkyCoord.from_name("eta car")
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
plt.xlabel('Time (s)')
plt.ylabel('Exposure (s)')
```

## 4. Read the Standard Products and Plot the Light Curve

Let's collect all the standard product light curves for RXTE.  (These are described on the [RXTE analysis pages](https://heasarc.gsfc.nasa.gov/docs/xte/recipes/cook_book.html).)

```python
## Need cycle number as well, since after AO9, 
##  no longer 1st digit of proposal number
ids = np.unique( results['cycle','prnb','obsid','time'])
ids.sort(order='time')
ids
```

```python
## Construct a file list.
rxtedata = "/FTP/rxte/data/archive"
filenames = []
for (k,val) in enumerate(tqdm(ids['obsid'], total=len(ids))):
    fname = "{}/AO{}/P{}/{}/stdprod/xp{}_n2a.lc.gz".format(
        rxtedata,
        ids['cycle'][k],
        ids['prnb'][k],
        ids['obsid'][k],
        ids['obsid'][k].replace('-',''))
    
    # keep only files that exist
    if os.path.exists(fname):
        filenames.append(fname)
print("Found {} out of {} files".format(len(filenames), len(ids)))
```

Let's collect them all into one light curve:

```python
lcurves = []
for file in tqdm(filenames):
    with fits.open(file) as hdul:
        data = hdul[1].data
        lcurves.append(data)
    plt.plot(data['TIME'], data['RATE'])
```

```python
# combine the ligh curves into one
lcurve = np.hstack(lcurves)

# The above LCs are merged per proposal.  You can see that some proposals
# had data added later, after other proposals, so you need to sort:
lcurve.sort(order='TIME')

# plot the light curve
plt.plot(lcurve['TIME'], lcurve['RATE'])

```

## 4. Re-extract the Light Curve

Let's say we find that we need different channel boundaries than were used in the standard products.  We can write a function that does the RXTE data analysis steps for every observation to extract a lightcurve and read it into memory to recreate the above dataset.  This function may look complicated, but it only calls three RXTE executables:

* `pcaprepobsid`
* `maketime`
* `pcaextlc2`

which extracts the Standard mode 2 data (not to be confused with the "standard products") for the channels we are interested in.  It has a bit of error checking that'll help when launching a long job.


```python

class XlcError(Exception):
    pass


#  Define a function that, given an ObsID, does the rxte light curve extraction
def rxte_lc(obsid=None, ao=None , chmin=None, chmax=None, cleanup=True):
    rxtedata = "/FTP/rxte/data/archive"
    obsdir = "{}/AO{}/P{}/{}/".format(
        rxtedata,
        ao,
        obsid[0:5],
        obsid
    )
    outdir = f"tmp.{obsid}"
    if (not os.path.isdir(outdir)):
        os.mkdir(outdir)

    if cleanup and os.path.isdir(outdir):
        shutil.rmtree(outdir, ignore_errors=True)

    result = hsp.pcaprepobsid(indir=obsdir, outdir=outdir)
    if result.returncode != 0:
        raise XlcError(f"pcaprepobsid returned status {result.returncode}.\n{result.stdout}")

    # Recommended filter from RTE Cookbook pages:
    filt_expr = "(ELV > 4) && (OFFSET < 0.1) && (NUM_PCU_ON > 0) && .NOT. ISNULL(ELV) && (NUM_PCU_ON < 6)"
    try:
        filt_file = glob.glob(outdir+"/FP_*.xfl")[0]
    except:
        raise XlcError("pcaprepobsid doesn't seem to have made a filter file!")

    result = hsp.maketime(
        infile=filt_file, 
        outfile=os.path.join(outdir,'rxte_example.gti'),
        expr=filt_expr, name='NAME', 
        value='VALUE', 
        time='TIME', 
        compact='NO'
    )
    if result.returncode != 0:
        raise XlcError(f"maketime returned status {result.returncode}.\n{result.stdout}")
      
    # Running pcaextlc2
    result = hsp.pcaextlc2(
        src_infile="@{}/FP_dtstd2.lis".format(outdir),
        bkg_infile="@{}/FP_dtbkg2.lis".format(outdir),
        outfile=os.path.join(outdir,'rxte_example.lc'), 
        gtiandfile=os.path.join(outdir,'rxte_example.gti'),
        chmin=chmin,
        chmax=chmax,
        pculist='ALL', layerlist='ALL', binsz=16
    )

    if result.returncode != 0:
        raise XlcError(f"pcaextlc2 returned status {result.returncode}.\n{result.stdout}")

    with fits.open(os.path.join(outdir,'rxte_example.lc')) as hdul:
        lc = hdul[1].data
    
    if cleanup:
        shutil.rmtree(outdir,ignore_errors=True)
    
    return lc

```

Note that each call to this function will take 10-20 seconds to complete.  Extracting all the observations will take a while, so we limit this run for 10 observations. We will look into running this in parallel in the next step.

Our new light curves will be for channels 5-10

```python
# For this tutorial, we limit the number of observations to 10
nlimit = 10
lcurves = []
for (k,val) in tqdm(enumerate(ids[:nlimit])):
    lc = rxte_lc(obsid=val['obsid'], ao=val['cycle'], chmin="5", chmax="10", cleanup=True)
    lcurves.append(lc)
lcurve = np.hstack(lcurves)
```

## 5. Running the Extraction in Parallel.
As noted, extracting the light curves for all observations will take a while if run in serial. We will look next into parallizing the `rxte_lc` calls. We will use the `multiprocessing` python module.

We do this by first creating a wrapper around `rxte_lc` that does a few things:

- Use `local_pfiles_context` in `heasoftpy` to properly handle parameter files used by the heasoft tasks. This step is required to prevent parallel calls to `rxte_lc` from reading or writing to the same parameter files that ca lead to calls with the wrong parameters.
- Convert `rxte_lc` from multi-parameter method to a single one, so `multiprocessing` can handle it.
- Catch all errors in the `rxte_lc` call.

We will use all CPUs available in the machine. This can be changing the value of `ncpu`.

```python
def rxte_lc_wrapper(pars):
    """A wrapper around rxte_lc so it can be called in parallel

    pars: (obsid, ao, chmin, chmax, cleanup)
    
    """
    obsid, ao, chmin, chmax, cleanup = pars
    
    # the following is needed so the parameter files
    # in parallel calls do not read or write the same file
    with hsp.utils.local_pfiles_context():
        try:
            lc = rxte_lc(obsid, ao, chmin, chmax, cleanup)
        except XlcError:
            lc = None
    return lc
```

Before running the function in parallel, we construct a list `pars` that holds the parameters that will be passed to `rxte_lc_wrapper` (and hence rxte_lc).

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<code>nlimit</code> is now increased to 64. When you run this in full, change the limit to the number of observations
</div>


```python
nlimit = 64
ncpu = mp.cpu_count()
pars = []
for (k,val) in enumerate(ids[:nlimit]):
    pars.append([val['obsid'], val['cycle'], "5", "10", True])

with mp.Pool(processes=ncpu) as pool:
    lcs = pool.map(rxte_lc_wrapper, pars)
```

```python
# combine the ligh curves into one
lcurve = np.hstack(lcs)

# The above LCs are merged per proposal.  You can see that some proposals
# had data added later, after other proposals, so you need to sort:
lcurve.sort(order='TIME')

# plot the light curve
plt.figure(figsize=(8,4))
plt.plot(lcurve['TIME'], lcurve['RATE'])
plt.xlabel('Time (s)')
plt.ylabel('Rate ($s^{-1}$)')
```

With the parallelization, we can do more observations at a fraction of the time.

If you want run this notebook on all observations, you can comment out the two cell that runs in serial (the cell below where `rxte_lc` is defined), and submit this notebook in the [batch queue](https://apps.sciserver.org/compute/jobs) on Sciserver.

```python

```
