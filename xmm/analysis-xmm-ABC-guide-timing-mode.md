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

# ABC Guide for XMM-Newton -- Chapter 8 (Timing Data Processing)
<hr style="border: 2px solid #fadbac" />

- **Description:** XMM-Newton ABC Guide, Chapter 8.
- **Level:** Beginner
- **Data:** XMM observation of Cen X-3 (obsid=0400550201)
- **Requirements:** Must be run using the `HEASARCv6.34` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (April 2024)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 1 January 2025, for SAS v21 and pySAS v1.4.6

<hr style="border: 2px solid #fadbac" />


# ABC Guide for XMM-Newton -- Chapter 8 (Timing Mode)

---

#### Introduction
This tutorial is based on Chapter 8 from the [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide") prepared by the NASA/GSFC XMM-Newton Guest Observer Facility. 
#### Expected Outcome
The ability to process EPIC data in the timing mode and prepare it for analysis.
#### SAS Tasks to be Used

- `epproc`[(Documentation for epproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html "epproc Documentation")
- `evselect`[(Documentation for evselect)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/evselect/index.html)
- `tabgtigen`[(Documentation for tabgtigen)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/tabgtigen/index.html)
- `gtibuild`[(Documentation for gtibuild)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/gtibuild/index.html)

#### Useful Links

- [`pysas` Documentation](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/pysas/index.html "pysas Documentation")
- [`pysas` on GitHub](https://github.com/XMMGOF/pysas)
- [Common SAS Threads](https://www.cosmos.esa.int/web/xmm-newton/sas-threads "SAS Threads")
- [Users' Guide to the XMM-Newton Science Analysis System (SAS)](https://xmm-tools.cosmos.esa.int/external/xmm_user_support/documentation/sas_usg/USG/SASUSG.html "Users' Guide")
- [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide")
- [XMM Newton GOF Helpdesk](https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html "Helpdesk") - Link to form to contact the GOF Helpdesk.

#### Caveats
This tutorial uses an observation of Cen X-3 (obsid = '0400550201').

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
# pySAS imports
import pysas
from pysas.wrapper import Wrapper as w

# Useful imports
import os
import subprocess
import jpyjs9

# Imports for plotting
import matplotlib.pyplot as plt
from astropy.visualization import astropy_mpl_style
from astropy.io import fits
from astropy.wcs import WCS
from astropy.table import Table
plt.style.use(astropy_mpl_style)

my_js9 = jpyjs9.JS9(width = 800, height = 800, side=True)
```

### 8.1 : Rerun basic processing


<div class="alert alert-block alert-info">
    <b>Note:</b> Running epproc and emproc on this particular obsid will take A LONG TIME, depending on your machine. Be prepared to wait.
</div>

```python
obsid = '0400550201'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')

odf = pysas.odfcontrol.ODFobject(obsid)
odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False,run_rgsproc=False,run_emproc=False)
```

We start by reprocessing the data. The SAS task `epproc` will automatically detect if the data was taken in either imaging mode or timing mode.

We also note that for this particular observation not all instruments were used. Which instruments were active for this observation is stored in a dictionary in the `odf` object. This data is contained in the ODF summary file, `sas_odf`.

```python
odf.active_instruments
```

We see that only one of the MOS cameras was used, both RGS, the pn, but not the optical monitor. In this case we only care about the pn.


### 8.2 : Create and Display an Image

<!-- #region -->
Below we define a useful function to make image plotting easier. It uses `evselect` to create a FITS image file from a FITS event list file. As a default it creates a file named "image.fits" and this file will be overwritten each time the function is called. If you want your image file to have a unique name then use the function input "image_file". For example:

```python
make_fits_image('event_list_file.fits', image_file='my_special_image.fits')
```
---
The input arguments to `evselect` to create a FITS image file are:

    table - input event list file name
    withimageset - make an image
    imageset - name of output image file
    xcolumn - event column for X axis
    ycolumn - event column for Y axis
    imagebinning - form of binning, force entire image into a given size or bin by a specified number of pixels
    ximagebinsize - output X bin sizes in pixels
    yimagebinsize - output Y bin sizes in pixels
<!-- #endregion -->

<div class="alert alert-block alert-info">
    <b>Note:</b> The inputs for evselect are slightly different from inputs used for plotting in the Jupyter Notebook for Chapter 6, Part 1 of the ABC Guide. In that notebook the image was binned to a total number of pixels in the X and Y directions. Here the detector pixels are binned using a set bin size, in this case "1" in both the X and Y directions.
</div>

```python
def make_fits_image(event_list_file, image_file='image.fits', expression=None):
    
    inargs = {}
    inargs['table']        = event_list_file
    inargs['withimageset'] = 'yes'
    inargs['imageset']     = image_file
    inargs['xcolumn']      = 'RAWX'
    inargs['ycolumn']      = 'RAWY'
    inargs['imagebinning'] = 'binSize'
    inargs['ximagebinsize']   = '1'
    inargs['yimagebinsize']   = '1'
    if expression != None:
        inargs['expression'] = expression
    
    w('evselect', inargs).run()

    with fits.open(image_file) as hdu:
        my_js9.SetFITS(hdu)
        my_js9.SetColormap('heat',1,0.5)
        my_js9.SetScale("log")

    return image_file
```

We also define a function to make plotting light curves simpler. As with the function `make_fits_image` it uses `evselect` to create the light curve. It also creates a default light curve FITS file.

---
The input arguments to `evselect` to create a light curve file are:

    table - input event table
    withrateset - make a light curve
    rateset - name of output light curve file
    maketimecolumn - control to create a time column
    timecolumn - time column label
    timebinsize - time binning (seconds)
    makeratecolumn - control to create a count rate column, otherwise a count column will be created


```python
def plot_light_curve(event_list_file, light_curve_file='ltcrv.fits'):
                     
    inargs = {'table': event_list_file, 
              'withrateset': 'yes', 
              'rateset': light_curve_file, 
              'maketimecolumn': 'yes', 
              'timecolumn': 'TIME', 
              'timebinsize': '50', 
              'makeratecolumn': 'yes'}

    w('evselect', inargs).run()

    ts = Table.read(light_curve_file,hdu=1)
    plt.plot(ts['TIME'],ts['RATE'])
    plt.xlabel('Time (s)')
    plt.ylabel('Count Rate (ct/s)')
    plt.show()
```

We need to change into the work directory to run the next SAS tasks. We also get the name and path to the event list file created in §8.1.

```python
os.chdir(odf.work_dir)
pn_burst           = odf.files['PNevt_list'][0]
basic_filter_file  = 'pn_basic_filter.fits'
basic_filter_image = 'pn_basic_image.fits'
basic_filter_ltcrv = 'basic_filter_ltcrv.fits'
final_filter_image = 'final_filter_image.fits'
source_pi_file     = 'source_pi_WithBore.fits'
bkg_pi_file        = 'bkg_pi.fits'
pn_spectra_file    = 'pn_filt_source_WithBore.fits'
pn_bkg_file        = 'pn_filt_bkg.fits'
```

Here we plot an image of the raw data with no filters applied.

```python
make_fits_image(pn_burst)
```

```python
plot_light_curve(pn_burst)
```

### 8.3 : Apply Standard Filter


The filtering expression for the PN in Timing mode is:
```
(PATTERN <= 4)&&(PI in [200:15000])&&#XMMEA_EP
```
The first two expressions will select good events with PATTERN in the 0 to 4 range. The PATTERN value is similar the GRADE selection for ASCA data, and is related to the number and pattern of the CCD pixels triggered for a given event. Single pixel events have PATTERN == 0, while double pixel events have PATTERN in [1:4].

The second keyword in the expressions, PI, selects the preferred pulse height of the event; for the PN, this should be between 200 and 15000 eV. This should clean up the image significantly with most of the rest of the obvious contamination due to low pulse height events. Setting the lower PI channel limit somewhat higher (e.g., to 300 or 400 eV) will eliminate much of the rest. Here we will use a lower limit of 4.

Finally, the #XMMEA_EP filter provides a canned screening set of FLAG values for the event. (The FLAG value provides a bit encoding of various event conditions, e.g., near hot pixels or outside of the field of view.) Setting FLAG == 0 in the selection expression provides the most conservative screening criteria and should always be used when serious spectral analysis is to be done on PN data.

```python
inargs = {'table': pn_burst, 
          'withfilteredset': 'yes', 
          'expression': "'(PATTERN <= 4)&&(PI in [200:15000])&&#XMMEA_EP'", 
          'filteredset': basic_filter_file, 
          'filtertype': 'expression', 
          'keepfilteroutput': 'yes', 
          'updateexposure': 'yes', 
          'filterexposure': 'yes'}

w('evselect', inargs).run()
inargs = {}

make_fits_image(basic_filter_file, image_file=basic_filter_image)
```

### 8.4 : Create and Display a Light Curve


Sometimes, it is necessary to use filters on time in addition to those mentioned above. This is because of soft proton background flaring, which can have count rates of 100 counts/sec or higher across the entire bandpass.

To determine if our observation is affected by background flaring, we can examine the light curve. For the time binning, we will set it to something reasonable (usually between 10 and 100 s).

```python
plot_light_curve(basic_filter_file, light_curve_file=basic_filter_ltcrv)
```

In this case no flares are evident, so we will continue to the next section. However, if a dataset does contain flares, they should be removed in the same way as shown for EPIC Imaging mode data in §6.5.


### 8.5 : Extract the Source and Background Spectra


The first step in extracting a spectrum from PN Timing data is to make an image of the event file over the energy range we are interested in; for this example, we'll say 0.5-15 keV. And since this is the PN, we need to remember to set `(FLAG==0)` to get a high-quality spectrum. Thus, our expression parameter would be set to `(FLAG==0) && (PI in [500:15000])`, and we make a new image using this expression.

```python
make_fits_image(basic_filter_file, image_file=final_filter_image, 
                expression="'(FLAG==0) && (PI in [500:15000])'")
```

The source is centered on `RAWX=37`; we will extract this and the 10 pixels on either side of it:

```python
expression = "'(FLAG==0) && (PI in [500:15000]) && (RAWX in [27:47])'"
```

```python
inargs = {}
inargs['table']           = basic_filter_file
inargs['spectrumset']     = source_pi_file
inargs['energycolumn']    = 'PI'
inargs['spectralbinsize'] = '5'
inargs['specchannelmin']  = '0'
inargs['specchannelmax']  = '20479'
inargs['withfilteredset'] = 'yes'
inargs['filteredset']     = pn_spectra_file
inargs['expression']      = expression

w('evselect', inargs).run()
```

For the background, the extraction area should be as far from the source as possible. However, sources with > 200 ct/s (like our example!) are so bright that they dominate the entire CCD area, and there is no source-free region from which to extract a background. (It goes without saying that this is highly energy-dependent.) In such a case, it may be best not to subtract a background. Users are referred to Ng et al. (2010, A&A, 522, 96) for an in-depth discussion. While this observation is too bright to have a good background extraction region, the process is shown below nonetheless for the sake of demonstration:

```python
expression = "'(FLAG==0) && (PI in [500:15000]) && (RAWX in [3:5])'"
```

```python
inargs = {}
inargs['table']           = basic_filter_file
inargs['withspectrumset'] = 'yes'
inargs['spectrumset']     = bkg_pi_file
inargs['energycolumn']    = 'PI'
inargs['spectralbinsize'] = '5'
inargs['withspecranges']  = 'yes'
inargs['specchannelmin']  = '0'
inargs['specchannelmax']  = '20479'
inargs['withfilteredset'] = 'yes'
inargs['filteredset']     = pn_bkg_file
inargs['expression']      = expression

w('evselect', inargs).run()
```

### 8.6 : Check for Pile Up


Depending on how bright the source is and what modes the EPIC detectors are in, event pile up may be a problem. Pile up occurs when a source is so bright that incoming X-rays strike two neighboring pixels or the same pixel in the CCD more than once in a read-out cycle. In such cases the energies of the two events are in effect added together to form one event. If this happens sufficiently often, 

    1. The spectrum will appear to be harder than it actually is, and 
    2. The count rate will be underestimated, since multiple events will be undercounted. 

Briefly, we deal with it in PN Timing data essentially the same way as in Imaging data, that is, by using only single pixel events, and/or removing the regions with very high count rates, checking the amount of pile up, and repeating until it is no longer a problem. We recommend to always check for it.

Note that this procedure requires as input the event files created when the spectrum was made (i.e. `pn_spectra_file = 'pn_filt_source_WithBore.fits'`), not the usual time-filtered event file.

```python
inargs = ['set={0}'.format(pn_spectra_file),
          'plotfile=pn_epat.ps',
          'useplotfile=yes',
          'withbackgroundset=yes',
          'backgroundset={0}'.format(pn_bkg_file)]

w('epatplot', inargs).run()
```

The output of `epatplot` is a postscript file, `pn_epat.ps`, which may be viewed with a postscript viewer such as `gv` (i.e. 'ghostscript viewer'). At the moment there is no way to view a postscript file on SciServer so to view it you will have to download `pn_epat.ps` to your local machine to view it. If you do not have `gv` installed on your local machine, install it from a terminal using `sudo apt install gv`. Then from the download directory you can run `gv pn_epat.ps` to view the graphs. In the postscript image there are two graphs describing the distribution of counts as a function of PI channel. You should get a plot like that shown below.


<center><img src="_files/timing_epatplot.png"/></center>


A few words about interpretting the plots are in order. The top is the distribution of counts versus PI channel for each pattern class (single, double, triple, quadruple), and the bottom is the expected pattern distribution (smooth lines) plotted over the observed distribution (line with noise). The lower plot shows the model distributions for single and double events and the observed distributions. It also gives the ratio of observed-to-modeled events with $1-\sigma$ uncertainties for single and double pattern events over a given energy range. (The default is 0.5-2.0 keV; this can be changed with the `pileupnumberenergyrange` parameter.) If the data is not piled up, there will be good agreement between the modeled and observed single and double event pattern distributions. Also, the observed-to-modeled fractions for both singles and doubles in the 0.5-2.0 keV range will be unity, within errors. In contrast, if the data is piled up, there will be clear divergence between the modeled and observed pattern distributions, and the observed-to-modeled fraction for singles will be less than 1.0, and for doubles, it will be greater than 1.0.

Finally, when examining the plots, it should noted that the observed-to-modeled fractions can be inaccurate. Therefore, the agreement between the modeled and observed single and double event pattern distributions should be the main factor in determining if an observation is affected by pile up or not.

Examining the plots, we see that there is a large difference between the modeled and observed single and double pattern events at $> 1.0$ keV, but this divergence is not reflected in the observed-to-model fractions since for singles it is $> 1.0$ with $1.011\pm 0.001$, and for doubles it is $<1.0$ with $0.977\pm 0.001$.

To capture the pile up we need to extend the energy range for the observed-to-model fraction calculations. The default is $500-2000$ eV. Let us set the range to $1000-5000$ eV.

```python
inargs = ['set={0}'.format(pn_spectra_file),
          'plotfile=pn_epat.ps',
          'useplotfile=yes',
          'pileupnumberenergyrange=1000 5000',
          'withbackgroundset=yes',
          'backgroundset={0}'.format(pn_bkg_file)]

w('epatplot', inargs).run()
```

<center><img src="_files/timing_epatplot2.png"/></center>


Now the cacluated observed-to-model fractions are $0.988\pm 0.001$ for singles, and $1.121\pm 0.001$ for doubles. This shows clear evidence of pile up.


### 8.7 : My Observation is Piled Up! Now What?

<!-- #region -->
There are a couple ways to deal with pile up. First, you can use event file filtering procedures to include only single pixel events `(PATTERN==0)`, as these events are less sensitive to pile up than other patterns.

You can also excise areas of high count rates, i.e., the boresight column and several columns to either side of it. (This is analogous to removing the inner-most regions of a source in Imaging data.) The spectrum can then be re-extracted and you can continue your analysis on the excised event file. As with Imaging data, it is recommended that you take an iterative approach: remove an inner region, extract a spectrum, check with epatplot, and repeat, each time removing a slightly larger region, until the model and observed pattern distributions agree.

To extract only the columns to either side of the boresight using the following expression when running `evselect`. All other inputs are the same as in §8.5.

<div class="alert alert-block alert-info">
    <b>Note:</b> We will not do the additional filtering for pile up here. We will just show the expression and inputs below. If you are only concerned with lower energies in the range of 500-2000 eV then pile up does not significantly affect this observation. But if you are interested in higher energies > 2000 eV, then you will need to correct for pile up. We recommend checking for pile up in the energy range you are interested in by using the <i>pileupnumberenergyrange</i> input for <i>epatplot</i>.
</div>

```python
expression = "'(FLAG==0)&&(PI in [500:15000])&&(RAWX in [3:5])&&!(RAWX in [29:45])'"

inargs = {}
inargs['table']           = basic_filter_file
inargs['withspectrumset'] = 'yes'
inargs['spectrumset']     = source_pi_file
inargs['energycolumn']    = 'PI'
inargs['spectralbinsize'] = '5'
inargs['withspecranges']  = 'yes'
inargs['specchannelmin']  = '0'
inargs['specchannelmax']  = '20479'
inargs['withfilteredset'] = 'yes'
inargs['filteredset']     = pn_spectra_file
inargs['expression']      = expression

w('evselect', inargs).run()
```
<!-- #endregion -->

### 8.8 : Determine the Spectrum Extraction Areas


Now that we are confident that our spectrum is not piled up, we can continue by finding the source and background region areas. (This process is identical to that used for IMAGING data.) This is done with the task backscale, which takes into account any bad pixels or chip gaps, and writes the result into the BACKSCAL keyword of the spectrum table.

The inputs are:

    -spectrumset - (input) spectrum file
    -badpixlocation - (output) event file containing the bad pixels

```python
inargs = ['spectrumset={0}'.format(source_pi_file),
          'badpixlocation=pn_filt.fits']

w('backscale', inargs).run()
```

```python
inargs = ['spectrumset={0}'.format(bkg_pi_file),
          'badpixlocation=pn_filt.fits']

w('backscale', inargs).run()
```

### 8.9 : Create the Photon Redistribution Matrix (RMF) and Ancillary File (ARF)


Making the RMF and ARF for PN data in `TIMING` mode is exactly the same as in `IMAGING` mode, even if you had to excise piled up areas.

To make the RMF use `rmfgen`. The inputs are:

    -rmfset - output file
    -spectrumset - spectrum file

rmfgen rmfset=source_rmf_NoBore.fits spectrumset=source_pi_NoBore.fits

To make the ARF use `arfgen`. The inputs are:

    -arfset - output file
    -spectrumset - spectrum file
    -arfset - output file
    -detmaptype - origin of the detector map
    -withrmfset - use the RMF dataset to define the ARF energy grid?
    -rmfset - RMF file
    -badpixlocation - the file containing the bad pixel locations

```python
inargs = ['rmfset=source_rmf_NoBore.fits',
          'spectrumset={0}'.format(source_pi_file)]

w('rmfgen', inargs).run()
```

```python
inargs = ['arfset=source_arf_NoBore.fits',
          'spectrumset={0}'.format(source_pi_file),
          'detmaptype=psf',
          'withrmfset=yes',
          'rmfset=source_rmf_NoBore.fits',
          'badpixlocation=pn_filt.fits']

w('arfgen', inargs).run()
```

At this point, the spectrum is ready to be analyzed. How to fit the spectrum is explained in [Chapter 13 of the ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/node15.html#Chap:epic-fit-xspec).
