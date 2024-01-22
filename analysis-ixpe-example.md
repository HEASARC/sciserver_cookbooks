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
    name: heasoft
---

# Getting Started with IXPE Data
<hr style="border: 2px solid #fadbac" />

- **Description:** An example on analysing IXPE data on Sciserver using heasoftpy.
- **Level:** Intermediate.
- **Data:** IXPE observation of blazar **Mrk 501** (ObsID 01004701).
- **Requirements:** `heasoftpy`, `xspec`, `matplotlib`
- **Credit:** Kavitha Arur (Jun 2023).
- **Support:** Contact the [IXPE Guest Observer Facility (GOF)](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback?selected=ixpe) or the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 01/26/2024.

<hr style="border: 2px solid #fadbac" />


## 1. Introduction

This notebook is a tutorial on accessing IXPE data on Sciserver and getting started with analysing them. You will learn to download the data, extract the source and background regions and perform spectro-polarimetric fits.

It also highly recommended that new users read the IXPE Quick Start Guide ([linked here](https://heasarc.gsfc.nasa.gov/docs/ixpe/analysis/IXPE_quickstart.pdf)) and the recommended practices for statistical treatment of IXPE results [here](https://heasarcdev.gsfc.nasa.gov/docs/ixpe/analysis/IXPE_Stats-Advice.pdf).

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br>
Also, this notebook requires <code>heasoftpy</code>, which is available in the (heasoft) conda environment. You should see (heasoft) at the top right of the notebook. If not, click there and select it.

<b>Running Outside Sciserver:</b><br>
If running outside Sciserver, some changes will be needed, including:<br>
&bull; Make sure heasoftpy and heasoft are installed (<a herf='https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/'>Download and Install heasoft</a>).<br>
&bull; Unlike on Sciserver, where the data is available locally, you will need to download the data to your machine.<br>
</div>


## 2. Module Imports
We need the following python modules:

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
In this example, reprocessing the data is not required. Instead the level 2 data products are sufficient. If you need to reprocess the data, the IXPE tools are available with <code>from heasoftpy import ixpe</code>.
</div>

```python
import glob
import matplotlib.pyplot as plt
import heasoftpy as hsp
import xspec
```

## 3. Finding the Data 

On Sciserver, all the HEASARC data ire mounted locally under `/FTP/`, so once we have the path to the data, we can directly access it without the need to download it.

For our exploratory data analysis, we will use an observation of the blazar **Mrk 501** (ObsID 01004701).

You can also see the [Getting Started](getting-started.md), [Data Access](data-access.md) and  [Finding and Downloading Data](data-find-download.md) tutorials for examples on how to find data.

```python
data_path = "/FTP/ixpe/data/obs/01/01004701"
```

Check the contents of this folder

It should contain the standard IXPE data files, which include:
   - `event_l1` and `event_l2`: level 1 and 2 event files, respectively.
   - `auxil`: auxiliary data files, such as exposure maps.
   - `hk`: house-keeping data such as orbit files etc.
    
For a complete description of data formats of the level 1, level 2 and calibration data products, see the support documentation on the [IXPE Website](https://heasarc.gsfc.nasa.gov/docs/ixpe/analysis/#supportdoc)

```python
glob.glob(f'{data_path}/*')
```

## 4. Exploring The Data
To Analyze the data within the notebook, we use `heasoftpy`.

In the folder for each observation, check for a `README` file. This file is included with a description of known issues (if any) with the processing for that observation.

In this *IXPE* example, it is not necessary to reprocess the data. Instead the level 2 data products can be analysed directly. 

```python
# set some input
indir  = data_path
obsid  = indir.split('/')[-1] 

filelist = glob.glob(f'{indir}/event_l2/*')
filelist
```

We see that there are three files: one event file for each detector. We can examine the structure of these level 2 files.

```python
det1_fits = filelist[0]
det2_fits = filelist[1]
det3_fits = filelist[2]

#print the file structure for event 1 detector file
out = hsp.fstruct(infile=det1_fits).stdout
print(out)

```

## 5. Extracting the spectro polarimetric data 

### 5.1 Defining the Source and Background Regions

To obtain the source and background spectra from the Level 2 files, we need to define a source region and background region for the extraction. This can also be done using `ds9`. 

For the source, we extract a 60" circle centered on the source. For the background region, we use an annulus with inner radius of 132.000" and outer radius 252.000"

The region files should be independently defined for each telescope; in this example, the source location has the same celestial coordinates within 0.25" for all three detectors so a single source and a single background region can be used.

```python
f = open("src.reg", "w")
f.write('circle(16:53:51.766,+39:45:44.41,60.000")')
f.close()

f = open("bkg.reg", "w")
f.write('annulus(16:53:51.766,+39:45:44.41,132.000",252.000")')
f.close()
```

### 5.2 Running the extractor tools

The `extractor` tool from FTOOLS, can now be used to extract I,Q and U spectra from IXPE Level 2
event lists as shown below. 

The help for the tool can be displayed using the `hsp.extractor?` command. 

First, we extract the source I,Q and U spectra 

```python
#Extract source I,Q and U spectra for DU1
out = hsp.extractor(filename=det1_fits, binlc=10.0, eventsout='NONE', imgfile='NONE',fitsbinlc='NONE', 
              phafile= 'ixpe_det1_src_.pha',regionfile='src.reg', timefile='NONE', stokes='NEFF', 
              polwcol='W_MOM', tcol='TIME', ecol='PI', xcolf='X', xcolh='X',ycolf='Y', ycolh='Y')
if out.returncode != 0:
    print(out.stdout)
    raise Exception('extractor for det1 failed!')

#Extract source I,Q and U spectra for DU2
out = hsp.extractor(filename=det2_fits, binlc=10.0, eventsout='NONE', imgfile='NONE',fitsbinlc='NONE', 
              phafile= 'ixpe_det2_src_.pha',regionfile='src.reg', timefile='NONE', stokes='NEFF', 
              polwcol='W_MOM', tcol='TIME', ecol='PI', xcolf='X', xcolh='X',ycolf='Y', ycolh='Y')
if out.returncode != 0:
    print(out.stdout)
    raise Exception('extractor for det2 failed!')

#Extract source I,Q and U spectra for DU3
out = hsp.extractor(filename=det3_fits, binlc=10.0, eventsout='NONE', imgfile='NONE',fitsbinlc='NONE', 
              phafile= 'ixpe_det3_src_.pha',regionfile='src.reg', timefile='NONE', stokes='NEFF', 
              polwcol='W_MOM', tcol='TIME', ecol='PI', xcolf='X', xcolh='X',ycolf='Y', ycolh='Y')
if out.returncode != 0:
    print(out.stdout)
    raise Exception('extractor for det3 failed!')

```

Now repeat the process to extract background I,Q and U spectra

```python
#Extract background I,Q and U spectra for DU1
out = hsp.extractor(filename=det1_fits, binlc=10.0, eventsout='NONE', imgfile='NONE',fitsbinlc='NONE', 
              phafile= 'ixpe_det1_bkg_.pha',regionfile='bkg.reg', timefile='NONE', stokes='NEFF', 
              polwcol='W_MOM', tcol='TIME', ecol='PI', xcolf='X', xcolh='X',ycolf='Y', ycolh='Y')
if out.returncode != 0:
    print(out.stdout)
    raise Exception('extractor for det1 failed!')

#Extract background I,Q and U spectra for DU2
out = hsp.extractor(filename=det2_fits, binlc=10.0, eventsout='NONE', imgfile='NONE',fitsbinlc='NONE', 
              phafile= 'ixpe_det2_bkg_.pha',regionfile='bkg.reg', timefile='NONE', stokes='NEFF', 
              polwcol='W_MOM', tcol='TIME', ecol='PI', xcolf='X', xcolh='X',ycolf='Y', ycolh='Y')
if out.returncode != 0:
    print(out.stdout)
    raise Exception('extractor for det2 failed!')

#Extract background I,Q and U spectra for DU3
out = hsp.extractor(filename=det3_fits, binlc=10.0, eventsout='NONE', imgfile='NONE',fitsbinlc='NONE', 
              phafile= 'ixpe_det3_bkg_.pha',regionfile='bkg.reg', timefile='NONE', stokes='NEFF', 
              polwcol='W_MOM', tcol='TIME', ecol='PI', xcolf='X', xcolh='X',ycolf='Y', ycolh='Y')
if out.returncode != 0:
    print(out.stdout)
    raise Exception('extractor for det3 failed!')
```

### 5.3 Obtaining the Response Files

For the I spectra, you will need to include the RMF (Response Matrix File), and
the ARF (Ancillary Response File). 

For the Q and U spectra, you will need to include the RMF and MRF (Modulation Response File). The MRF is defined by the product of the energy-dependent modulation factor, $\mu$(E) and the ARF.

The location of the calibration files can be obtained through the `hsp.quzcif` tool. Type in `hsp.quzcif?` to get more information on this function. 

Note that the output of the `hsp.quzcif` gives the path to more than one file. This is because there are 3 sets of response files, corresponding to the different weighting schemes. 

- For the 'NEFF' weighting, use 'alpha07_02'.
- For the 'SIMPLE' weighting, use 'alpha075simple_02'. 
- For the 'UNWEIGHTED' version, use '20170101_02'.

```python
# hsp.quzcif?
```

```python
# get the on-axis rmf
res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU1',
             filter='-', date='-', time='-',expr='-',codename='MATRIX')

rmf1 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]

res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU2',
             filter='-', date='-', time='-',expr='-',codename='MATRIX')

rmf2 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]

res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU3',
             filter='-', date='-', time='-',expr='-',codename='MATRIX')

rmf3 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]
```

```python
# get the on-axis arf
res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU1',
             filter='-', date='-', time='-',expr='-',codename='SPECRESP')
arf1 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]

res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU2',
             filter='-', date='-', time='-',expr='-',codename='SPECRESP')
arf2 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]

res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU3',
             filter='-', date='-', time='-',expr='-',codename='SPECRESP')
arf3 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]
```

```python
# get the on-axis mrf
res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU1',
             filter='-', date='-', time='-',expr='-',codename='MODSPECRESP')
mrf1 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]

res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU2',
             filter='-', date='-', time='-',expr='-',codename='MODSPECRESP')
mrf2 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]

res = hsp.quzcif(mission='ixpe', instrument='gpd',detector='DU3',
             filter='-', date='-', time='-',expr='-',codename='MODSPECRESP')
mrf3 = [x.split()[0] for x in res.output if 'alpha075_02'  in x][0]
```


### 5.4 Load data into PyXSPEC and start fitting 

```python

rmf_list = [rmf1,rmf2,rmf3]
mrf_list = [mrf1,mrf2,mrf3]
arf_list = [arf1,arf2,arf3]
du_list = [1,2,3]

xspec.AllData.clear()

x=0 #factor to get the spectrum numbering right 
for (du, rmf_file, mrf_file, arf_file) in zip(du_list, rmf_list, mrf_list, arf_list):

    #Load the I data
    xspec.AllData("%i:%i ixpe_det%i_src_I.pha"%(du, du+x, du))
    xspec.AllData(f"{du}:{du+x} ixpe_det{du}_src_I.pha")
    s = xspec.AllData(du+x)
    
    # #Load response and background files
    s.response = rmf_file
    s.response.arf = arf_file
    s.background = 'ixpe_det%i_bkg_I.pha'%du
    
    #Load the Q data
    xspec.AllData("%i:%i ixpe_det%i_src_Q.pha"%(du, du+x+1, du))
    s = xspec.AllData(du+x+1)
    
    # #Load response and background files
    s.response = rmf_file
    s.response.arf = mrf_file
    s.background = 'ixpe_det%i_bkg_Q.pha'%du
    
    #Load the U data
    xspec.AllData("%i:%i ixpe_det%i_src_U.pha"%(du, du+x+2, du))
    s = xspec.AllData(du+x+2)
    
    # #Load response and background files
    s.response = rmf_file
    s.response.arf = mrf_file
    s.background = 'ixpe_det%i_bkg_U.pha'%du
    
    x+=2

```

```python
#Ignore all channels except 2-8keV
xspec.AllData.ignore("0.0-2.0, 8.0-**")
```

```python jupyter={"source_hidden": true}
model = xspec.Model('polconst*tbabs(constant*powerlaw)')

model.polconst.A = 0.05
model.polconst.psi = -50
model.TBabs.nH = 0.15
model.powerlaw.PhoIndex = 2.7
model.powerlaw.norm = 0.1

# xspec.Fit.perform()

# model.show()
```

```python
m1 = xspec.AllModels(1)
m2 = xspec.AllModels(2)
m3 = xspec.AllModels(3)

m1.constant.factor = 1.0
m1.constant.factor.frozen = True
m2.constant.factor = 0.8
m3.constant.factor = 0.9
```

```python
xspec.AllModels.show()
```

```python
xspec.Fit.perform()
```

### 5.5 Plotting the results

This is done through `matplotlib`.

```python
xspec.Plot.area=True
xspec.Plot.xAxis='keV'
xspec.Plot('lda')
yVals=xspec.Plot.y()
yErr = xspec.Plot.yErr()
xVals = xspec.Plot.x()
xErr = xspec.Plot.xErr()
mop = xspec.Plot.model()


fig, ax = plt.subplots(figsize=(10,6))
ax.errorbar(xVals, yVals, xerr=xErr, yerr=yErr, fmt='k.', alpha=0.2)
ax.plot(xVals, mop,'r-')
ax.set_xlabel('Energy (keV)')
ax.set_ylabel(r'counts/cm$^2$/s/keV')
ax.set_xscale("log")
ax.set_yscale("log")

```

```python
xspec.Plot.area=True
xspec.Plot.xAxis='keV'
xspec.Plot('polangle')
yVals=xspec.Plot.y()
yErr = xspec.Plot.yErr()
xVals = xspec.Plot.x()
xErr = xspec.Plot.xErr()
mop = xspec.Plot.model()


fig, ax = plt.subplots(figsize=(10,6))
ax.errorbar(xVals, yVals, xerr=xErr, yerr=yErr, fmt='k.', alpha=0.2)
ax.plot(xVals, mop,'r-')
ax.set_xlabel('Energy (keV)')
ax.set_ylabel(r'Polangle')
```

## 6. Interpreting the results from XSPEC

There are two parameters of interest in our example. These given by the polarization fraction, A,
and polarization angle, $\psi$. The XSPEC error (or uncertainty) command can be used
to deduce confidence intervals for these parameters. 

We can estimate the 99% confidence interval for these two parameters.

```python
xspec.Fit.error("6.635 1") #Uncertainty on parameter 1
```

```python
xspec.Fit.error("6.635 2") #Uncertainty on parameter 2
```

Of particular interest is the 2-D error contour for the polarization fraction and polarization angle. 

```python
lch = xspec.Xset.logChatter
xspec.Xset.logChatter = 20

# Create and open a log file for XSPEC output. 
# This step can sometimes take a few minutes. Please be patient!
logFile = xspec.Xset.openLog("steppar.txt")

xspec.Fit.steppar("1 0.00 0.21 41 2 -90 0 36")

# Close XSPEC's currently opened log file.
xspec.Xset.closeLog()
```

```python
#Plot the results
xspec.Plot.area=True
xspec.Plot('contour ,,4 1.386, 4.61 9.21 13.81')
yVals=xspec.Plot.y()
xVals = xspec.Plot.x()
zVals = xspec.Plot.z()
levelvals = xspec.Plot.contourLevels()
statval = xspec.Fit.statistic
plt.contour(xVals,yVals,zVals,levelvals)
plt.ylabel('Psi (deg)')
plt.xlabel('A')
plt.errorbar(m1.polconst.A.values[0],m1.polconst.psi.values[0],fmt='+')
```

### 6.1 Determining the flux and calculating MDP


Note that the detection is deemed "highly probable" (confidence C > 99.9%) as
A/$\sigma$ = 4.123 >
$\sqrt(-2 ln(1- C)$ where $\sigma$ = 0.01807 as given by XSPEC above. 

Finally, we can use PIMMS to estimate the Minimum Detectable Polarization (MDP). 

To do this, we first use XSPEC to determine the (model) flux on the 2-8 keV energy range:

```python
xspec.AllModels.calcFlux("2.0 8.0")
```

Then enter the appropriate parameters (power law model with Galactic hydrogen column density
$n_H/10^{22}$ = 0.646, photon index $\Gamma$ = 2.75, 
and flux (average of three detectors) 7.55 x $10^{-11} erg cm^{-2} s^{-1}$ in the 2-8 keV range) into [PIMMS](https://heasarc.gsfc.nasa.gov/cgi-bin/Tools/w3pimms/w3pimms.pl). 

PIMMS returns MDP99 of 5.62% for a 100 ks exposure. Scaling by the actual
mean of exposure time of 97243 s gives an MDP99 of 5.70% meaning that, for an unpolarized source with these physical parameters, an IXPE observation will return a value A > 0.057 only 1% of the time. 

This is consistent with the highly probable detection deduced here of a polarization fraction of 7.45$\pm$1.8%.


## 7. Additional Resources

Visit the IXPE [GOF Website](https://heasarcdev.gsfc.nasa.gov/docs/ixpe/analysis/) and the IXPE [Project Website at MSFC](https://ixpe.msfc.nasa.gov/for_scientists/index.html) for more resources.

```python

```
