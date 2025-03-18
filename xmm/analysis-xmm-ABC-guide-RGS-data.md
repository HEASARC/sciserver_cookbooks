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

<!-- #region editable=true slideshow={"slide_type": ""} -->
# ABC Guide for XMM-Newton -- Chapter 10 (RGS Data Processing)
<hr style="border: 2px solid #fadbac" />

- **Description:** XMM-Newton ABC Guide, Chapter 10.
- **Level:** Beginner
- **Data:** XMM observation of Mkn 421(obsid=0153950701)
- **Requirements:** Must be run using the `HEASARCv6.35` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (April 2024)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 1 January 2025, for SAS v21 and pySAS v1.4.8

<hr style="border: 2px solid #fadbac" />
<!-- #endregion -->

<!-- #region editable=true slideshow={"slide_type": ""} -->
#### Introduction
This tutorial is based on Chapter 10 from the [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide") prepared by the NASA/GSFC XMM-Newton Guest Observer Facility. 
#### Expected Outcome
The ability to process RGS data and prepare it for analysis.
#### SAS Tasks to be Used

- `rgsproc`[(Documentation for epproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/rgsproc/index.html "rgsproc Documentation")
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
This tutorial uses an observation of Mkn 421 (obsid = '0153950701').


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
<!-- #endregion -->

```python editable=true slideshow={"slide_type": ""}
# pySAS imports
import pysas
from pysas.wrapper import Wrapper as w

# Importing Js9
import jpyjs9

# Useful imports
import os
import subprocess

# Imports for plotting
import matplotlib.pyplot as plt
from astropy.visualization import astropy_mpl_style
from astropy.io import fits
from astropy.wcs import WCS
from astropy.table import Table
plt.style.use(astropy_mpl_style)

# set up instance of js9
my_js9 = jpyjs9.JS9(width = 800, height = 800, side=True)
```

<!-- #region editable=true slideshow={"slide_type": ""} -->
### 10.1 : Rerun basic processing
<!-- #endregion -->

<div class="alert alert-block alert-info">
    <b>Note:</b> Running rgsproc on this particular obsid will take A LONG TIME, depending on your machine. Be prepared to wait.
</div>

```python editable=true slideshow={"slide_type": ""}
obsid = '0153950701'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')

odf = pysas.odfcontrol.ODFobject(obsid)
```

We start by reprocessing the data. Since we are only interested in the RGS data we do not have to run `epproc` and `emproc`. By default `basic_setup` will run `epproc`,`emproc`, and `rgsproc`, so we will set `run_epproc` and `run_emproc` to `False`.

We will also use the rgsproc inputs, `orders='1 2' bkgcorrect=no withmlambdacolumn=yes spectrumbinning=lambda`. For this analysis we will also need a single PPS file in addition to the `ODF` files, so we will download it separately. You could alternatively download all of the `ODF` and `PPS` files by setting `level='ALL'`.

```python editable=true slideshow={"slide_type": ""}
rgsproc_args = ["orders='1 2'",
                'bkgcorrect=no',
                'withmlambdacolumn=yes',
                'spectrumbinning=lambda']
odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False,
                run_epproc=False,run_emproc=False,rgsproc_args=rgsproc_args)

odf.download_data(data_dir=data_dir,repo='sciserver',level='PPS',
                  filename='P0153950701OBX000CALIND0000.FTZ')
```

The input arguments for `rgsproc` are:

    orders - dispersion orders to extract
    bkgcorrect - subtract background from source spectra?
    withmlambdacolumn - include a wavelength column in the event file product
    spectrumbinning - accumulate the spectrum either in wavelength or beta space

Note the last keyword, `spectrumbinning`. If you want to merge data from the same orders in RGS1 and RGS2, keep it at the default value `lambda`. If you want to merge data from the same instrument, with different orders, set it to `beta`. Merging spectra is discussed in §10.6.

This takes several minutes, and outputs 12 files per RGS, plus 3 general use FITS files. As before, links to the event list files are stored in `odf.files['R1evt_list']` and `odf.files['R2evt_list']`. Filenames and paths to any spectra produced can be found in `odf.files['R1spectra']` and `odf.files['R2spectra']`.

```python
print(odf.files['R1evt_list'])
print(odf.files['R2evt_list'])
print(odf.files['R1spectra'])
print(odf.files['R2spectra'])
```

<div class="alert alert-block alert-info">
<b>Note:</b> While there is only one event list for each RGS instrument, there are two spectra, one for the first two orders of diffraction. These can be combined to increase the signal to noise ratio, and we will discuss this in §10.6.
</div>


### 10.1.1 : Potentially useful tips for using the pipeline


The pipeline task, rgsproc, is very flexible and can address potential pitfalls for RGS users. In §10.1, we used a simple set of parameters with the task; if this is sufficient for your data (and it should be for most), feel free to skip to later sections, where data filters are discussed. In the following subsections, we will look at the cases of a nearby bright optical source, a nearby bright X-ray source, and a user-defined source.


### 10.1.2 : A Nearby Bright Optical Source

<!-- #region -->
With certain pointing angles, zeroth-order optical light may be reflected off the telescope optics and cast onto the RGS CCD detectors. If this falls on an extraction region, the current energy calibration will require a wavelength-dependent zero-offset. Stray light can be detected on RGS DIAGNOSTIC images taken before, during and after the observation. This test, and the offset correction, are not performed on the data before delivery. Please note that this will not work in every case. If a source is very bright, the diagnostic data that this relies on may not have been downloaded from the telescope in order to save bandwidth. Also, the RGS target itself cannot be the source of optical photons, as the spectrum's zero-order falls far from the RGS chip array. To check for stray light and apply the appropriate offsets, use the following inputs.

```python
rgsproc_args = ["orders='1 2'",
                'bkgcorrect=no',
                'calcoffsets=yes',
                'withoffsethistogram=no']
```

where the parameters are as described in §10.1 and
    
calcoffsets - calculate PHA offsets from diagnostic image    s
withoffsethistogram - produce a histogram of uncalibrated excess for the user
<!-- #endregion -->

### 10.1.3 : A Nearby Bright X-ray Source

<!-- #region editable=true slideshow={"slide_type": ""} -->
In the example above, it is assumed that the field around the source contains sky only. Provided a bright background source is well-separated from the target in the cross-dispersion direction, a mask can be created that excludes it from the background region. Here the source has been identified in the EPIC images and its coordinates have been taken from the EPIC source list which is included among the pipeline products. The bright neighboring object is found to be the third source listed in the sources file. The first source is the target. The inputs would be

```python
rgsproc_args = ["orders='1 2'",
                'bkgcorrect=no',
                'withepicset=yes',
                'epicset=P0153950701EPX000OMSRLI0000.FTZ',
                "exclsrcsexpr='INDEX==1&&INDEX==3'"]
```

where the parameters are as described in §10.1 and

    withepicset - calculate extraction regions for the sources contained in an EPIC source list
    epicset - name of the EPIC source list, such as generated by emldetect or eboxdetect procedures
    exclsrcsexpr - expression to identify which source(s) should be excluded from the background extraction region

<div class="alert alert-block alert-warning">
    <b>Notice:</b> This method uses an <b>OMSRLI</b> file which is found in the pipeline products (PPS). <b>OMSRLI</b> stands for Observation Maximum-Likelihood Source List, in this case OM does <i>not</i> stand for 'Optical Monitor'. We downloaded this file at the beginning. The file will be in the '$data_dir/obsid/PPS/' directory.
</div>
<!-- #endregion -->

### 10.1.4 : User-defined Source Coordinates

<!-- #region -->
If the true coordinates of an object are not included in the EPIC source list or the science proposal, the user can define the coordinates of a new source by typing:

```python
rgsproc_args = ["orders='1 2'",
                'bkgcorrect=no',
                'withsrc=yes',
                'srclabel=Mkn421',
                'srcstyle=radec',
                'srcra=166.113808',
                'srcdec=+38.208833']
```

where the parameters are as described in §10.1 and

    withsrc - make the source be user-defined
    srclabel - source name
    srcstyle - coordinate system in which the source position is defined
    srcra - the source's right ascension in decimal degrees
    srcdec - the source's declination in decimal degrees
    
Since the event files are current, we can proceed with some simple analysis demonstrations, which will allow us to generate filters. Rememer that all tasks should be called from the work directory, and that tasks place output files in whatever directory you are in when they are called.
<!-- #endregion -->

### 10.2 : Create and Display an Image


Two commonly-made plots are those showing PI vs. BETA_CORR (also known as 'banana plots') and XDSP_CORR vs. BETA_CORR.

The input arguments to `evselect` to create these FITS image files are:

    table - input event table
    withimageset - make an image
    imageset - name of output image
    xcolumn - event column for X axis
    ycolumn - event column for Y axis
    imagebinning - form of binning, force entire image into a given size or bin by a specified number of pixels
    ximagesize - output image pixels in X
    yimagesize - output image pixels in Y

```python editable=true slideshow={"slide_type": ""}
def make_fits_image(event_list_file, image_file='image.fits', xcolumn='BETA_CORR', ycolumn='PI', expression=None):
    
    inargs = {}
    inargs['table']        = event_list_file+':EVENTS'
    inargs['withimageset'] = 'yes'
    inargs['imageset']     = image_file
    inargs['xcolumn']      = xcolumn
    inargs['ycolumn']      = ycolumn
    inargs['imagebinning'] = 'imageSize'
    inargs['ximagesize']   = '600'
    inargs['yimagesize']   = '600'
    if expression != None:
        inargs['expression'] = expression
    
    w('evselect', inargs).run()

    with fits.open(image_file) as hdu:
        my_js9.SetFITS(hdu)
        my_js9.SetColormap('heat',1,0.5)
        my_js9.SetScale("log")
        
    return image_file
```

```python
os.chdir(odf.work_dir)
R1_event_list = odf.files['R1evt_list'][0]
R2_event_list = odf.files['R2evt_list'][0]
make_fits_image(R1_event_list,image_file='pi_bc.fits')
make_fits_image(R1_event_list,image_file='xd_bc.fits', xcolumn='BETA_CORR', ycolumn='XDSP_CORR')
```

### 10.3 : Create and Display a Light Curve


The background is assessed through examination of the light curve. We will extract a region, CCD9, that is most susceptible to proton events and generally records the least source events due to its location close to the optical axis. Also, to avoid confusing solar flares for source variability, a region filter that removes the source from the final event list should be used. The region filters are kept in the source file product `*SRCLI_*.FIT`. `rgsproc` outputs an `M_LAMBDA` column which can be used to generate the light curve. (The `*SRCLI_*.FIT` file that came with the PPS products contains a `BETA_CORR` column if you prefer to use that instead.)

The input arguments to `evselect` to create a light curve file are:

    table - input event table
    withrateset - make a light curve
    rateset - name of output light curve file
    maketimecolumn - control to create a time column
    timecolumn - time column label
    timebinsize - time binning (seconds)
    makeratecolumn - control to create a count rate column, otherwise a count column will be created
    expression - filtering expression


```python editable=true slideshow={"slide_type": ""}
def plot_light_curve(event_list_file, light_curve_file='ltcrv.fits',expression=None):
                     
    inargs = {'table': event_list_file, 
              'withrateset': 'yes', 
              'rateset': light_curve_file, 
              'maketimecolumn': 'yes', 
              'timecolumn': 'TIME', 
              'timebinsize': '50', 
              'makeratecolumn': 'yes'}

    if expression != None:
        inargs['expression'] = expression

    w('evselect', inargs).run()

    ts = Table.read(light_curve_file,hdu=1)
    plt.plot(ts['TIME'],ts['RATE'])
    plt.xlabel('Time (s)')
    plt.ylabel('Count Rate (ct/s)')
    plt.show()
```

Sometimes, it is necessary to use filters on time in addition to those mentioned above. This is because of soft proton background flaring, which can have count rates of 100 counts/sec or higher across the entire bandpass.

To determine if our observation is affected by background flaring, we can examine the light curve. For the time binning, we will set it to something reasonable such as 50 s (usually between 10 and 100 s).

```python
light_curve_file='r1_ltcrv.fits'

expression = '(CCDNR==9)&&(REGION(P0153950701R1S001SRCLI_0000.FIT:RGS1_BACKGROUND,M_LAMBDA,XDSP_CORR))'
plot_light_curve(R1_event_list, light_curve_file=light_curve_file, expression=expression)
```

### 10.4.1 : Generating the Good Time Interval (GTI) File


Examination of the lightcurve shows that there is a loud section at the end of the observation, after 1.36975e8 seconds, where the count rate is well above the quiet count rate of $\sim$ 0.05-0.2 count/second. To remove it, we need to make an additional Good Time Interval (GTI) file and apply it by rerunning `rgsproc`.

The filtering is done in a similar way as is shown in <a href="./xmm_ABC_guide_images_and_filters.ipynb">Chapter 6 of the XMM-Newton ABC Guide</a>. We will show one of the four filtering methods demonstrated in Chapter 6. The difference is that after the GTI file is made we apply it by rerunning `rgsproc` instead of filtering the event list using `evselect`. We use the light curve `r1_ltcrv.fits` we just created in the previous section.

If we look at the light curve we just made we see that the typical count rate for this observation is $\sim$ 0.05 ct/s. We can apply a rate limit of $<=$ 0.2 ct/s.

```python
gti_file = 'gti.fits'

inargs = ['table={0}'.format(light_curve_file), 
          'gtiset={0}'.format(gti_file),
          'timecolumn=TIME', 
          "expression='(RATE <= 0.2)'"]

w('tabgtigen', inargs).run()
```

### 10.4.2 : Apply the new GTI


Now that we have a GTI file, we can apply it by running `rgsproc` again. `rgsproc` is a complex task, running several steps, with five different entry and exit points. It is not necessary to rerun all the steps in the procedure, only the ones involving filtering.

To apply the GTI file we run:

<div class="alert alert-block alert-info">
    <b>Note:</b> This will overwrite the original event list created when we ran <b>rgsproc</b> at the beginning.</div>

```python
inargs = ["orders='1 2'",
          'auxgtitables={0}'.format(gti_file),
          'bkgcorrect=no',
          'withmlambdacolumn=yes',
          'entrystage=3:filter',
          'finalstage=5:fluxing']

w('rgsproc', inargs).run()
```

where

    orders - spectral orders to be processed
    auxgtitables - gti file in FITS format
    bkgcorrect - subtract background from source spectra?
    withmlambdacolumn - include a wavelength column in the event file product
    entrystage - stage at which to begin processing
    finalstage - stage at which to end processing


### 10.5 : Creating the Response Matrices (RMFs)

<!-- #region editable=true slideshow={"slide_type": ""} -->
<div class="alert alert-block alert-info">
<b>Note:</b > This is for demonstration purposes only. The task <i>rgsproc</i> will automatically generate response matrices (RMFs), and the RMFs are also included in the downloaded PPS files.
</div>

As noted in §10.1.4, the source coordinates are under the observer's control. The source coordinates have a profound influence on the accuracy of the wavelength scale as recorded in the RMF that is produced automatically by `rgsproc`, thus if you made any changes in the source coordinates you will have to generate new RMFs.

<div class="alert alert-block alert-info">
<b>Note:</b> Each RGS instrument and each order will have its own RMF. If the user modifies the source coordinates, a new RMF will need to be created for each RGS instrument and each order.
</div>

Making the RMF is easily done with the package `rgsrmfgen`. Please note that, unlike with EPIC data, it is not necessary to make ancillary response files (ARFs). Below we demonstrate generating RMFs for RGS1 and RGS2, but only for the first order.
<!-- #endregion -->

```python
rmf1_file = 'r1_o1_rmf.fits'
rmf2_file = 'r2_o1_rmf.fits'

inargs = {}
inargs['spectrumset'] = odf.files['R1spectra'][0]
inargs['rmfset']      = rmf1_file
inargs['evlist']      = R1_event_list
inargs['emin']        = '0.4'
inargs['emax']        = '2.5'
inargs['rows']        = '4000'

w('rgsrmfgen', inargs).run()

inargs['spectrumset'] = odf.files['R2spectra'][0]
inargs['rmfset']      = rmf2_file
inargs['evlist']      = R2_event_list

w('rgsrmfgen', inargs).run()
```

where

    spectrumset - spectrum file
    evlist - event file
    emin - lower energy limit of the response file
    emax - upper energy limit of the response file
    rows - number of energy bins; this should be greater than 3000
    rmfset - output FITS file
    
RMFs for the RGS1 2nd order, and for the RGS2 1st and 2nd orders, are made in a similar way. At this point, the spectra can be analyzed or combined with other spectra.


### 10.6 : Combining Spectra


Spectra from the same order in RGS1 and RGS2 can be safely combined to create a spectrum with higher signal-to-noise if they were reprocessed using `rgsproc` with `spectrumbinning=lambda`, as we did in §10.1 (this also happens to be the default). (Spectra of different orders, from one particular instrument, can also be merged if they were reprocessed using `rgsproc` with `spectrumbinning=beta`.) The task `rgscombine` also merges response files and background spectra. When merging response files, be sure that they have the same number of bins. For this example, we will use the RMFs that were made using `rgsproc` for order 1 in both RGS1 and RGS2.

To merge the first order RGS1 and RGS2 spectra we run,

```python
inargs = {}
inargs['pha']     = '{0} {1}'.format(odf.files['R1spectra'][0],odf.files['R2spectra'][0])
inargs['rmf']     = 'P0153950701R1S001RSPMAT1001.FIT P0153950701R2S002RSPMAT1001.FIT'
inargs['bkg']     = 'P0153950701R1S001BGSPEC1001.FIT P0153950701R2S002BGSPEC1001.FIT'
inargs['filepha'] = 'r12_o1_srspec.fits'
inargs['filermf'] = 'r12_o1_rmf.fits'
inargs['filebkg'] = 'r12_o1_bgspec.fits'
#inargs['rmfgrid'] = 4000

w('rgscombine', inargs).run()
```

where

    pha - list of spectrum files
    rmf - list of response matrices
    bkg - list of bakcground spectrum files
    filepha - output merged spectrum
    filermf - output merged response matrix
    filebkg - output merged badkground spectrum
    rmfgrid - number of energy bins; should be the same as the input RMFs (i.e. should match the input `rows` for `rgsrmfgen`)
    
The spectra are ready for analysis. To prepare the spectrum for fitting please consult [Chapter 14 in the ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/node16.html#Chap:rgs-fit-xspec).

```python

```
