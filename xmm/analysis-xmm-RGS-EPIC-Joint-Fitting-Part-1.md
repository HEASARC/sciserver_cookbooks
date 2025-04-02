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
# ABC Guide for XMM-Newton -- RGS+EPIC Joint Spectral Fitting Part 1: Data Processing
<hr style="border: 2px solid #fadbac" />

- **Description:** XMM-Newton - Spectral Fitting Introduction
- **Level:** Advanced
- **Data:** XMM observation of Mkn 509 (obsid=0601390201)
- **Requirements:** Must be run using the `HEASARCv6.35` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Jenna Cann (March 2025)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 28 March 2025, for SAS v22.1 and pySAS v1.4.8

<hr style="border: 2px solid #fadbac" />
<!-- #endregion -->

<!-- #region editable=true slideshow={"slide_type": ""} -->
#### Introduction
This tutorial was created to guide XMM users through 
an example analysis of RGS and EPIC spectra. This is Part 1, where we will reduce and prepare the data for analysis in Part 2. 
#### Expected Outcome
The ability to fit RGS and EPIC spectra
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
This tutorial uses an observation of Mkn 509 (obsid = '0601390201').


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

import xspec

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
### Rerun basic processing
<!-- #endregion -->

```python editable=true slideshow={"slide_type": ""}
obsid = '0601390201'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')

odf = pysas.odfcontrol.ODFobject(obsid)
```

We start by reprocessing the data. As we will be jointly fitting the MOS and RGS data, we will set run_emproc and run_rgsproc to 'True' and run_epproc to 'False'.


<div class="alert alert-block alert-info">
    <b>Note:</b> Running rgsproc on this particular obsid will take A LONG TIME, depending on your machine. Be prepared to wait.
</div>

```python editable=true slideshow={"slide_type": ""}
rgsproc_args = ["orders='1 2'",
                'bkgcorrect=no',
                'withmlambdacolumn=yes',
                'spectrumbinning=lambda']

odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False,
                run_epproc=True,run_emproc=True,run_rgsproc=True,rgsproc_args=rgsproc_args)
```

As we are processing both RGS and EPIC data, the above task will take several minutes. We will also follow the standard process for filtering EPIC data and extracting spectra from chapter 6 of the ABC guide.

```python
mos1 = odf.files['M1evt_list'][0]
mos2 = odf.files['M2evt_list'][0]
pn = odf.files['PNevt_list'][0]

print(mos1)
print(mos2)
print(pn)
```

```python
filtered_event_list_mos1 = 'mos1_filt1.fits'
filtered_event_list_mos2 = 'mos2_filt1.fits'
filtered_event_list_pn = 'pn_filt1.fits'

inargs = ['table={0}'.format(mos1), 
          'withfilteredset=yes', 
          "expression='(PATTERN <= 12)&&(PI in [200:12000])&&#XMMEA_EM'", 
          'filteredset={0}'.format(filtered_event_list_mos1), 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()

inargs = ['table={0}'.format(mos2), 
          'withfilteredset=yes', 
          "expression='(PATTERN <= 12)&&(PI in [200:12000])&&#XMMEA_EM'", 
          'filteredset={0}'.format(filtered_event_list_mos2), 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()

inargs = ['table={0}'.format(pn), 
          'withfilteredset=yes', 
          "expression='(PATTERN <= 4)&&(PI in [200:15000])&&#XMMEA_EP'", 
          'filteredset={0}'.format(filtered_event_list_pn), 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```

Functions for generating images and light curves.

```python
def make_fits_image(event_list_file, image_file='image.fits'):
    
    inargs = ['table={0}'.format(event_list_file), 
              'withimageset=yes',
              'imageset={0}'.format(image_file), 
              'xcolumn=X', 
              'ycolumn=Y', 
              'imagebinning=imageSize', 
              'ximagesize=600', 
              'yimagesize=600']

    w('evselect', inargs).run()

    with fits.open(image_file) as hdu:
        my_js9.SetFITS(hdu)
        my_js9.SetColormap('heat',1,0.5)
        my_js9.SetScale("log")
    
    return image_file

def plot_light_curve(event_list_file, filtered_event_list, light_curve_file, ccd):
    
    inargs = ['table={0}'.format(event_list_file), 
              'withfilteredset=yes', 
              "expression='(PATTERN == 0)&&(PI in [10000:12000])&&#XMMEA_{:s}'".format(ccd), 
              'filteredset={0}'.format(filtered_event_list), 
              'filtertype=expression', 
              'keepfilteroutput=yes', 
              'updateexposure=yes', 
              'filterexposure=yes']

    w('evselect', inargs).run()

    inargs = ['table={0}'.format(filtered_event_list), 
              'withrateset=yes', 
              'rateset={0}'.format(light_curve_file), 
              'maketimecolumn=yes', 
              'timecolumn=TIME', 
              'timebinsize=100', 
              'makeratecolumn=yes']

    w('evselect', inargs).run()

    ts = Table.read(light_curve_file,hdu=1)
    plt.plot(ts['TIME'],ts['RATE'])
    plt.xlabel('Time (s)')
    plt.ylabel('Count Rate (ct/s)')
    plt.show()
```

This particular observation is not contaminated with flaring, but as best practice we check the light curves to confirm that everything looks good. The light curves for a constant source like the one we are analyzing should remain fairly constant (with some noise of course). For your own sources you should of course check the light curves to check for contamination from flaring.

```python
light_curve_file_mos1='mos1_ltcrv.fits'
filtered_gtr10_mos1 = 'mos1_gtr10.fits'
plot_light_curve(filtered_event_list_mos1, filtered_gtr10_mos1, light_curve_file_mos1, 'EM')

light_curve_file_mos2='mos2_ltcrv.fits'
filtered_gtr10_mos2 = 'mos2_gtr10.fits'
plot_light_curve(filtered_event_list_mos2, filtered_gtr10_mos2, light_curve_file_mos2, 'EM')

light_curve_file_pn='pn_ltcrv.fits'
filtered_gtr10_pn = 'pn_gtr10.fits'
plot_light_curve(filtered_event_list_pn, filtered_gtr10_pn, light_curve_file_pn, 'EP')
```

```python
def make_spectrum(filtered_event_list, filtered_source, filtered_bkg, source_spectrum_file, bkg_spectrum_file, source_coords, bkg_coords, specchannelmax):

    inargs = {}
    inargs = {'table'           : filtered_event_list,
              'energycolumn'    : 'PI',
              'withfilteredset' : 'yes',
              'filteredset'     : filtered_source,
              'keepfilteroutput': 'yes',
              'filtertype'      : 'expression',
              'expression'      : "'((X,Y) in {:s})'".format(source_coords),
              'withspectrumset' : 'yes',
              'spectrumset'     : source_spectrum_file,
              'spectralbinsize' : '5',
              'withspecranges'  : 'yes',
              'specchannelmin'  : '0',
              'specchannelmax'  : '{:s}'.format(specchannelmax)}

    w('evselect', inargs).run()

    inargs = {}
    inargs = {'table'           : filtered_event_list,
              'energycolumn'    : 'PI',
              'withfilteredset' : 'yes',
              'filteredset'     : filtered_bkg,
              'keepfilteroutput': 'yes',
              'filtertype'      : 'expression',
              'expression'      : "'((X,Y) in {:s})'".format(bkg_coords),
              'withspectrumset' : 'yes',
              'spectrumset'     : bkg_spectrum_file,
              'spectralbinsize' : '5',
              'withspecranges'  : 'yes',
              'specchannelmin'  : '0',
              'specchannelmax'  : '{:s}'.format(specchannelmax)}

    w('evselect', inargs).run()
    
    return source_spectrum_file, bkg_spectrum_file
```

Let's use the make_fits_image command to identify our ideal source and background regions.

```python
make_fits_image(mos1)
```

As there is limited area to extract a background spectrum in the pn image, we will focus on the spectra from the MOS1 and MOS2 images.

```python
filtered_source_mos1 = 'mos1_filt.fits'
filtered_bkg_mos1 = 'bkg_mos1_filt.fits'
source_spectrum_file_mos1 = 'mos1_pi.fits'
bkg_spectrum_file_mos1 = 'mos1_bkg_pi.fits'
source_coords_mos1 = 'CIRCLE(27623.01,26927.01,1033.12)'
bkg_coords_mos1 = 'CIRCLE(18052.94,35540.01,2697.07)'
specchannelmax_mos1 = '11999'

make_spectrum(filtered_event_list_mos1, filtered_source_mos1, 
              filtered_bkg_mos1, source_spectrum_file_mos1, 
              bkg_spectrum_file_mos1, source_coords_mos1, 
              bkg_coords_mos1, specchannelmax_mos1)

filtered_source_mos2 = 'mos2_filt.fits'
filtered_bkg_mos2 = 'bkg_mos2_filt.fits'
source_spectrum_file_mos2 = 'mos2_pi.fits'
bkg_spectrum_file_mos2 = 'mos2_bkg_pi.fits'
source_coords_mos2 = 'CIRCLE(27492.51,27144.51,1033.12)'
bkg_coords_mos2 = 'CIRCLE(14355.38,28101.50,2697.07)'
specchannelmax_mos2 = '11999'

make_spectrum(filtered_event_list_mos2, filtered_source_mos2, 
              filtered_bkg_mos2, source_spectrum_file_mos2, 
              bkg_spectrum_file_mos2, source_coords_mos2, 
              bkg_coords_mos2, specchannelmax_mos2)
```

```python
def make_rmf_arf(rmf,arf,source_spectrum_file,event_file):
    
    inargs = {'rmfset'      : rmf,
              'spectrumset' : source_spectrum_file}

    w('rmfgen', inargs).run()

    inargs = {}
    inargs = {'arfset'         : arf,
              'spectrumset'    : source_spectrum_file,
              'withrmfset'     : 'yes',
              'rmfset'         : rmf,
              'withbadpixcorr' : 'yes',
              'badpixlocation' : event_file,
              'setbackscale'   : 'yes'}

    w('arfgen', inargs).run()
    
    return rmf, arf
```

<div class="alert alert-block alert-info">
    <b>Note:</b> The next cell may take several minutes to run.
</div>

```python
mos1_rmf = 'mos1.rmf'
mos1_arf = 'mos1.arf'
mos2_rmf = 'mos2.rmf'
mos2_arf = 'mos2.arf'

make_rmf_arf(mos1_rmf, mos1_arf,source_spectrum_file_mos1,filtered_event_list_mos1)
make_rmf_arf(mos2_rmf, mos2_arf,source_spectrum_file_mos2,filtered_event_list_mos2)
```

```python
sou_mos1_grp = 'mos1_grp25.fits'
sou_mos2_grp = 'mos2_grp25.fits'

inargs = {}
inargs = {'spectrumset' : source_spectrum_file_mos1,
          'groupedset'  : sou_mos1_grp,
          'arfset'      : mos1_arf,
          'rmfset'      : mos1_rmf,
          'backgndset'  : bkg_spectrum_file_mos1,
          'mincounts'   : '25',
          'oversample'  : '3'}

w('specgroup', inargs).run()

inargs = {}
inargs = {'spectrumset' : source_spectrum_file_mos2,
          'groupedset'  : sou_mos2_grp,
          'arfset'      : mos2_arf,
          'rmfset'      : mos2_rmf,
          'backgndset'  : bkg_spectrum_file_mos2,
          'mincounts'   : '25',
          'oversample'  : '3'}

w('specgroup', inargs).run()
```

Now we have processed the relevant data and are ready to move forward with Part 2.
