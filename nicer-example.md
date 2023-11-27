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

# An Example Analysing NICER Data One Sciserver

In this tutorial, we will go through the steps of analyzing a NICER observation of `PSR_B0833-45` (`obsid = 4142010107`) using `heasoftpy`.

The following assumes this notebook is run from the (heasoft) environment on Sciserver. You should see `(Heasoft)` at the top right of the notebook. If not, click there and select `(Heasoft)`. Heasoft higher than v6.31 is required in order to be able to run `nicerl3` tools.

If running outside sciserver, please ensure that heasoft v6.31 or above is installed.

```python
## Import libraries that we will need.
import heasoftpy as hsp
import xspec as xs
from astropy.io import fits
from astropy.table import Table
import os
import sys
import matplotlib.pylab as plt
import numpy as np
```

# Set up the NICER obsid directory

We are using OBSID `4142010107`. The data archive is mounted under `/FTP/..`. To find the exact location of the observation, we can use `pyvo` to query the archive using the VO services, or use Xamin, as illustrated in the `Getting-Started` and `data_access` notebooks

Because nicerl2 may modify of the observation directory, we copy it from the data location.

```python
nicerobsID = '4020180460'
dataLocation = f'/FTP/nicer/data/obs/2021_12/{nicerobsID}'
work_dir = os.getcwd()

if not os.path.exists(nicerobsID):
    os.system(f'cp -r {dataLocation} {work_dir}')
```

# Process and Clean the Data.
Next, we run the `nicerl2` pipeline to process and clean the data using `heasoftpy`

There are different ways of calling a `heasoftpy` task. Here, we first create a dictionary that contains the input parameters for the `nicerl2` task, which is then passed to `hsp.nicerl2`

```python
# input
inPars = {
    'indir': nicerobsID,
    'geomag_path': '/FTP/caldb/data/gen/pcf/geomag/',
    'filtcolumns': 'NICERV4',
    
    'clobber': True, 
    'noprompt': True,
}

# run the task
out = hsp.nicerl2(inPars)

# check that everything run correctly
if out.returncode == 0: 
    print(f'{nicerobsID} processed sucessfully!')
else:
    logfile = f'process_nicer_{nicerobsID}.log'
    print(f'ERROR processing {nicerobsID}; Writing log to {logfile}')
    with open(logfile, 'w') as fp:
        fp.write('\n'.join(out.output))
```

<!-- #region -->
# Extract the Spectra using `nicerl3-spect`

We use `nicerl3-spect3` (which is available in heasoft v6.31 and up).

#### Note
> Note that the `-` symbol in the name is replace by `_` when calling the equivalent python name, so that `nicerl3-spect3` becomes `nicerl3_spect3`


For this example, we use the `scorpeon` background model to create a background pha file. You can choose other models too, if needed.

The spectra are written to the `spec` directory. 

Note that we set the parameter `updatepha` to `yes`, so that the header of the spectral file is modifered to point to the relevant response and background files.
<!-- #endregion -->

```python
# Setup the output directory
os.chdir(work_dir)
outdir = 'spec'
if not os.path.exists(outdir):
    os.system(f'mkdir -p {outdir}')

# input parameters
inPars = {
    'indir'       : nicerobsID,
    'phafile'     : f'spec.pha',
    'rmffile'     : f'spec.rmf',
    'arffile'     : f'spec.arf',
    'bkgfile'     : f'spec_sc.bgd',
    'grouptype'   : 'optmin',
    'groupscale'  : 5,
    'updatepha'   : 'yes',
    'bkgformat'   : 'file',
    'bkgmodeltype': 'scorpeon', 
    'clobber'     : True,
    'noprompt'    : True,
}

# run the spectral extraction task
out = hsp.nicerl3_spect(inPars)

# check that the task run correctly
if out.returncode == 0: 
    print(f'Extracted the spectrum sucessfully!')
    os.system(f'mv spec*.* {outdir}')
else:
    logfile = f'nicerl3_spect_{nicerobsID}.log'
    print(f'ERROR in nicerl3-spect {nicerobsID}; Writing log to {logfile}')
    with open(logfile, 'w') as fp:
        fp.write('\n'.join(out.output))
        
```

<!-- #region -->
# Extract the Light Curve using `nicerl3-lc`

We use `nicerl3-lc` (which is available in heasoft v6.31 and up).

#### Note
> Note that, similar to `nicerl3_spect`, the `-` symbol in the name is replace by `_` when calling the equivalent python name, so that `nicerl3-lc` becomes `nicerl3_lc`


Note that no background light curve is estimated

<!-- #endregion -->

```python
# extract light curve
os.chdir(work_dir)

# input parameters
inPars = {
    'indir'       : nicerobsID,
    'timebin'     : 10,
    'lcfile'      : 'lc.fits',
    
    'clobber'     : True,
    'noprompt'    : True,
}

# run the light curve task
out = hsp.nicerl3_lc(inPars)

# check the task runs correctly
if out.returncode == 0: 
    print(f'Extracted the light curve sucessfully!')
else:
    logfile = f'nicerl3_lc_{nicerobsID}.log'
    print(f'ERROR in nicerl3-lc {nicerobsID}; Writing log to {logfile}')
    with open(logfile, 'w') as fp:
        fp.write('\n'.join(out.output))
```

# Analysis

## 1. Spectral Analysis
Here, we will show an example of how the spectra we just extract can be analyzed using `pyxspec`.

The spectra is loaded and fitted with a broken power-law model.

We then plot the data using matplotlib

```python
# move to the right location
os.chdir(f'{work_dir}/{outdir}')

# load the spectra into xspec
xs.AllData.clear()
spec = xs.Spectrum('spec.pha')
spec.ignore('0.0-0.3, 10.0-**')
```

```python
# fit a simple absorbed broken powerlaw model
model = xs.Model('wabs*bknpow')
xs.Fit.perform()
```

```python
# Plot the spectra

# first get the data to be plotted
xs.Plot.device='/null'
xs.Plot.xAxis='keV'
xs.Plot('lda')
cr = xs.Plot.y()
crerr = xs.Plot.yErr()
en = xs.Plot.x()
enwid = xs.Plot.xErr()
mop = xs.Plot.model()
target = fits.open(spec.fileName)[1].header['OBJECT']

# do the plotting
fig = plt.figure(figsize=[8,6])
plt.ylabel('Cts/s/keV', fontsize=12)
plt.xlabel('Energy (keV)', fontsize=12)
plt.title('Target = '+target+' OBSID = '+nicerobsID+' wabs*bknpow', fontsize=12)
plt.yscale('log')
plt.xscale('log')
plt.errorbar(en, cr, xerr=enwid, yerr=crerr, fmt='k.', alpha=0.2)
plt.plot(en, mop,'r-')
```

## 2. Plot the Light Curve
Next, we going to read the light curve we just generated.

Different Good Time Intervals (GTI) are plotted separately.

The light curve in the form of a fits file is read using `astropy.io.fits`.

```python
# read the light curve table to lctab, and the GTI table to gtitab
os.chdir(work_dir)
with fits.open('lc.fits') as fp:
    lctab  = Table(fp['rate'].data)
    tBin = fp['rate'].header['timedel']
    timezero = fp['rate'].header['timezero']
    lctab['TIME'] += timezero
    gtitab = Table(fp['gti'].data)
```

```python
# select GTI's that are withing the start-end time of the light curve
gti = []
for _gti in gtitab:
    g = (lctab['TIME']-tBin/2 >= _gti['START']) & (lctab['TIME']+tBin/2 <= _gti['STOP'])
    if np.any(g):
        gti.append(g)
```

```python
# We have two GTI's, we plot them.
ngti = len(gti)
fig, axs = plt.subplots(1, ngti, figsize=[10,3], sharey=True)
for i in range(ngti):
    tab = lctab[gti[i]]
    axs[i].errorbar(tab['TIME'] - timezero, tab['RATE'], yerr=tab['ERROR'], fmt='k.')
    
    axs[i].set_ylabel('Cts/s', fontsize=12)
    axs[i].set_xlabel('Time (s)', fontsize=12)
    axs[i].set_yscale('log')
    axs[i].set_ylim(40, 500)
    
plt.tight_layout()
```

```python

```
