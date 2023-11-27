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

# A simple RXTE spectral extraction example

Here we just show how to get a list of RXTE observations of a given source, construct a file list to the standard products, and extract spectra in physical units using PyXspec.

```python
import sys,os,glob
import pyvo as vo
import numpy as np
import matplotlib.pyplot as plt
%matplotlib inline  
import astropy.io.fits as fits
import xspec
xspec.Xset.allowPrompting = False 
# Ignore unimportant warnings
import warnings
warnings.filterwarnings('ignore', '.*Unknown element mirrorURL.*', 
                        vo.utils.xml.elements.UnknownElementWarning)
```

First query the HEASARC for its catalogs related to XTE.  For more on using PyVO to find observations, see [NAVO's collection of notebook tutorials](https://nasa-navo.github.io/navo-workshop/).  

```python
#  First query the Registry to get the HEASARC TAP service.
tap_services=vo.regsearch(servicetype='tap',keywords=['heasarc'])
#  Then query that service for the names of the tables it serves.
heasarc_tables=tap_services[0].service.tables

for tablename in heasarc_tables.keys():
    if "xte" in tablename:  
        print(" {:20s} {}".format(tablename,heasarc_tables[tablename].description))
 
```

Query the xtemaster catalog for observations of Eta Car

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
results=tap_services[0].search(query).to_table()
results
```

```python
## Need cycle number as well, since after AO9, 
##  no longer 1st digit of proposal number
ids=np.unique( results['cycle','prnb','obsid'])
ids
```

At this point, you need to construct a file list.  There are a number of ways to do this, but this one is just using our knowledge of how the RXTE archive is structured.  This code block limits the results to a particular proposal ID to make this quick, but you could remove that restriction and wait longer:

```python
## Construct a file list.
rootdir="/FTP"
rxtedata="rxte/data/archive"
filenames=[]
for (k,val) in enumerate(ids['obsid']):
    #  Skip some for a quicker test case
    if ids['prnb'][k]!=80001:
        continue
    fname="{}/{}/AO{}/P{}/{}/stdprod/xp{}_s2.pha.gz".format(
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

```python
print(type(ids['obsid'][k]))
print(type('-'))
import inspect,astropy
inspect.getfile(astropy)
```

Now we have to use our knowledge of [PyXspec](https://heasarc.gsfc.nasa.gov/xanadu/xspec/python/html/quick.html) to convert the spectra into physical units.  Then we use Matplotlib to plot, since the Xspec plotter is not available here.  

(Note that there will be errors when the code tries to read in the background and response files from the working directory.  We then specify them explicitly.)  

```python
dataset=[]
xref=np.arange(0.,50.,1)
for f in filenames[0:500]:
    xspec.AllData.clear()  # clear out any previously loaded dataset
    ## Ignore the errors it will print about being unable
    ##  to find response or background
    s = xspec.Spectrum(f)
    ## Then specify with the correct path.  
    s.background=f.replace("_s2.pha","_b2.pha")
    s.response=f.replace("_s2.pha",".rsp")
    xspec.Plot.area=True
    xspec.Plot.xAxis = "keV"
    xspec.Plot.add = True
    xspec.Plot("data")
    xspec.Plot.background = True
    xVals = xspec.Plot.x()
    yVals = xspec.Plot.y()
    yref= np.interp(xref, xVals, yVals) 
    dataset.append( yref )

```

```python
fig, ax = plt.subplots(figsize=(10,6))

for s in dataset:
    ax.plot(xref,s)
ax.set_xlabel('Energy (keV)')
ax.set_ylabel(r'counts/cm$^2$/s/keV')
ax.set_xscale("log")
ax.set_yscale("log")
```

And now you can put these into your favorite spectral analysis program like [PyXspec](https://heasarc.gsfc.nasa.gov/xanadu/xspec/python/html/quick.html) or into an AI/ML analysis following [our lightcurve example](rxte_example_lightcurves.ipynb).

If you prefer to use the Xspec plot routines, you can do so but only using an output file.  It cannot open a window through a notebook running on SciServer.  So here's an example using a GIF output file and then displaying the result in the notebook:

```python
xspec.Plot.splashPage=None
xspec.Plot.device='spectrum.gif/GIF'
xspec.Plot.xLog = True
xspec.Plot.yLog = True
xspec.Plot.background = False
xspec.Plot()
xspec.Plot.device='/null'
```

```python
from IPython.display import Image
with open('spectrum.gif','rb') as f:
    display(Image(data=f.read(), format='gif',width=500))
```

```python

```
