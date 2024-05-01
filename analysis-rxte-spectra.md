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

# RXTE Spectral Extraction Example
<hr style="border: 2px solid #fadbac" />

- **Description:** Finding standard spectral products from RXTE.
- **Level:** Intermediate.
- **Data:** RXTE observations of **eta car** taken over 16 years.
- **Requirements:** `pyvo`, `matplotlib`, `pyxspec`
- **Credit:** Tess Jaffe (Sep 2021).
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 01/26/2024.

<hr style="border: 2px solid #fadbac" />


## 1. Introduction
This notebook demonstrates an analysis of 16 years of RXTE spectra of Eta Car. 

The RXTE archive contain standard data product that can be used without re-processing the data. These are described in details in the [RXTE ABC guide](https://heasarc.gsfc.nasa.gov/docs/xte/abc/front_page.html).

We first find all of the standard spectra, then use `pyxspec` to do some basic analysis.

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br>

<b>Running Outside Sciserver:</b><br>
If running outside Sciserver, some changes will be needed, including:<br>
&bull; Make sure <code>pyxspec</code> and heasoft are installed (<a href='https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/'>Download and Install heasoft</a>).<br>
&bull; Unlike on Sciserver, where the data is available locally, you will need to download the data to your machine.<br>
</div>


## 2. Module Imports
We need the following python modules:


```python
import os
import pyvo as vo
import numpy as np
from tqdm import tqdm
import matplotlib.pyplot as plt
import astropy.io.fits as fits
from astropy.coordinates import SkyCoord
import xspec
```

## 3. Find the Data

To find the relevent data, we can use [Xamin](https://heasarc.gsfc.nasa.gov/xamin/), the HEASARC web portal, or the Virtual Observatory (VO) python client `pyvo`. Here, we use the latter so it is all in one notebook.

You can also see the [Getting Started](getting-started.md), [Data Access](data-access.md) and  [Finding and Downloading Data](data-find-download.md) tutorials for examples using `pyVO` to find the data.

Specifically, we want to look at the observation tables.  So first we get a list of all the tables HEASARC serves and then look for the ones related to RXTE:

```python
#  First query the Registry to get the HEASARC TAP service.
tap_services=vo.regsearch(servicetype='tap',keywords=['heasarc'])
#  Then query that service for the names of the tables it serves.
heasarc_tables=tap_services[0].service.tables

for tablename in heasarc_tables.keys():
    if "xte" in tablename:  
        print(" {:20s} {}".format(tablename,heasarc_tables[tablename].description))
 
```

Query the `xtemaster` catalog for observations of **Eta Car**

```python
# Get the coordinate for Eta Car
pos = SkyCoord.from_name("eta car")

query = """SELECT target_name, cycle, prnb, obsid, time, exposure, ra, dec 
    FROM public.xtemaster as cat 
    where 
    contains(point('ICRS',cat.ra,cat.dec),circle('ICRS',{},{},0.1))=1 
    and 
    cat.exposure > 0 order by cat.time
    """.format(pos.ra.deg, pos.dec.deg)
results = tap_services[0].search(query).to_table()
results
```

```python
# Keep the unique combination of these columns
ids = np.unique( results['cycle','prnb','obsid'])
ids
```

At this point, you need to construct a file list.  There are a number of ways to do this, but this one is just using our knowledge of how the RXTE archive is structured.

```python
## Construct a file list.
rxtedata = "/FTP/rxte/data/archive"
filenames = []
for id in tqdm(ids):
    fname = "{}/AO{}/P{}/{}/stdprod/xp{}_s2.pha.gz".format(
        rxtedata,
        id['cycle'],
        id['prnb'],
        id['obsid'],
        id['obsid'].replace('-',''))
    # keep only files that exist in the archive
    if os.path.exists(fname):
        filenames.append(fname)
print(f"Found {len(filenames)} out of {len(ids)} files")
```

Now we have to use [PyXspec](https://heasarc.gsfc.nasa.gov/xanadu/xspec/python/html/quick.html) to convert the spectra into physical units. The spectra are read into a list `spectra` that contain enery values, their error (from the bin size), the counts (counts cm$^{-2}$ s$^{-1}$ keV$^{-1}$) and their uncertainities.  Then we use Matplotlib to plot them, since the Xspec plotter is not available here.  

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
The background and response files are set in the header of each spectral file. So before reading a spectrum, we change directory to the location of the file so those files can be read correctly, then move back to the working directory.

We also set the <code>chatter</code> paramter to 0 to reduce the printed text given the large number of files we are reading.
</div>

```python

xspec.Xset.chatter = 0

# other xspec settings
xspec.Plot.area = True
xspec.Plot.xAxis = "keV"
xspec.Plot.background = True

# save current working location
cwd = os.getcwd()

# number of spectra to read. We limit it to 500. Change as desired.
nspec = 500

# The spectra will be saved in a list
spectra = []
for file in tqdm(filenames[:nspec]):
    # clear out any previously loaded dataset
    xspec.AllData.clear()
    # move to the folder containing the spectrum before loading it
    os.chdir(os.path.dirname(file))
    spec = xspec.Spectrum(file)
    os.chdir(cwd)

    xspec.Plot("data")
    spectra.append([xspec.Plot.x(), xspec.Plot.xErr(),
                    xspec.Plot.y(), xspec.Plot.yErr()])

```

```python
# Now we plot the spectra

fig = plt.figure(figsize=(10,6))
for x,xerr,y,yerr in spectra:
    plt.loglog(x, y, linewidth=0.2)
plt.xlabel('Energy (keV)')
plt.ylabel(r'counts cm$^{-2}$ s$^{-1}$ keV$^{-1}$')
```

You can at this stage start adding spectral models using `pyxspec`, or model the spectra in others ways that may include Machine Learning modeling similar to the [Machine Learning Demo](model-rxte-ml.md)

If you prefer to use the Xspec built-in functionality, you can do so by plotting to a file (e.g. GIF as we show below).

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
