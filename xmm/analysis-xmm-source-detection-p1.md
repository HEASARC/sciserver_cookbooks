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

# Source Detection with `edetect_chain` -- Part 1
<hr style="border: 2px solid #fadbac" />

- **Description:** Using `edetect_chain` to automatically detect sources.
- **Level:** Intermediate
- **Data:** XMM observation of the Lockman Hole (obsid=0123700101)
- **Requirements:** Must be run using the `HEASARCv6.35` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (March 2025)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 26 March 2025, for SAS v22.1 and pySAS v1.4.8

<hr style="border: 2px solid #fadbac" />


## Introduction
This tutorial is a variation on the introductory notebooks on preparing an observation for analysis, image creation, filtering, and source extraction (XMM-Newton ABC Guide, Chapter 6, [Part 1](./analysis-xmm-ABC-guide-ch6-p1.ipynb) and [Part 2](./analysis-xmm-ABC-guide-ch6-p2.ipynb)). This notebook assumes you are at least minimally familiar with pySAS on SciServer (see the [Long pySAS Introduction](./analysis-xmm-long-intro.md "Long pySAS Intro")) and that you have previously worked through the two introductory notebooks.

In the two introductory notebooks a single source and a background region were selected by hand with the coordinates determined before hand. Now we will use the SAS task `edetect_chain` to automatically detect sources in an image. We will also demonstrate a few of the potential problems you might run into using `edetect_chain`.

In this notebook we will use the raw data files (ODFs) which will have to be calibrated and processed. This may take several (>20) minutes to run. Be prepared to wait.

#### SAS Tasks to be Used

- `edetect_chain`[(Documentation for edetect_chain)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/edetect_chain/index.html)

#### Useful Links

- [`pysas` Documentation](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/pysas/index.html "pysas Documentation")
- [`pysas` on GitHub](https://github.com/XMMGOF/pysas)
- [Common SAS Threads](https://www.cosmos.esa.int/web/xmm-newton/sas-threads/ "SAS Threads")
- [Users' Guide to the XMM-Newton Science Analysis System (SAS)](https://xmm-tools.cosmos.esa.int/external/xmm_user_support/documentation/sas_usg/USG/SASUSG.html "Users' Guide")
- [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide")
- [XMM Newton GOF Helpdesk](https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html "Helpdesk") - Link to form to contact the GOF Helpdesk.

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

# Importing Js9
import jpyjs9
my_js9 = jpyjs9.JS9(width = 800, height = 800, side=True)

# Useful imports
import os

# Astropy import
from astropy.io import fits

# Environment variables that need to be set to avoid a problem with edetect_chain on SciServer
os.environ['HEADASNOQUERY'] = ''
os.environ['HEADASPROMPT']  = '/dev/null'
```

```python
obsid = '0123700101'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')
odf = pysas.odfcontrol.ODFobject(obsid)
odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False,
                run_epproc=False,run_rgsproc=False)
os.chdir(odf.work_dir)
```

```python
# File names for this notebook. The User can change these file names.
unfiltered_event_list = odf.files['M1evt_list'][0]
first_filter_event_list = 'first_filter_event_list.fits'
light_curve_file ='mos1_ltcrv.fits'
gti_rate_file = 'gti_rate.fits'

filtered_event_list = 'filtered_event_list.fits'
filtered_image_file = 'filtered_image.fits'

attitude_file = 'attitude.fits'

large_filtered_image = 'large_filtered_image.fits'

eml_list_file = 'emllist.fits'
```

## Filter the Observation

The following filtering follows exactly the filtering done in the ABC Guide Chapter 6, [Part 1](./analysis-xmm-ABC-guide-ch6-p1.ipynb).

```python
def display_fits_image(event_list_file, image_file='image.fits'):
    
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
```

```python
# "Standard" Filter
inargs = ['table={0}'.format(unfiltered_event_list), 
          'withfilteredset=yes', 
          "expression='(PATTERN <= 12)&&(PI in [200:10000])&&#XMMEA_EM'", 
          'filteredset={0}'.format(first_filter_event_list), 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()

# Make Light Curve File
inargs = ['table={0}'.format(first_filter_event_list), 
          'withrateset=yes', 
          'rateset={0}'.format(light_curve_file), 
          'maketimecolumn=yes', 
          'timecolumn=TIME', 
          'timebinsize=100', 
          'makeratecolumn=yes']

w('evselect', inargs).run()

# Make Secondary GTI File
inargs = ['table={0}'.format(light_curve_file), 
          'gtiset={0}'.format(gti_rate_file),
          'timecolumn=TIME', 
          "expression='(RATE <= 6)'"]

w('tabgtigen', inargs).run()

# Filter Using Secondary GTI File
inargs = ['table={0}'.format(first_filter_event_list),
          'withfilteredset=yes', 
          "expression='GTI({0},TIME)'".format(gti_rate_file), 
          'filteredset={0}'.format(filtered_event_list),
          'filtertype=expression', 
          'keepfilteroutput=yes',
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()

# Make attitude file
inargs = ['atthkset={0}'.format(attitude_file),
          'timestep=1']

w('atthkgen', inargs).run()
```

```python
display_fits_image(filtered_event_list,image_file=filtered_image_file)
```

## Make a Large Image for Analysis

Above we defined a function `display_fits_image` to generate a FITS image for display purposes. In that function the size of the FITS image was set (`imagebinning=imageSize`, 600x600 pixels) and events in the event list were binned accordingly. While that size of image is fine for quick looks at the data, the resolution is too low for good analysis. Below we define another function, `make_large_image` to make a FITS image, but here we set the bin size (`imagebinning=binSize`, 20x20 arcseconds). Events will be binned accordingly. This creates a much higher resolution image suitable for data analysis.

For now we will make a high resolution image using the default settings, but later on we will see what happens when we change these defaults. We will also make a short function to run `edetect_chain` for convenience.

`edetect_chain` will create a list of sources and write the list to file in FITS format. We will define a function (`make_regions`) that will take the source list and generate regions for each of the sources and load the regions into JS9.

<div class="alert alert-block alert-info">
<b>Note:</b> The resulting high resolution image will be quite large (>20 MB). Currently JS9 struggles to display such a large image on SciServer. So for display purposes we will use the lower resolution image, but for analysis we will use the higher resolution image.</div>

```python
# High resolution image function
def make_large_image(event_list_file,image_file,xbinsize=20,ybinsize=20,pimin=300,pimax=2000):

    expression = '(FLAG == 0)&&(PI in [{pimin}:{pimax}])'.format(pimin=pimin,pimax=pimax)
    
    inargs = {'table'         : event_list_file, 
              'withimageset'  : 'yes',
              'imageset'      : image_file, 
              'xcolumn'       : 'X', 
              'ycolumn'       : 'Y', 
              'imagebinning'  : 'binSize', 
              'ximagebinsize' : xbinsize, 
              'yimagebinsize' : ybinsize,
              'filtertype'    : 'expression',
              'expression'    : expression}

    w('evselect', inargs).run()

# Function to run edetect_chain
def run_edetect_chain(large_filtered_image,filtered_event_list,attitude_file,eml_list,
                      pimin=300,pimax=2000,
                      likemin=10,eml_ecut=15):
    inargs = {'imagesets'   : large_filtered_image, 
              'eventsets'   : filtered_event_list,
              'attitudeset' : attitude_file, 
              'pimin'       : pimin, 
              'pimax'       : pimax,
              'witheexpmap' : 'yes',
              'eml_ecut'    : eml_ecut,
              'likemin'     : likemin,
              'eml_list'    : eml_list}
    
    w('edetect_chain', inargs).run()

# Function to make regions and load into JS9
def make_regions(source_list):
    my_js9.RemoveRegions('all')
    with fits.open(eml_list_file) as hdu:
        data = hdu[1].data[hdu[1].data['ID_BAND'] == 1]
    for i in range(len(data)):
        my_js9.AddRegions("circle", {'ra': data['RA'][i], 'dec': data['DEC'][i], 'radius': 10.0})
```

<div class="alert alert-block alert-warning">
<b>Warning:</b> Running <tt>edetect_chain</tt> with a high resolution image will take several minutes to run.
</div>


When we run the cell below it will generate a source list and mark regions around each source. We notice that the algorithm in `edetect_chain` will occationally find two separate sources, with a slight offset, for a single source. This can be seen where for a few of the sources there are two region circles with a slight offset around a single source. There are also a few spots where our eye can detect what might be a source, but the algorithm in `edetect_chain` rejected them as sources due to default source detection cutoff values. `edetect_chain` has a large number of possible inputs that you can use to modify the detection assumptions made by the algorithm.

```python
make_large_image(filtered_event_list, large_filtered_image)
run_edetect_chain(large_filtered_image,filtered_event_list,attitude_file,eml_list_file)
make_regions(eml_list_file)
```

```python
print('Number of regions: {}'.format(len(my_js9.GetRegions())))
```

<div class="alert alert-block alert-info">
<b>Note:</b> Below we will demonstrate changing a few input parameters from their defaults. This is not a comprehensive demonstration of the possible inputs for <tt>edetect_chain</tt>, just a few selected examples.</div>

Now let us change some basic values and see how that changes the results of `edetect_chain`. First we will change the resolution of the image used for source detection. We will change the bin size from 20x20 arcseconds to 50x50.

```python
xbinsize=50
ybinsize=50

eml_list_lores = 'emllist_lores.fits'

make_large_image(filtered_event_list, large_filtered_image,xbinsize=xbinsize,ybinsize=ybinsize)
run_edetect_chain(large_filtered_image,filtered_event_list,attitude_file,eml_list_lores)
make_regions(eml_list_lores)
```

```python
print('Number of regions: {}'.format(len(my_js9.GetRegions())))
```

Because the image is lower resolution `edetect_chain` will run faster, but we can also see that the number of sources detected has gone down from 42 to 20 (though the number of duplicates has also gone down).

As a default we restricted source detection over the energy range 0.3-2.0 keV. Now let's see what happens if we expand the energy range to 0.3-8.0 keV, but return to the original resolution of 20x20 arcseconds.

```python
pimin=300
pimax=8000

eml_list_hipimax = 'emllist_hipimax.fits'

make_large_image(filtered_event_list, large_filtered_image,pimin=pimin,pimax=pimax)
run_edetect_chain(large_filtered_image,filtered_event_list,attitude_file,eml_list_hipimax,pimin=pimin,pimax=pimax)
make_regions(eml_list_hipimax)
```

```python
print('Number of regions: {}'.format(len(my_js9.GetRegions())))
```

We see that the number of detected sources has dropped to 4. This shows that the algorithm for `edetect_chain` is sensitive to the energy range given for detecting sources. Generally a narrower energy range will be better for source detection.

Next let us try two other parameters. The first is `likemin` which is the detection likelihood threshold. The default is 10. Let's set it to something higher and see what we get.

```python
likemin=20

eml_list_hilikemin = 'emllist_hilikemin.fits'

make_large_image(filtered_event_list, large_filtered_image)
run_edetect_chain(large_filtered_image,filtered_event_list,attitude_file,eml_list_hilikemin,likemin=likemin)
make_regions(eml_list_hilikemin)
```

```python
print('Number of regions: {}'.format(len(my_js9.GetRegions())))
```

With a higher detection likelihood threshold we only get 32 sources, instead of 42 using the default value.

Now let's try another parameter. There is the parameter `eml_ecut` which is the event cut-out radius as measured in pixels.

<div class="alert alert-block alert-info">
<b>Note:</b> We have the function calls commented out because this takes ~50 minutes to run. If you do wish to run the following cells, just uncomment the lines.</div>

```python
eml_ecut=30

eml_list_hieml_ecut = 'emllist_hieml_ecut.fits'

#make_large_image(filtered_event_list, large_filtered_image)
#run_edetect_chain(large_filtered_image,filtered_event_list,attitude_file,eml_list_hieml_ecut,eml_ecut=eml_ecut)
#make_regions(eml_list_hieml_ecut)
```

```python
#print('Number of regions: {}'.format(len(my_js9.GetRegions())))
```

With this parameter change we also get 32 source detections.


## Automatic Spectra Extraction

Below we provide an example function that can be used to automatically extract spectra from all sources, along with background regions. As inputs it takes a filtered event list and the source list generated by `edetect_chain`. The outputs will be a corresponding source event list, background event list, source spectrum, background spectrum, RMF, ARF, and binned spectrum file for each source. The files for each source will start with 'MMMsXXX' where MMM is the instrument and XXX is the source number.

<div class="alert alert-block alert-info">
<b>Note:</b> This will generate spectra from duplicate sources. The size of the region used for source extraction uses a default value, along with the size of the background region. There are a few other default assumptions that may or may not be appropriate depending on the individual sources.
</div>

<!-- #region -->
```python
def extract_spectra_from_source(filtered_event_list,eml_list_file,instrument):
    my_js9.RemoveRegions('all')
    with fits.open(eml_list_file) as hdu:
        data = hdu[1].data[hdu[1].data['ID_BAND'] == 1]
    for i in range(len(data)):
        # File names
        source_event_list = instrument+'s{:03}_event_list.fits'.format(i)
        bkg_event_list    = instrument+'s{:03}_bkg_event_list.fits'.format(i)
        source_spectra    = instrument+'s{:03}_spectra.fits'.format(i)
        bkg_spectra       = instrument+'s{:03}_bkg_spectra.fits'.format(i)
        rmf_file          = instrument+'s{:03}_rmf.fits'.format(i)
        arf_file          = instrument+'s{:03}_arf.fits'.format(i)
        grouped_spectra   = instrument+'s{:03}_spectra_grouped.fits'.format(i)

        # Add source region and background annulus
        my_js9.AddRegions("circle", {'ra': data['RA'][i], 'dec': data['DEC'][i], 'radius': 4.0})
        my_js9.AddRegions("annulus", {'ra': data['RA'][i], 'dec': data['DEC'][i], 'radii': [5,15]})
        source_region = regions[-2]
        bkg_region = regions[-1]
        source_loc = source_region['lcs']
        bkg_loc = bkg_region['lcs']

        # Extract spectrum from source
        expression = "'((X,Y) in CIRCLE({x:.1f},{y:.1f},{radius:.1f}))'".format(x=source_loc['x'], y=source_loc['y'], radius=source_loc['radius'])
        inargs = {'table': filtered_event_list,
                  'energycolumn': 'PI',
                  'withfilteredset': 'yes',
                  'filteredset': source_event_list,
                  'keepfilteroutput': 'yes',
                  'filtertype': 'expression',
                  'expression': expression,
                  'withspectrumset': 'yes',
                  'spectrumset': source_spectra,
                  'spectralbinsize': '5',
                  'withspecranges': 'yes',
                  'specchannelmin': '0',
                  'specchannelmax': '11999'}
        
        w('evselect', inargs).run()

        # Extract spectrum from background
        expression = "((X,Y) in CIRCLE({x:.1f},{y:.1f},{radiuso:.1f}))&&!((X,Y) in CIRCLE({x:.1f},{y:.1f},{radiusi:.1f}))".format(x=bkg_loc['x'], y=bkg_loc['y'], radiuso=bkg_loc['radii'][1], radiusi=bkg_loc['radii'][0])
        inargs = {'table': filtered_event_list,
                  'energycolumn': 'PI',
                  'withfilteredset': 'yes',
                  'filteredset': bkg_event_list,
                  'keepfilteroutput': 'yes',
                  'filtertype': 'expression',
                  'expression': expression,
                  'withspectrumset': 'yes',
                  'spectrumset': bkg_spectra,
                  'spectralbinsize': '5',
                  'withspecranges': 'yes',
                  'specchannelmin': '0',
                  'specchannelmax': '11999'}
        
        w('evselect', inargs).run()

        # Generate rmf for source
        inargs = {}
        inargs = {'rmfset': rmf_file,
                  'spectrumset': source_spectra}
        
        w('rmfgen', inargs).run()

        # Generate arf for source
        inargs = {}
        inargs = {'arfset': arf_file,
                  'spectrumset': source_spectra,
                  'withrmfset': 'yes',
                  'rmfset': rmf_file,
                  'withbadpixcorr': 'yes',
                  'badpixlocation': filtered_event_list,
                  'setbackscale': 'yes'}
        
        w('arfgen', inargs).run()

        # Bin events in spectrum and link arf and rmf
        inargs = {}
        inargs = {'spectrumset': source_spectra,
                  'groupedset': grouped_spectra,
                  'arfset': arf_file,
                  'rmfset': rmf_file,
                  'backgndset': bkg_spectra,
                  'mincounts': '30'}
        
        w('specgroup', inargs).run()
```
<!-- #endregion -->
