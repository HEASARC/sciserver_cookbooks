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

# NuSTAR Lightcurve Extraction On Sciserver
<hr style="border: 2px solid #fadbac" />

- **Description:** Run NuSTAR pipeline and extract light curve products.
- **Level:** Beginner.
- **Data:** NuSTAR observation of **SWIFT J2127.4+5654** (obsid = 60001110002)
- **Requirements:** `heasoftpy`, `numpy`, `matplotlib`
- **Credit:** Abdu Zoghbi (Jan 2023).
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 02/28/2024.

<hr style="border: 2px solid #fadbac" />


## An Example Analysing NuSTAR Data One Sciserver

In this tutorial, we will go through the steps of analyzing NuSTAR observation of the AGN in center of `SWIFT J2127.4+5654` with `obsid = 60001110002` using `heasoftpy`.

We will run the NuSTAR pipeline to reprocess the data and then extract a light curve.

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br>
Also, this notebook requires <code>heasoftpy</code>, which is available in the (heasoft) conda environment. You should see (heasoft) at the top right of the notebook. If not, click there and select it.

<br> <br>

<b>Running Outside Sciserver:</b><br>
If running outside Sciserver, some changes will be needed, including:<br>
&bull; Make sure heasoftpy and heasoft are installed (<a href='https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/'>Download and Install heasoft</a>).<br>
&bull; Unlike on Sciserver, where the data is available locally, you will need to download the data to your machine.<br>
</div>


## 2. Module Imports
We need the following python modules:

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
Note that for heasoftpy < 1.4, <code>nupipeline</code> is accessed via <code>heasoftpy.nupipeline</code>. For heasoftpy >= 1.4, it is available under a separate module called <code>nustar</code> that needs to be imported explicitly.
</div>

```python
import os
import sys
import numpy as np
import matplotlib.pyplot as plt

import heasoftpy as hsp

# import nupipeline from heasoftpy
# for heasoftpy version >= 1.4, it is under heasoftpy.nustar.nupipeline
# for heasoftpy version < 1.4, it is under heasoftpy.nupipeline
try:
    from heasoftpy.nustar import nupipeline
except ModuleNotFoundError:
    from heasoftpy import nupipeline

```

## 3. Run the Reprocessing Pipeline

We are interested in *NuSTAR* observation `60001110002`. To obtain the full path to the data directory, we can use [Xamin](https://heasarc.gsfc.nasa.gov/xamin/) and select `FTP Paths` in `Data Products Cart` to find the path:  `/FTP/nustar/data/obs/00/6//60001110002/`. 

You can also see the [Getting Started](getting-started.md), [Data Access](data-access.md) and  [Finding and Downloading Data](data-find-download.md) tutorials for examples using `pyVO` to find the data.

On Sciserver, all the data is available locally in the path `/FTP/...`.

In the case of *NuSTAR*, we don't even have to copy the data. We can call the pipleline tool using that data path.

```python

obsid = '60001110002'
path  = f'/FTP/nustar/data/obs/00/6/{obsid}/'
```

<!-- #region -->
Next, we use `nupipeline` to process the data ([see detail here](https://heasarc.gsfc.nasa.gov/lheasoft/ftools/caldb/help/nupipeline.html)).


To run `nupipeline`, only three parameters are needed: `indir`, `outdir` and `steminput`. By default, calling the task will also query for other parameters. We can instruct the task to use default values by setting `noprompt=True`.

We will also request the output to be logged to the screen by setting `verbose=True`.

For the purposes of illustrations in this tutorial, we will focus on the `FMPA` instrument.

If we use `outdir='60001110002_p/event_cl'`, the call may look something like:

<!-- #endregion -->

```python

# set some parameters.
indir  = path
outdir = obsid + '_p/event_cl'
stem   = 'nu' + obsid

# call the tasks
out = nupipeline(indir=indir, outdir=outdir, steminputs=stem, instrument='FPMA',
                        clobber='yes', noprompt=True, verbose=True)
```

After running for some time, and if things run smoothly, the last a few lines of the output may contain a message like:

```
=============================================================================================
nupipeline_0.4.9: Exit with no errors - ...

=============================================================================================
```

A return code `out.returncode` of `0`, indicates that the task run with success!

```python
print('return code:', out.returncode)
```

<!-- #region -->
The main cleaned event files are: `nu60001110002A01_cl.evt` and `nu60001110002B01_cl.evt` for NuSTAR modules `A` and `B`, respectively.


---
Note that the same results can acheived by using the parameters as attributes of the tasks:

```python

nupipeline = hsp.HSPTask('nupipeline')

nupipeline.indir = indir
nupipeline.outdir = obsid + '_p/event_cl'
nupipeline.steminput = 'nu' + obsid
nupipeline(noprompt=True, verbose=True)

```
<!-- #endregion -->

---
## 4. Extract a Light Curve
Now that we have data processed, we can proceed and extract a light curve for the source. For this, we use `nuproducts` (see [nuproducts](https://heasarc.gsfc.nasa.gov/lheasoft/ftools/caldb/help/nuproducts.html) for details)

First, we need to create a source and background region files.

The source regions is a circle centered on the source with a radius of 150 arcseconds, while the background region is an annulus with an inner and outer radii of 180 and 300 arcseconds, respectively.

```python
# write region files
region = 'circle(21:27:46.406,+56:56:31.38,150")'
with open('src.reg', 'w') as fp: fp.write(region)

region = 'annulus(21:27:46.406,+56:56:31.38,180",300")'
with open('bgd.reg', 'w') as fp: fp.write(region)

```

```python

# initialize the task instance
nuproducts = hsp.HSPTask('nuproducts')

params = {
    'indir'         : f'{obsid}_p/event_cl',
    'outdir'        : f'{obsid}_p/lc',
    'instrument'    : 'FPMA',
    'steminputs'    : f'nu{obsid}',
    'outdir'        : f'{obsid}_p/lc',
    'binsize'       : 256,
    'bkgextract'    : 'yes',
    'srcregionfile' : 'src.reg',
    'bkgregionfile' : 'bgd.reg',
    'imagefile'     : 'none',
    'phafile'       : 'DEFAULT',
    'bkgphafile'    : 'DEFAULT',
    'runbackscale'  : 'yes',
    'correctlc'     : 'yes',
    'runmkarf'      : 'no',
    'runmkrmf'      : 'no',  
}

out = nuproducts(params, noprompt=True, verbose=True)

```

```python
print('return code:', out.returncode)
```

## 5. Read and Plot the Light Curve
listing the content of the output directory `60001110002_p/lc`, we see that the task has created a source and background light cruves (`nu60001110002A01_sr.lc` and `nu60001110002A01_bk.lc`) along with the corresponding spectra. 

The task also generates `.flc` file, which contains the background-subtracted light curves.

We can proceed in different ways. We may for example use `fits` libraries in `astropy` to read this fits file directly, or we can use `ftlist` to dump the content of that file to an ascii file before reading it (we use `option=T` to list the table content).

```python
out = hsp.ftlist(infile='60001110002_p/lc/nu60001110002A01.flc', option='T', 
                 outfile='60001110002_p/lc/nu60001110002A01.txt', rownum='no', colheader='no', clobber='yes')
```


---

- Now, we use `numpy` for example for read the file, and `matplotlib` to plot it.

- For reading the data, we use `numpy.genfromtxt`, which allows for easy handling of missing data (`NULL` values in our case), so these are just replaced by `np.nan`

- The columns are: `Time`, `Time_err`, `Rate`, `Rate_err`, `Fraction_exposure`

- After reading the data, we plot the data points with full exposure (`Fraction_exposure == 1`)

```python
lc_data = np.genfromtxt('60001110002_p/lc/nu60001110002A01.txt', missing_values='NULL', filling_values=np.nan)
good_data = lc_data[:,4] == 1
lc_data = lc_data[good_data, :]
```

```python
# modify the plot style a little bit
plt.rcParams.update({
    'font.size': 14, 
    'lines.markersize': 8.0,
    'xtick.direction': 'in',
    'ytick.direction': 'in',
    'xtick.major.size': 9.,
    'ytick.major.size': 9.,
})

fig = plt.figure(figsize=(12,6))
plt.errorbar(lc_data[:,0], lc_data[:,2], lc_data[:,3], fmt='o', lw=0.5)
plt.xlabel('Time (sec)')
plt.ylabel('Count Rate (per sec)')
```

```python

```
