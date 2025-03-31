---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.16.0
  kernelspec:
    display_name: (xmmsas)
    language: python
    name: conda-env-xmmsas-py
---

# ABC Guide for XMM-Newton -- RGS+EPIC Joint Spectral Fitting Part 2: Fitting the Spectra
<hr style="border: 2px solid #fadbac" />

- **Description:** A short introduction to joint fitting RGS and EPIC spectra on SciServer.
- **Level:** Advanced
- **Data:** XMM observation of Mkn 509 (obsid=0601390201)
- **Requirements:** Must be run using the `HEASARCv6.35` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Jenna Cann (March 2025)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 28 March 2025, for SAS v22.1 and pySAS v1.4.8

<hr style="border: 2px solid #fadbac" />


## 1. Introduction
This tutorial provides a short, basic introduction to joint fitting RGS and EPIC data on SciServer. This is Part 2, and assumes that you have already run Part 1, where we reprocess the relevant data using pyXSpec.

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br><br>
<b>Running Outside Sciserver:</b><br>
This notebook was designed to run on SciServer, but an equivelent notebook can be found on <a href="https://github.com/XMMGOF/pysas">GitHub</a>. You will need to install the development version of pySAS found on GitHub (<a href="https://github.com/XMMGOF/pysas">pySAS on GitHub</a>). There are installation instructions on GitHub and example notebooks can be found inside the directory named 'documentation'.
<br>
</div>

<div class="alert alert-block alert-warning">
    <b>Warning:</b> By default this notebook will place observation data files in your <tt>scratch</tt> space. The <tt>scratch</tt> space on SciServer will only retain files for 90 days. If you wish to keep the data files for longer move them into your <tt>persistent</tt> directory.
</div>

```python
import xspec
import os

import pysas
from pysas.wrapper import Wrapper as w

# Importing Js9
import jpyjs9

# Useful imports
import os, shutil

# Imports for plotting
import matplotlib.pyplot as plt
from astropy.visualization import astropy_mpl_style
from astropy.io import fits
from astropy.wcs import WCS
from astropy.table import Table
plt.style.use(astropy_mpl_style)

cur_dir = os.getcwd()
```

First we define the paths to all of our data. We will be fitting MOS1, MOS2, and both orders of RGS1 and RGS2.

```python
obsid = '0601390201'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')

odf = pysas.odfcontrol.ODFobject(obsid,data_dir=data_dir)
os.chdir(odf.work_dir)
```

For this tuturial we will be using a specialized absoption model. `XSPEC` comes with a number of prebuilt models for spectral fitting. But it is possible to load your own models into XSPEC. In this case the model is in a FITS table. Due to the size (~150 MB) you will have to download the model from the HEASARC website. The following cells will download the FITS file and place it in the work directory for the ObsID.

```python
# This will install the wget module if it is not already present
try:
    import wget
except ModuleNotFoundError:
    %pip install wget
    import wget
```

```python
# This will download the FITS table
url = 'https://heasarc.gsfc.nasa.gov/FTP/xmm/software/sciserver/twarmabs.fits'
filename = wget.download(url)
```

```python
# Linking filenames
bkg_R1spectra  = [os.path.join(odf.work_dir,'P0601390201R1S004BGSPEC1001.FIT'),
                               os.path.join(odf.work_dir,'P0601390201R1S004BGSPEC2001.FIT')]
bkg_R2spectra  = [os.path.join(odf.work_dir,'P0601390201R2S005BGSPEC1001.FIT'),
                               os.path.join(odf.work_dir,'P0601390201R2S005BGSPEC2001.FIT')]

rmf_R1spectra  = [os.path.join(odf.work_dir,'P0601390201R1S004RSPMAT1001.FIT'),
                               os.path.join(odf.work_dir,'P0601390201R1S004RSPMAT2001.FIT')]
rmf_R2spectra  = [os.path.join(odf.work_dir,'P0601390201R2S005RSPMAT1001.FIT'),
                               os.path.join(odf.work_dir,'P0601390201R2S005RSPMAT2001.FIT')]


mos1_spectrum  = os.path.join(odf.work_dir,'mos1_grp25.fits')
mos2_spectrum = os.path.join(odf.work_dir,'mos2_grp25.fits')
```

Now we will initialize the EPIC and RGS spectra into PyXSpec for analysis, as well as their respective rmfs, arfs, and background files.

```python
RGS1o1 = odf.files['R1spectra'][0]
RGS1o2 = odf.files['R1spectra'][1]
RGS2o1 = odf.files['R2spectra'][0]
RGS2o2 = odf.files['R2spectra'][1]

bkg_RGS1o1 = bkg_R1spectra[0]
bkg_RGS1o2 = bkg_R1spectra[1]
bkg_RGS2o1 = bkg_R2spectra[0]
bkg_RGS2o2 = bkg_R2spectra[1]

rmf_RGS1o1 = rmf_R1spectra[0]
rmf_RGS1o2 = rmf_R1spectra[1]
rmf_RGS2o1 = rmf_R2spectra[0]
rmf_RGS2o2 = rmf_R2spectra[1]
```

```python
xspec.AllData("1:1 {:s}".format(mos1_spectrum))

s1 = xspec.AllData(1)
s1.response = os.path.join(odf.work_dir,'mos1.rmf')
s1.response.arf = os.path.join(odf.work_dir,'mos1.arf')
s1.ignore('**-0.3, 6.0-**')
```

```python
xspec.AllData -= "*"

xspec.AllData("1:1 {:s} 2:2 {:s} 3:3 {:s} 4:4 {:s} 5:5 {:s} 6:6 {:s}".format(mos1_spectrum, mos2_spectrum, RGS1o1, RGS1o2, RGS2o1, RGS2o2))

s1 = xspec.AllData(1)
s1.response = os.path.join(odf.work_dir,'mos1.rmf')
s1.response.arf = os.path.join(odf.work_dir,'mos1.arf')
s1.ignore('**-0.3, 6.0-**')

s2 = xspec.AllData(2)
s2.response = os.path.join(odf.work_dir,'mos2.rmf')
s2.response.arf = os.path.join(odf.work_dir,'mos2.arf')
s2.ignore('**-0.3, 6.0-**')

s3 = xspec.AllData(3)
s3.background = bkg_RGS1o1
s3.response = rmf_RGS1o1
s3.ignore('**-0.5, 2.0-**')

s4 = xspec.AllData(4)
s4.background = bkg_RGS1o2
s4.response = rmf_RGS1o2
s4.ignore('**-0.5, 2.0-**')

s5 = xspec.AllData(5)
s5.background = bkg_RGS2o1
s5.response = rmf_RGS2o1
s5.ignore('**-0.5, 2.0-**')

s6 = xspec.AllData(6)
s6.background = bkg_RGS2o2
s6.response = rmf_RGS2o2
s6.ignore('**-0.5, 2.0-**')
```

And let's use the `show` command to make sure that all of our data was loaded properly. Each spectrum should have an response matrix file (rmf) and a background file, and each EPIC spectrum should also have an ancillary response file (arf).

```python
xspec.AllData.show()
```

Joint fitting spectra follows a very similar process to fitting single spectra, with one main addition of a constant "scale factor" at the beginning of each spectrum's model. For example, let's start with a very simple redshifted power law fit with Galactic absorption.

```python
xspec.AllModels.clear()

m = xspec.Model("constant*phabs*zpowerlw")

m1 = xspec.AllModels(1)
m2 = xspec.AllModels(2)
m3 = xspec.AllModels(3)
m4 = xspec.AllModels(4)
m5 = xspec.AllModels(5)
m6 = xspec.AllModels(6)
```

Next, we will want to define some known parameters, such as the redshift, and the Galactic absorption, which can be found by inputting the source's RA and DEC in the [Swift Galactic NH tool](https://www.swift.ac.uk/analysis/nhtot/). The RA and DEC of Mrk 509 are 20h44m09.7526s, -10d43m24.739s, or 311.040636, -10.723539 in decimal degree format. To ensure that these values do not change during the fitting, we will also freeze them (either by setting its uncertainty to -1 or by toggling the 'frozen' attribute. We will also unlink just the constant parameter between each of the models, to ensure that the models will be able to scale as necessary to fit the data. 

To list the components, and their respective parameters, for the current model, you can use the commands `componentNames` and `parameterNames` as shown below. For more information about the component models and their parameters, including units, check the relevant model pages on the [XSpec model documentation](https://heasarc.gsfc.nasa.gov/docs/xanadu/xspec/manual/node128.html).

```python
m.componentNames
```

```python
m.zpowerlw.parameterNames
```

```python
m.zpowerlw.Redshift = [0.034397, -1]
m.phabs.nH = [0.0504, -1]
m.constant.factor=[1, -1]
m.zpowerlw.PhoIndex=1.8

m2(1).link = ""
m2(1).frozen = False

m3(1).link = ""
m3(1).frozen = False

m4(1).link = ""
m4(1).frozen = False

m5(1).link = ""
m5(1).frozen = False

m6(1).link = ""
m6(1).frozen = False
```

And let's double-check to make sure all of those changes were taken into consideration for our model.

```python
xspec.AllModels.show()
```

Now, we renormalize the model and begin our fit.

```python
xspec.Fit.renorm()
xspec.Fit.perform()
```

And let's see what the best fit model provided! 

```python
xspec.AllModels.show()
```

As you can see, the photon index (PhoIndex) required by this model for the best fit to the data is ~2.25.

In order to assess the fit, we will want to examine how a plot of the model spectrum matches up with data. 

To create a plot of the spectrum and the model we include a convenient function. It takes as an input the spectrum object created by PyXSPEC. A lot of what goes into this function is for formatting the plot.

(For more advanced users: The function is written so that it returns the `figure` and two `axis` objects created by `Matplotlib`. You can use these to make additional changes to the formatting of the plot.)

```python
xspec.Plot.device="/null"
xspec.Plot.xAxis="keV"
xspec.Plot("data")

energies_mos1 = xspec.Plot.x(1)
edeltas_mos1 = xspec.Plot.xErr(1)
energies_mos2 = xspec.Plot.x(2)
edeltas_mos2 = xspec.Plot.xErr(2)
energies_r1o1 = xspec.Plot.x(3)
edeltas_r1o1 = xspec.Plot.xErr(3)
energies_r1o2 = xspec.Plot.x(4)
edeltas_r1o2 = xspec.Plot.xErr(4)
energies_r2o1 = xspec.Plot.x(5)
edeltas_r2o1 = xspec.Plot.xErr(5)
energies_r2o2 = xspec.Plot.x(6)
edeltas_r2o2 = xspec.Plot.xErr(6)

rates_mos1 = xspec.Plot.y(1,1)
errors_mos1 = xspec.Plot.yErr(1,1)

rates_mos2 = xspec.Plot.y(2,1)
errors_mos2 = xspec.Plot.yErr(2,1)

rates_r1o1 = xspec.Plot.y(3,1)
errors_r1o1 = xspec.Plot.yErr(3,1)

rates_r1o2 = xspec.Plot.y(4,1)
errors_r1o2 = xspec.Plot.yErr(4,1)

rates_r2o1 = xspec.Plot.y(5,1)
errors_r2o1 = xspec.Plot.yErr(5,1)

rates_r2o2 = xspec.Plot.y(6,1)
errors_r2o2 = xspec.Plot.yErr(6,1)


foldedmodel_mos1 = xspec.Plot.model()
foldedmodel_mos2 = xspec.Plot.model(2)
foldedmodel_r1o1 = xspec.Plot.model(3)
foldedmodel_r1o2 = xspec.Plot.model(4)
foldedmodel_r2o1 = xspec.Plot.model(5)
foldedmodel_r2o2 = xspec.Plot.model(6)

dataLabels = xspec.Plot.labels(1)

nE_mos1 = len(energies_mos1)
stepenergies_mos1 = list()

for i in range(nE_mos1):
    stepenergies_mos1.append(energies_mos1[i] - edeltas_mos1[i])
stepenergies_mos1.append(energies_mos1[-1]+edeltas_mos1[-1])

nE_mos2 = len(energies_mos2)
stepenergies_mos2 = list()

for i in range(nE_mos2):
    stepenergies_mos2.append(energies_mos2[i] - edeltas_mos2[i])
stepenergies_mos2.append(energies_mos2[-1]+edeltas_mos2[-1])

nE_r1o1 = len(energies_r1o1)
stepenergies_r1o1 = list()

for i in range(nE_r1o1):
    stepenergies_r1o1.append(energies_r1o1[i] - edeltas_r1o1[i])
stepenergies_r1o1.append(energies_r1o1[-1]+edeltas_r1o1[-1])

nE_r1o2 = len(energies_r1o2)
stepenergies_r1o2 = list()

for i in range(nE_r1o2):
    stepenergies_r1o2.append(energies_r1o2[i] - edeltas_r1o2[i])
stepenergies_r1o2.append(energies_r1o2[-1]+edeltas_r1o2[-1])

nE_r2o1 = len(energies_r2o1)
stepenergies_r2o1 = list()

for i in range(nE_r2o1):
    stepenergies_r2o1.append(energies_r2o1[i] - edeltas_r2o1[i])
stepenergies_r2o1.append(energies_r2o1[-1]+edeltas_r2o1[-1])

nE_r2o2 = len(energies_r2o2)
stepenergies_r2o2 = list()

for i in range(nE_r2o2):
    stepenergies_r2o2.append(energies_r1o2[i] - edeltas_r2o2[i])
stepenergies_r2o2.append(energies_r2o2[-1]+edeltas_r2o2[-1])

foldedmodel_mos1.append(foldedmodel_mos1[-1])
foldedmodel_mos2.append(foldedmodel_mos2[-1])
foldedmodel_r1o1.append(foldedmodel_r1o1[-1])
foldedmodel_r1o2.append(foldedmodel_r1o2[-1])
foldedmodel_r2o1.append(foldedmodel_r2o1[-1])
foldedmodel_r2o2.append(foldedmodel_r2o2[-1])
```

```python
plt.ylabel(dataLabels[1])
plt.title(dataLabels[2])
plt.yscale('log')
plt.xscale('log')
plt.errorbar(energies_mos1,rates_mos1,xerr=edeltas_mos1,yerr=errors_mos1,fmt='.',color='b')
plt.errorbar(energies_mos2,rates_mos2,xerr=edeltas_mos2,yerr=errors_mos2,fmt='.',color='r')
plt.errorbar(energies_r1o1,rates_r1o1,xerr=edeltas_r1o1,yerr=errors_r1o1,fmt='.',color='#0cf52c')
plt.errorbar(energies_r1o2,rates_r1o2,xerr=edeltas_r1o2,yerr=errors_r1o2,fmt='.',color='#0cf5f1')
plt.errorbar(energies_r2o1,rates_r2o1,xerr=edeltas_r2o1,yerr=errors_r2o1,fmt='.',color='#ce0cf5')
plt.errorbar(energies_r2o2,rates_r2o2,xerr=edeltas_r2o2,yerr=errors_r2o2,fmt='.',color='k')

plt.step(stepenergies_mos1,foldedmodel_mos1,where='post',color='b')
plt.step(stepenergies_mos2,foldedmodel_mos2,where='post',color='r')
plt.step(stepenergies_r1o1,foldedmodel_r1o1,where='post',color='#0cf52c')
plt.step(stepenergies_r1o2,foldedmodel_r1o2,where='post',color='#0cf5f1')
plt.step(stepenergies_r2o1,foldedmodel_r2o1,where='post',color='#ce0cf5')
plt.step(stepenergies_r2o2,foldedmodel_r2o2,where='post',color='k')
```

This looks like a pretty decent rough fit, but let's zoom into certain energy ranges to test that.

```python
plt.ylabel(dataLabels[1])
plt.title(dataLabels[2])
plt.yscale('log')
plt.xscale('log')
plt.errorbar(energies_mos1,rates_mos1,xerr=edeltas_mos1,yerr=errors_mos1,fmt='.',color='b')
plt.errorbar(energies_mos2,rates_mos2,xerr=edeltas_mos2,yerr=errors_mos2,fmt='.',color='r')
plt.errorbar(energies_r1o1,rates_r1o1,xerr=edeltas_r1o1,yerr=errors_r1o1,fmt='.',color='#0cf52c')
plt.errorbar(energies_r1o2,rates_r1o2,xerr=edeltas_r1o2,yerr=errors_r1o2,fmt='.',color='#0cf5f1')
plt.errorbar(energies_r2o1,rates_r2o1,xerr=edeltas_r2o1,yerr=errors_r2o1,fmt='.',color='#ce0cf5')
plt.errorbar(energies_r2o2,rates_r2o2,xerr=edeltas_r2o2,yerr=errors_r2o2,fmt='.',color='k')

plt.step(stepenergies_mos1,foldedmodel_mos1,where='post',color='b')
plt.step(stepenergies_mos2,foldedmodel_mos2,where='post',color='r')
plt.step(stepenergies_r1o1,foldedmodel_r1o1,where='post',color='#0cf52c')
plt.step(stepenergies_r1o2,foldedmodel_r1o2,where='post',color='#0cf5f1')
plt.step(stepenergies_r2o1,foldedmodel_r2o1,where='post',color='#ce0cf5')
plt.step(stepenergies_r2o2,foldedmodel_r2o2,where='post',color='k')

plt.xlim(0.5, 2)
```

```python
plt.ylabel(dataLabels[1])
plt.title(dataLabels[2])
plt.yscale('log')
plt.xscale('log')
plt.errorbar(energies_mos1,rates_mos1,xerr=edeltas_mos1,yerr=errors_mos1,fmt='.',color='b')
plt.errorbar(energies_mos2,rates_mos2,xerr=edeltas_mos2,yerr=errors_mos2,fmt='.',color='r')
plt.errorbar(energies_r1o1,rates_r1o1,xerr=edeltas_r1o1,yerr=errors_r1o1,fmt='.',color='#0cf52c')
plt.errorbar(energies_r1o2,rates_r1o2,xerr=edeltas_r1o2,yerr=errors_r1o2,fmt='.',color='#0cf5f1')
plt.errorbar(energies_r2o1,rates_r2o1,xerr=edeltas_r2o1,yerr=errors_r2o1,fmt='.',color='#ce0cf5')
plt.errorbar(energies_r2o2,rates_r2o2,xerr=edeltas_r2o2,yerr=errors_r2o2,fmt='.',color='k')

plt.step(stepenergies_mos1,foldedmodel_mos1,where='post',color='b')
plt.step(stepenergies_mos2,foldedmodel_mos2,where='post',color='r')
plt.step(stepenergies_r1o1,foldedmodel_r1o1,where='post',color='#0cf52c')
plt.step(stepenergies_r1o2,foldedmodel_r1o2,where='post',color='#0cf5f1')
plt.step(stepenergies_r2o1,foldedmodel_r2o1,where='post',color='#ce0cf5')
plt.step(stepenergies_r2o2,foldedmodel_r2o2,where='post',color='k')

plt.xlim(0.5, 0.6)
```

In the most recent plot, you can see that we're matching the continuum pretty well, but there are some potential absorption features that are not being taken into account. To account for this, let's explore fitting a more complex model.

In this next fit, we are adding additional absorption components, including a rough table model that allows us to vary ionization parameter and column density. While this model is sufficient for our instructional purposes here, it makes numerous assumptions that may not hold true for all cases. We recommend using a more robust model (such as [`warmabs`](https://heasarc.gsfc.nasa.gov/docs/software/xstar/docs/sphinx/xstardoc/docs/build/html/warmabs.html 'warmabs')) for any rigorous scientific analysis.


We will now load a `warmabs` model. The model data is found in the file `twarmabs.fits`, which should have automatically been copied into your work directory at the beginning of this notebook. If you encounter an error, make sure the file is in your `work_dir` for the `ObsID` you are working with.

```python
xspec.AllModels.clear()

m = xspec.Model("constant*phabs*tbabs*mtable{twarmabs.fits}*zpowerlw")

m1 = xspec.AllModels(1)
m2 = xspec.AllModels(2)
m3 = xspec.AllModels(3)
m4 = xspec.AllModels(4)
m5 = xspec.AllModels(5)
m6 = xspec.AllModels(6)
```

And we will similarly define our known parameters as before.

```python editable=true slideshow={"slide_type": ""}
m.zpowerlw.Redshift = [0.034397, -1]
m.phabs.nH = [0.0504, -1]
m.constant.factor=[1, -1]
m.zpowerlw.PhoIndex=1.8

m2(1).link = ""
m2(1).frozen = False

m3(1).link = ""
m3(1).frozen = False

m4(1).link = ""
m4(1).frozen = False

m5(1).link = ""
m5(1).frozen = False

m6(1).link = ""
m6(1).frozen = False
```

```python
xspec.AllModels.show()
```

Now, let's renormalize and fit this slightly more complex model. This will likely take a little longer than fitting a simple power law.

```python editable=true slideshow={"slide_type": ""}
xspec.Fit.renorm()
xspec.Fit.perform()
```

And again, let's see what our best fit parameters to our model are:

```python
xspec.AllModels.show()
```

As you can see, this model provides a similar value for PhoIndex as before. Since this is the primary continuum component, that is a good sign that this fit should also follow the continuum well, and that the added model components will provide more insight into the finer absorption features that were not fit by the previous model.

```python editable=true slideshow={"slide_type": ""}
xspec.Plot.device="/null"
xspec.Plot.xAxis="keV"
xspec.Plot("data")

energies_mos1 = xspec.Plot.x(1)
edeltas_mos1 = xspec.Plot.xErr(1)
energies_mos2 = xspec.Plot.x(2)
edeltas_mos2 = xspec.Plot.xErr(2)
energies_r1o1 = xspec.Plot.x(3)
edeltas_r1o1 = xspec.Plot.xErr(3)
energies_r1o2 = xspec.Plot.x(4)
edeltas_r1o2 = xspec.Plot.xErr(4)
energies_r2o1 = xspec.Plot.x(5)
edeltas_r2o1 = xspec.Plot.xErr(5)
energies_r2o2 = xspec.Plot.x(6)
edeltas_r2o2 = xspec.Plot.xErr(6)

rates_mos1 = xspec.Plot.y(1,1)
errors_mos1 = xspec.Plot.yErr(1,1)

rates_mos2 = xspec.Plot.y(2,1)
errors_mos2 = xspec.Plot.yErr(2,1)

rates_r1o1 = xspec.Plot.y(3,1)
errors_r1o1 = xspec.Plot.yErr(3,1)

rates_r1o2 = xspec.Plot.y(4,1)
errors_r1o2 = xspec.Plot.yErr(4,1)

rates_r2o1 = xspec.Plot.y(5,1)
errors_r2o1 = xspec.Plot.yErr(5,1)

rates_r2o2 = xspec.Plot.y(6,1)
errors_r2o2 = xspec.Plot.yErr(6,1)


foldedmodel_mos1 = xspec.Plot.model()
foldedmodel_mos2 = xspec.Plot.model(2)
foldedmodel_r1o1 = xspec.Plot.model(3)
foldedmodel_r1o2 = xspec.Plot.model(4)
foldedmodel_r2o1 = xspec.Plot.model(5)
foldedmodel_r2o2 = xspec.Plot.model(6)

dataLabels = xspec.Plot.labels(1)

nE_mos1 = len(energies_mos1)
stepenergies_mos1 = list()

for i in range(nE_mos1):
    stepenergies_mos1.append(energies_mos1[i] - edeltas_mos1[i])
stepenergies_mos1.append(energies_mos1[-1]+edeltas_mos1[-1])

nE_mos2 = len(energies_mos2)
stepenergies_mos2 = list()

for i in range(nE_mos2):
    stepenergies_mos2.append(energies_mos2[i] - edeltas_mos2[i])
stepenergies_mos2.append(energies_mos2[-1]+edeltas_mos2[-1])

nE_r1o1 = len(energies_r1o1)
stepenergies_r1o1 = list()

for i in range(nE_r1o1):
    stepenergies_r1o1.append(energies_r1o1[i] - edeltas_r1o1[i])
stepenergies_r1o1.append(energies_r1o1[-1]+edeltas_r1o1[-1])

nE_r1o2 = len(energies_r1o2)
stepenergies_r1o2 = list()

for i in range(nE_r1o2):
    stepenergies_r1o2.append(energies_r1o2[i] - edeltas_r1o2[i])
stepenergies_r1o2.append(energies_r1o2[-1]+edeltas_r1o2[-1])


nE_r2o1 = len(energies_r2o1)
stepenergies_r2o1 = list()

for i in range(nE_r2o1):
    stepenergies_r2o1.append(energies_r2o1[i] - edeltas_r2o1[i])
stepenergies_r2o1.append(energies_r2o1[-1]+edeltas_r2o1[-1])

nE_r2o2 = len(energies_r2o2)
stepenergies_r2o2 = list()

for i in range(nE_r2o2):
    stepenergies_r2o2.append(energies_r1o2[i] - edeltas_r2o2[i])
stepenergies_r2o2.append(energies_r2o2[-1]+edeltas_r2o2[-1])


foldedmodel_mos1.append(foldedmodel_mos1[-1])
foldedmodel_mos2.append(foldedmodel_mos2[-1])
foldedmodel_r1o1.append(foldedmodel_r1o1[-1])
foldedmodel_r1o2.append(foldedmodel_r1o2[-1])
foldedmodel_r2o1.append(foldedmodel_r2o1[-1])
foldedmodel_r2o2.append(foldedmodel_r2o2[-1])
```

```python editable=true slideshow={"slide_type": ""}
plt.ylabel(dataLabels[1])
plt.yscale('log')
plt.xscale('log')
plt.errorbar(energies_mos1,rates_mos1,xerr=edeltas_mos1,yerr=errors_mos1,fmt='.',color='b')
plt.errorbar(energies_mos2,rates_mos2,xerr=edeltas_mos2,yerr=errors_mos2,fmt='.',color='r')
plt.errorbar(energies_r1o1,rates_r1o1,xerr=edeltas_r1o1,yerr=errors_r1o1,fmt='.',color='#0cf52c')
plt.errorbar(energies_r1o2,rates_r1o2,xerr=edeltas_r1o2,yerr=errors_r1o2,fmt='.',color='#0cf5f1')
plt.errorbar(energies_r2o1,rates_r2o1,xerr=edeltas_r2o1,yerr=errors_r2o1,fmt='.',color='#ce0cf5')
plt.errorbar(energies_r2o2,rates_r2o2,xerr=edeltas_r2o2,yerr=errors_r2o2,fmt='.',color='k')

plt.step(stepenergies_mos1,foldedmodel_mos1,where='post',color='b')
plt.step(stepenergies_mos2,foldedmodel_mos2,where='post',color='r')
plt.step(stepenergies_r1o1,foldedmodel_r1o1,where='post',color='#0cf52c')
plt.step(stepenergies_r1o2,foldedmodel_r1o2,where='post',color='#0cf5f1')
plt.step(stepenergies_r2o1,foldedmodel_r2o1,where='post',color='#ce0cf5')
plt.step(stepenergies_r2o2,foldedmodel_r2o2,where='post',color='k')
```

<!-- #region editable=true slideshow={"slide_type": ""} -->
This looks like a pretty decent fit! Let's zoom into the RGS data to see if we can see the absorption features being fit.
<!-- #endregion -->

```python
plt.ylabel(dataLabels[1])
plt.yscale('log')
plt.xscale('log')
plt.errorbar(energies_mos1,rates_mos1,xerr=edeltas_mos1,yerr=errors_mos1,fmt='.',color='b')
plt.errorbar(energies_mos2,rates_mos2,xerr=edeltas_mos2,yerr=errors_mos2,fmt='.',color='r')
plt.errorbar(energies_r1o1,rates_r1o1,xerr=edeltas_r1o1,yerr=errors_r1o1,fmt='.',color='#0cf52c')
plt.errorbar(energies_r1o2,rates_r1o2,xerr=edeltas_r1o2,yerr=errors_r1o2,fmt='.',color='#0cf5f1')
plt.errorbar(energies_r2o1,rates_r2o1,xerr=edeltas_r2o1,yerr=errors_r2o1,fmt='.',color='#ce0cf5')
plt.errorbar(energies_r2o2,rates_r2o2,xerr=edeltas_r2o2,yerr=errors_r2o2,fmt='.',color='k')

plt.step(stepenergies_mos1,foldedmodel_mos1,where='post',color='b')
plt.step(stepenergies_mos2,foldedmodel_mos2,where='post',color='r')
plt.step(stepenergies_r1o1,foldedmodel_r1o1,where='post',color='#0cf52c')
plt.step(stepenergies_r1o2,foldedmodel_r1o2,where='post',color='#0cf5f1')
plt.step(stepenergies_r2o1,foldedmodel_r2o1,where='post',color='#ce0cf5')
plt.step(stepenergies_r2o2,foldedmodel_r2o2,where='post',color='k')

plt.xlim(0.5, 2.0)
```

```python
plt.ylabel(dataLabels[1])
plt.yscale('log')
plt.xscale('log')
plt.errorbar(energies_mos1,rates_mos1,xerr=edeltas_mos1,yerr=errors_mos1,fmt='.',color='b')
plt.errorbar(energies_mos2,rates_mos2,xerr=edeltas_mos2,yerr=errors_mos2,fmt='.',color='r')
plt.errorbar(energies_r1o1,rates_r1o1,xerr=edeltas_r1o1,yerr=errors_r1o1,fmt='.',color='#0cf52c')
plt.errorbar(energies_r1o2,rates_r1o2,xerr=edeltas_r1o2,yerr=errors_r1o2,fmt='.',color='#0cf5f1')
plt.errorbar(energies_r2o1,rates_r2o1,xerr=edeltas_r2o1,yerr=errors_r2o1,fmt='.',color='#ce0cf5')
plt.errorbar(energies_r2o2,rates_r2o2,xerr=edeltas_r2o2,yerr=errors_r2o2,fmt='.',color='k')

plt.step(stepenergies_mos1,foldedmodel_mos1,where='post',color='b')
plt.step(stepenergies_mos2,foldedmodel_mos2,where='post',color='r')
plt.step(stepenergies_r1o1,foldedmodel_r1o1,where='post',color='#0cf52c')
plt.step(stepenergies_r1o2,foldedmodel_r1o2,where='post',color='#0cf5f1')
plt.step(stepenergies_r2o1,foldedmodel_r2o1,where='post',color='#ce0cf5')
plt.step(stepenergies_r2o2,foldedmodel_r2o2,where='post',color='k')

plt.xlim(0.5, 0.6)
```

As you can see, we still have a good fit to the continuum, but now this slightly more complex model is providing a better fit to the finer absorption features. You can now further explore improving the fit with additional models, or more physically robust models.
