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

# How to reprocess ODFs to generate calibrated and concatenated EPIC event lists
<hr style="border: 2px solid #fadbac" />

- **Description:** A guide for processing data from all EPIC cameras on XMM.
- **Level:** Beginner
- **Data:** XMM observation of RX J122135.6+280613 (obsid=0104860501)
- **Requirements:** Must be run using the `HEASARCv6.33.1` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (April 2024)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 1 May 2024, for SAS v21

<hr style="border: 2px solid #fadbac" />


## 1. Introduction
This thread illustrates how to reprocess Observation Data Files (ODFs) to obtain calibrated and concatenated event lists.
#### Expected Outcome
The user will obtain calibrated and concatenated event lists which can be directly used to generate scientific products (images, spectra, light curves) through the SAS tasks [<tt>evselect</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/evselect/index.html) or [<tt>xmmselect</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/xmmselect/index.html).
#### SAS Tasks to be Used

- `emproc`[(Documentation for emproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html "emproc Documentation")
- `epproc`[(Documentation for epproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html "epproc Documentation")

#### Useful Links

- [`pysas` Documentation](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/pysas/index.html "pysas Documentation")
- [`pysas` on GitHub](https://github.com/XMMGOF/pysas)
- [Common SAS Threads](https://www.cosmos.esa.int/web/xmm-newton/sas-threads/index.html "SAS Threads")
- [Users' Guide to the XMM-Newton Science Analysis System (SAS)](https://xmm-tools.cosmos.esa.int/external/xmm_user_support/documentation/sas_usg/USG/SASUSG.html "Users' Guide")
- [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide")
- [XMM Newton GOF Helpdesk](https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html "Helpdesk") - Link to form to contact the GOF Helpdesk.

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br><br>
<b>Running Outside Sciserver:</b><br>
This notebook was designed to run on SciServer, but an equivelent notebook can be found on <a href="https://github.com/XMMGOF/pysas">GitHub</a>. You will need to install the development version of pySAS found on GitHub (<a href="https://github.com/XMMGOF/pysas">pySAS on GitHub</a>). There are installation instructions on GitHub and example notebooks can be found inside the directory named 'examples'.
<br>
</div>

<div class="alert alert-block alert-warning">
    <b>Warning:</b> By default this notebook will place observation data files in your <tt>scratch</tt> space. The <tt>scratch</tt> space on SciServer will only retain files for 90 days. If you wish to keep the data files for longer move them into your <tt>persistent</tt> directory.
</div>


## 2. Procedure
Run the EPIC reduction meta-tasks.

    For EPIC-MOS:
        emproc

    and for EPIC-pn:
        epproc

That's it! The default values of these meta-tasks are appropriate for most practical cases. You may have a look at the next section in this thread to learn how to perform specific reduction sub-tasks using [emproc](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html) or [epproc](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html).

The files produced by [epproc](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) are the following:

 - `????_??????????_AttHk.ds`, the reconstructed attitude file
 - `????_??????????_EPN_????_01_Badpixels.ds`, one table per reduced CCD containing the bad pixels
 - `????_??????????_EPN_????_ImagingEvts.ds`, the calibrated and concatenated event list, which shall be used as an input to extract scientific products via [evselect](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/evselect/index.html) or [xmmselect](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/xmmselect/index.html).
    
The files produced by [emproc](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html) are conceptually the same. The main difference in the naming convention is that the string `EPN` is replaced by `EMOS1` and `EMOS2` for each EPIC-MOS camera, respectively.
___

```python
# pySAS imports
import pysas
from pysas.wrapper import Wrapper as w

# Useful imports
import os

# Imports for plotting
import matplotlib.pyplot as plt
from astropy.visualization import astropy_mpl_style
from astropy.io import fits
from astropy.wcs import WCS
from astropy.table import Table
plt.style.use(astropy_mpl_style)
```

```python
obsid = '0104860501'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')
odf = pysas.odfcontrol.ODFobject(obsid)
odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False)
```

The odf object contains a dictionary with the path and filename for important output files created by `basic_setup`.

```python
instrument_files = list(odf.files.keys())
print(instrument_files,'\n')
for instrument in instrument_files:
    print(f'File Type: {instrument}')
    print('>>> {0}'.format(odf.files[instrument]),'\n')
```

## 3. Visualize the contents of the event files just created


To visualize the output we will apply a simple filter to remove some background noise and then create a FITS image file from the event list from each detector (EPIC-pn, EPIC-MOS1, EPIC-MOS2). To help with this we define two functions.

The first function applies a simple filter to the data. The inputs are:

- unfiltered_event_list: File name of the event list to be filtered.
- mos: If using MOS1 or MOS2 set mos=True, if using the pn set mos=False
- pattern: The number and pattern of the CCD pixels triggered for a given event, for MOS can be any number from 0 to 12, for pn can be any number from 0 to 4. Higher numbers look for more complex multiple pixel events to include them. 
- pi_min: Minimum energy in eV
- pi_max: Maximum energy in eV
- flag: The FLAG value provides a bit encoding of various event conditions, e.g., near hot pixels or outside of the field of view. Setting FLAG == 0 in the selection expression provides the most conservative screening criteria and should always be used when serious spectral analysis is to be done on the PN. It typically is not necessary for the MOS.
- filtered_event_list: File name of the output file, or filtered event list.

```python
def apply_simple_filter(unfiltered_event_list,mos=True,pattern=12,
                          pi_min=200,pi_max=12000,flag=None,
                          filtered_event_list='filtered_event_list.fits'):
    
    if flag is None:
        if mos:
            flag = '#XMMEA_EM'
        else:
            flag = '#XMMEA_EP'
    else:
        flag = '(FLAG == {0})'.format(flag)
    
    # "Standard" Filter
    expression = "expression='(PATTERN <= {pattern})&&(PI in [{pi_min}:{pi_max}])&&{flag}'".format(pattern=pattern,pi_min=pi_min,pi_max=pi_max,flag=flag)
    
    inargs = ['table={0}'.format(unfiltered_event_list), 
              'withfilteredset=yes', 
              expression, 
              'filteredset={0}'.format(filtered_event_list), 
              'filtertype=expression', 
              'keepfilteroutput=yes', 
              'updateexposure=yes', 
              'filterexposure=yes']
    
    w('evselect', inargs).run()
```

The second function will create a FITS image file and plot it. The inputs are:

- event_list_file: File name of the event list to be plotted.
- image_file: Name of the output FITS image file.

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

    hdu = fits.open(image_file)[0]
    wcs = WCS(hdu.header)

    ax = plt.subplot(projection=wcs)
    plt.imshow(hdu.data, origin='lower', norm='log', vmin=1.0, vmax=1e2)
    ax.set_facecolor("black")
    plt.grid(color='blue', ls='solid')
    plt.xlabel('RA')
    plt.ylabel('Dec')
    plt.colorbar()
    plt.show()
```

In the cell below we will range over all event lists from the three EPIC instruments (EPIC-pn, EPIC-MOS1, EPIC-MOS2). An image file will be created from each event list and a plot will be made.

```python
# For display purposes only, define a minimum filtering criteria for EPIC-pn

pn_pattern   = 4        # pattern selection
pn_pi_min    = 300.     # Low energy range eV
pn_pi_max    = 12000.   # High energy range eV
pn_flag      = 0        # FLAG

# For display purposes only, define a minimum filtering criteria for EPIC-MOS

mos_pattern   = 12      # pattern selection
mos_pi_min    = 300.    # Low energy range eV
mos_pi_max    = 20000.  # High energy range eV
mos_flag      = None    # FLAG

os.chdir(odf.work_dir)

pnevt_list = odf.files['pnevt_list']
m1evt_list = odf.files['m1evt_list']
m2evt_list = odf.files['m2evt_list']

# Filter pn and make FITS image file
if len(pnevt_list) > 0:
    for i,event_list in enumerate(pnevt_list):
        filtered_event_list='pn_event_list{0}.fits'.format(i)
        image_file='pn_image{0}.fits'.format(i)
        apply_simple_filter(event_list,
                            flag=pn_flag,
                            pattern=pn_pattern,
                            pi_min=pn_pi_min,
                            pi_max=pn_pi_max,
                            filtered_event_list=filtered_event_list)
        make_fits_image(filtered_event_list, image_file=image_file)

# Filter mos1 and make FITS image file
if len(m1evt_list) > 0:
    for event_list in m1evt_list:
        filtered_event_list='mos1_event_list{0}.fits'.format(i)
        image_file='mos1_image{0}.fits'.format(i)
        apply_simple_filter(event_list,
                            mos=True,
                            pattern=mos_pattern,
                            pi_min=mos_pi_min,
                            pi_max=mos_pi_max,
                            filtered_event_list=filtered_event_list)
        make_fits_image(filtered_event_list, image_file=image_file)

# Filter mos2 and make FITS image file
if len(m2evt_list) > 0:
    for event_list in m2evt_list:
        filtered_event_list='mos2_event_list{0}.fits'.format(i)
        image_file='mos2_image{0}.fits'.format(i)
        apply_simple_filter(event_list,
                            mos=True,
                            pattern=mos_pattern,
                            pi_min=mos_pi_min,
                            pi_max=mos_pi_max,
                            filtered_event_list=filtered_event_list)
        make_fits_image(filtered_event_list, image_file=image_file)

```

## 4. How to accomplish specific reduction tasks

[<tt>emproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html) and [<tt>epproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) are highly flexible tasks, which allow the user to perform a wide range of customized reduction tasks. Some [<tt>emproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html) examples are listed below. The same customized reduction tasks can be performed for the EPIC-pn as well, just by substituting [<tt>emproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html) with [<tt>epproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) in the commands.

In the cells below the commands to run each SAS task have been commented out. If you wish to run the commands uncomment the relevant cells.

- If you want to reduce only one of the cameras (EPIC-MOS1 in the example):

    <tt>emproc selectinstruments=yes emos1=yes</tt>

```python
# SAS Command
cmd    = "emproc" # SAS task to be executed                  

# Arguments of SAS Command
inargs = ['selectinstruments=yes','emos1=yes']

print("   SAS command to be executed: "+cmd+", with arguments; \n")
inargs
```

```python
# w(cmd, inargs).run()
```

- If you want to reduce only a subsample of exposures:

    <tt>emproc withinstexpids=yes instexpids="M1S001 M2S002"</tt>

```python
# SAS Command
cmd    = "emproc" # SAS task to be executed                  

# Arguments of SAS Command
inargs = ['withinstexpids=yes','instexpids="M1S001 M2S002"']

print("   SAS command to be executed: "+cmd+", with arguments; \n")
inargs
```

```python
# w(cmd, inargs).run()
```

- If you want to reduce data from 1 CCD only (#4 and #5 in the example):

    <tt>emproc selectccds=yes ccd4=yes ccd5=yes</tt>

```python
# SAS Command
cmd    = "emproc" # SAS task to be executed                  

# Arguments of SAS Command
inargs = ['selectccds=yes','ccd4=yes','ccd5=yes']

print("   SAS command to be executed: "+cmd+", with arguments; \n")
inargs
```

```python
# w(cmd, inargs).run()
```

- If you want to change the reference pointing for the calculation of the sky coordinates to a value of your choice:

    <tt>emproc referencepointing=user ra=34.65646 dec=-12.876546</tt>

```python
# SAS Command
cmd    = "emproc" # SAS task to be executed                  

# Arguments of SAS Command
inargs = ['referencepointing=user','ra=34.65646','dec=-12.876546']

print("   SAS command to be executed: "+cmd+", with arguments; \n")
inargs
```

```python
# w(cmd, inargs).run()
```

- Please be aware that if you want to supply coordinates for the analysis of the EPIC-MOS Timing mode, the command is slightly different, e.g.:

    <tt>emproc withsrccoords=yes srcra=34.65646 srcdec=-12.876546</tt>

- If you want to filter the event list events, using an external Good Time Interval (GTI) file (see the corresponding thread on how to filter event files for flaring particle background by creating a GTI file):

    <tt>emproc withgtiset=yes gtiset=mygti.gti filterevents=yes</tt>

```python
# SAS Command
cmd    = "emproc" # SAS task to be executed                  

# Arguments of SAS Command
inargs = ['withgtiset=yes','gtiset=mygti.gti','filterevents=yes']

print("   SAS command to be executed: "+cmd+", with arguments; \n")
inargs
```

```python
# w(cmd, inargs).run()
```

Parameters can be combined to accomplish simultaneously two or more of the above tasks during the same run.

The user is referred to the on-line documentation of [<tt>emproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html) and [<tt>epproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) for a complete list of the available options.


## 5. Reduction of EPIC-pn Timing Mode exposures

Most exposures in EPIC-pn Timing Mode are affected by X-ray Loading (XRL; cf. Sect.3.1 in Guainazzi et al., 2013, [XMM-SOC-CAL-TN-0083](http://xmm2.esac.esa.int/docs/documents/CAL-TN-0083.pdf)). Furthermore, a residual dependence of the energy scale on the total count rate is corrected through the "Rate-Dependent PHA" correction (Guainazzi, 2014, [XMM-CCF-REL-312](http://xmm2.esac.esa.int/docs/documents/CAL-SRN-0312-1-4.pdf)). In order to correct for these effects a set of default calibration settings have been identified. As of SAS v14.0, this is controlled by a single parameter within the tasks [<tt>epproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) and [<tt>epchain</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epchain/index.html). This parameter is called <tt>withdefaultcal</tt> and is set to <tt>yes</tt> by default. Setting <tt>withdefaultcal=yes</tt> implies <tt>runepreject=yes withxrlcorrection=yes runepfast=no withrdpha=yes</tt>. So one shall run the EPIC-pn reduction meta-tasks as follows:

&emsp;&emsp;<tt>epproc </tt>

or:

&emsp;&emsp;<tt>epchain datamode=TIMING</tt>

For more information please refer to the documentation of [<tt>epproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) and [<tt>epchain</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epchain/index.html).


## 6. Reduction of EPIC-pn Burst Mode exposures

Most exposures in EPIC-pn Burst Mode are affected by X-ray Loading (XRL; cf. Sect.3.1 in Guainazzi et al., 2013, [XMM-SOC-CAL-TN-0083](http://xmm2.esac.esa.int/docs/documents/CAL-TN-0083.pdf)). Furthermore, a residual dependence of the energy scale on the total count rate is corrected through the "Rate-Dependent CTI" correction. In order to correct for these effects a set of default calibration settings have been identified. As of SAS v14.0, this is controlled by a single parameter within the tasks [<tt>epproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) and [<tt>epchain</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epchain/index.html). This parameter is called <tt>withdefaultcal</tt> and is set to <tt>yes</tt> by default. Setting <tt>withdefaultcal=yes</tt> implies <tt>runepreject=yes withxrlcorrection=yes runepfast=yes withrdpha=no</tt>. So one shall run the EPIC-pn reduction meta-tasks as follows:

&emsp;&emsp;<tt>epproc burst=yes</tt>

Notice the inclusion of the extra parameter <tt>burst=yes</tt> in the call to [<tt>epproc</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html) and [<tt>epchain</tt>](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epchain/index.html) also needs an extra parameter:

&emsp;&emsp;<tt>epchain datamode=BURST</tt>

```python
# SAS Command
cmd    = "epchain" # SAS task to be executed                  

# Arguments of SAS Command
inargs = ['datamode=BURST']

print("   SAS command to be executed: "+cmd+", with arguments; \n")
inargs
```

```python
# w(cmd,inargs).run()
```
