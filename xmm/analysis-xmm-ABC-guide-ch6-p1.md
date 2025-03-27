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
# ABC Guide for XMM-Newton -- Part 1
<hr style="border: 2px solid #fadbac" />

- **Description:** XMM-Newton ABC Guide, Chapter 6, Part 1.
- **Level:** Beginner
- **Data:** XMM observation of the Lockman Hole (obsid=0123700101)
- **Requirements:** Must be run using the `HEASARCv6.35` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (April 2024)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 26 March 2025, for SAS v22.1 and pySAS v1.4.8

<hr style="border: 2px solid #fadbac" />
<!-- #endregion -->

## Introduction
This tutorial is based on Chapter 6 from the The [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide") prepared by the NASA/GSFC XMM-Newton Guest Observer Facility. This notebook assumes you are at least minimally familiar with pySAS on SciServer (see the [Long pySAS Introduction](./analysis-xmm-long-intro.md "Long pySAS Intro")). 

#### SAS Tasks to be Used

- `emproc`[(Documentation for emproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html "emproc Documentation")
- `epproc`[(Documentation for epproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html "epproc Documentation")
- `evselect`[(Documentation for evselect)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/evselect/index.html)
- `tabgtigen`[(Documentation for tabgtigen)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/tabgtigen/index.html)
- `gtibuild`[(Documentation for gtibuild)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/gtibuild/index.html)

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


## 6.1 Rerun basic processing

```python
# pySAS imports
import pysas
from pysas.wrapper import Wrapper as w

# Importing Js9
import jpyjs9

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
obsid = '0123700101'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')

odf = pysas.odfcontrol.ODFobject(obsid)
odf.basic_setup(data_dir=data_dir,repo='sciserver',overwrite=False,
                run_epproc=False,run_emproc=False,run_rgsproc=False,
                level='PPS',filename='P0123700101M1S001MIEVLI0000.FTZ')
```

<!-- #region -->
For demonstration purposes we will start with the processed event list from the pipeline products (`PPS`) instead of the raw observational data files (`ODF`). You can run this notebook using the following command instead:

```python
odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False)
```

If you use the `ODFs` then running `odf.basic_setup` will recalibrate the data and run `epproc`, `emproc`, and `rgsproc` on the data. The output from those tasks will not display in the cell output, but will be written to log files found in the `obsid` work directory.

<div class="alert alert-block alert-info">
    <b>Note:</b> If you use the <tt>ODFs</tt> instead of the <tt>PPS</tt> files then running <tt>epproc</tt>, <tt>emproc</tt>, and <tt>rgsproc</tt> on this particular obsid may take several (>40) minutes. Be prepared to wait.
</div>

If the dataset has more than one exposure, a specific exposure can be accessed using the <tt>withinstexpids</tt> and <tt>instexpids</tt> parameters, e.g.:

```python
inargs = "withinstexpids=yes instexpids='M1S001 M2S001'"
w('emproc', inargs).run()
```

To create an out-of-time event file for your PN data, add the parameter <tt>withoutoftime</tt> to your <tt>epproc</tt> invocation:

```python
inargs = ["withoutoftime=yes"]
w('epproc', inargs).run()
```

<div class="alert alert-block alert-info">
    <b>Note:</b> For PN observations with very bright sources, out-of-time events can provide a serious contamination of the image. Out-of-time events occur because the read-out period for the CCDs can be up to $\sim6.3$% of the frame time. Since events that occur during the read-out period can't be distinguished from others events, they are included in the event files but have invalid locations. For observations with bright sources, this can cause bright stripes in the image along the CCD read-out direction.
</div>

By default, these tasks do not keep any intermediate files they generate. <tt>Emproc</tt> and <tt>epproc</tt> designate their output event files with "*ImagingEvts.ds".
<!-- #endregion -->

## 6.2 Plot image


For displaying images we are using a `ds9` clone, `JS9`. It has all the same functionality as `ds9` but it allows us to directly interface with it using Python code. The cell below  will display the `JS9` window to the side of this notebook.

```python
my_js9 = jpyjs9.JS9(width = 800, height = 800, side=True)
```

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
    ximagesize - output image pixels in X
    yimagesize - output image pixels in Y
<!-- #endregion -->

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
                     
    inargs = ['table={0}'.format(event_list_file), 
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

We need to change into the work directory to run the next SAS tasks. We also get the name and path to the event list file created in §6.1.

```python
os.chdir(odf.work_dir)
mos1 = odf.files['PPS'][0]
```

Here we plot an image of the raw data with no filters applied. The image should be very noisy.

```python
make_fits_image(mos1)
```

## 6.3 Apply Standard Filter


To begin we apply a standard filter. The filtering expressions for the MOS and PN are, respectively:
```
(PATTERN $<=$ 12)&&(PI in [200:12000])&&#XMMEA_EM
```
and
```
(PATTERN $<=$ 4)&&(PI in [200:15000])&&#XMMEA_EP
```
The first two expressions will select good events with `PATTERN` in the 0 to 12 (or 0 to 4) range. The `PATTERN` value is similar the `GRADE` selection for ASCA data, and is related to the number and pattern of the CCD pixels triggered for a given event. The `PATTERN` assignments are: single pixel events: `PATTERN == 0`, double pixel events: `PATTERN in [1:4]`, triple and quadruple events: `PATTERN in [5:12]`.

The second keyword in the expressions, `PI`, selects the preferred pulse height of the event; for the MOS, this should be between 200 and 12000 eV. For the PN, this should be between 200 and 15000 eV. This should clean up the image significantly with most of the rest of the obvious contamination due to low pulse height events. Setting the lower `PI` channel limit somewhat higher (e.g., to 300 eV) will eliminate much of the rest.

Finally, the `#XMMEA_EM` (`#XMMEA_EP` for the PN) filter provides a canned screening set of `FLAG` values for the event. The `FLAG` value provides a bit encoding of various event conditions, e.g., near hot pixels or outside of the field of view. Setting `FLAG == 0` in the selection expression provides the most conservative screening criteria and should always be used when serious spectral analysis is to be done on the PN. It typically is not necessary for the MOS.

It is a good idea to keep the output filtered event files and use them in your analyses, as opposed to re-filtering the original file with every task. This will save much time and computer memory. As an example, the Lockman Hole data's original event file is 48.4 MB; the fully filtered list (that is, filtered spatially, temporally, and spectrally) is only 4.0MB!

The input arguments to `evselect` to apply the filter are:

    table - input event table
    filtertype - method of filtering
    expression - filtering expression
    withfilteredset - create a filtered set
    filteredset - output file name
    keepfilteroutput - save the filtered output
    updateexposure - update exposure information in event list and in spectrum files
    filterexposure - filter exposure extensions of event list with same time

```python
filtered_event_list = 'mos1_filt.fits'

inargs = ['table={0}'.format(mos1), 
          'withfilteredset=yes', 
          "expression='(PATTERN <= 12)&&(PI in [200:4000])&&#XMMEA_EM'", 
          'filteredset={0}'.format(filtered_event_list), 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```

<div class="alert alert-block alert-info">
    <b>Note:</b> The expression for the input <tt>expression</tt> contains single quotes ('text'). The entire string needs to be surrounded by double quotes ("text") to preserve the single quotes inside the string. i.e. "This text has 'single quotes' inside of the double quotes."
</div>


Now we plot the filtered image. It should have less noise now.

```python
make_fits_image(filtered_event_list)
```

<!-- #region editable=true slideshow={"slide_type": ""} -->
## 6.4 Create Light Curve
<!-- #endregion -->

Sometimes, it is necessary to use filters on time in addition to those mentioned above. This is because of soft proton background flaring, which can have count rates of 100 counts/sec or higher across the entire bandpass. It should be noted that the amount of flaring that needs to be removed depends in part on the object observed; a faint, extended object will be more affected than a very bright X-ray source.

To see if background flaring should be removed we plot and examine the light curve.

```python
light_curve_file='mos1_ltcrv.fits'
plot_light_curve(filtered_event_list, light_curve_file=light_curve_file)
```

Taking a look at the light curve, we can see that there is a very large flare toward the end of the observation and two much smaller ones in the middle of the exposure. Examining the light curve shows us that during non-flare times, the count rate is quite low, about 1.3 ct/s, with a small increase at 7.3223e7 seconds to about 6 ct/s. We can use that to further filter the data.


## 6.5 Applying Time or Rate Filters to the Data


There are many ways to filter the data. We will demonstrate four different methods. The first three methods will create a Good Time Interval (GTI) file which can then be used as an input to the command `evselect`. This will create a new, filtered, event list.

1. Create a secondary GTI file using the command `tabgtigen` and filter on `RATE`.
2. Create a secondary GTI file using the command `tabgtigen` and filter on `TIME`.
3. Create a *new* GTI file using the command `gtibuild` and filter on `TIME`.
4. Filter on `TIME` using an explicit reference in the inputs to the command `evselect`.

For the last method the user explicitly inputs the time intervals to be used as an expression for the command `evselect` rather than using a separate GTI file. All of these will get the job done, so which to use is a matter of the user's preference.


#### 6.5.1 Using `tabgtigen` to filter on `RATE`


The inputs for `tabgtigen` are:

    table - input file name with count rate table
    gtiset - output file name for selected GTI intervals
    timecolumn - time column
    expression - filtering expression
    
We choose a rate $<= 6$ counts/s and filter based on that. As the input we use the lightcurve file created in §6.4.

```python
gti_rate_file = 'gti_rate.fits'
mos1_filt_rate = 'mos1_filt_rate.fits'

inargs = ['table={0}'.format(light_curve_file), 
          'gtiset={0}'.format(gti_rate_file),
          'timecolumn=TIME', 
          "expression='(RATE <= 6)'"]

w('tabgtigen', inargs).run()

inargs = ['table={0}'.format(filtered_event_list),
          'withfilteredset=yes', 
          "expression='GTI({0},TIME)'".format(gti_rate_file), 
          'filteredset={0}'.format(mos1_filt_rate),
          'filtertype=expression', 
          'keepfilteroutput=yes',
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```

Now we create an image from the new event list that has been filtered based on `RATE`. There should be significantly less noise and only point sources should remain. Compare this final image to the first raw, unfilted image.

```python
make_fits_image(mos1_filt_rate, image_file='final_image1.fits')
```

We can also create a new light curve from the filtered event list and compare it to the light curve from §6.4 to see what we have done.

```python
plot_light_curve(mos1_filt_rate)
```

#### 6.5.2 Using `tabgtigen` to filter on `TIME`


Alternatively, we could have chosen to make a new GTI file by noting the times of the flaring in the light curve and using that as a filtering parameter. The big flare starts around 7.32276e7 s, and the smaller ones are at 7.32119e7 s and 7.32205e7 s. The expression to remove these would be `(TIME <= 73227600)&&!(TIME IN [7.32118e7:7.3212e7])&&!(TIME IN [7.32204e7:7.32206e7])`. The syntax `(TIME <= 73227600)` includes only events with times less than or equal to `73227600`, and the "!" symbol stands for the logical "not", so use `&&!(TIME in [7.32118e7:7.3212e7])` to exclude events in that time interval. Once the new GTI file is made, we apply it with `evselect`. Everything else remains the same as in §6.5.1.

```python
gti_time_file = 'gti_rate.fits'
mos1_filt_time = 'mos1_filt_time.fits'

inargs = ['table={0}'.format(light_curve_file), 
          'gtiset={0}'.format(gti_time_file),
          'timecolumn=TIME', 
          "expression='(TIME <= 73227600)&&!(TIME IN [7.32118e7:7.3212e7])&&!(TIME IN [7.32204e7:7.32206e7])'"]

w('tabgtigen', inargs).run()

inargs = ['table={0}'.format(filtered_event_list),
          'withfilteredset=yes', 
          "expression='GTI({0},TIME)'".format(gti_time_file), 
          'filteredset={0}'.format(mos1_filt_time),
          'filtertype=expression', 
          'keepfilteroutput=yes',
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```

We can now plot the image that has been filtered on `TIME` and compare it to the image that was been filtered on `RATE` from §6.5.1.

```python
make_fits_image(mos1_filt_time, image_file='final_image2.fits')
plot_light_curve(mos1_filt_time)
```

#### 6.5.3 Using `gtibuild` to make a new GTI file and filter on `TIME`


This method requires a text file as input. The file should be in ASCII format with eash row on a new line and values for each column separated by spaces. In the first two columns, enter the start and end times (in seconds) that you are interested in, and in the third column, indicate with either a + or - sign whether that region should be kept or removed. Each good (or bad) time interval should get its own line, with any optional comments preceeded by a "#". In the example case, we would write in our ASCII file (named gti.txt):

```python
gti_lines = ['0        73227600 + # Good time from the start of the observation',
             '73211800 73212000 - # But without a small flare here.',
             '73220400 73220600 - # And here.']

with open('gti.txt', 'w') as f:
    f.writelines(gti_lines)
```

We can now run `gtibuild` to create a new GTI file.

---
The inputs for `gtibuild` are:

    file - input text file name
    table - output GTI file name

```python
gti_txt_file = 'gti.txt'
new_gti_file = 'new_gti.fits'
mos1_new_gti = 'mos1_new_gti.fits'

inargs = ['file={0}'.format(gti_txt_file),
          'table={0}'.format(new_gti_file)]

w('gtibuild', inargs).run()
```

We can now run `evselect` as before with the new GTI file.

```python
inargs = ['table={0}'.format(filtered_event_list),
          'withfilteredset=yes', 
          "expression='GTI({0},TIME)'".format(new_gti_file), 
          'filteredset={0}'.format(mos1_new_gti),
          'filtertype=expression', 
          'keepfilteroutput=yes',
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```

If you want, you can compare the new image and light curve to what was made previously.

```python
make_fits_image(mos1_new_gti, image_file='final_image3.fits')
plot_light_curve(mos1_new_gti)
```

<!-- #region editable=true slideshow={"slide_type": ""} -->
#### 6.5.4 Filter on `TIME` by Explicit Reference
<!-- #endregion -->

Finally, we could have chosen to forgo making a secondary GTI file altogether, and simply filtered on `TIME` with the standard filtering expression (see §6.3). The filtering expression from §6.3 can be combined with the filtering expression from §6.5.2 and filter the raw data all in one step. In this case, the full filtering expression would be:

```python
expression = "expression='(PATTERN <= 12)&&(PI in [200:12000])&&#XMMEA_EM&&(TIME <= 73227600) &&!(TIME IN [7.32118e7:7.3212e7])&&!(TIME IN [7.32204e7:7.32206e7])'"
```

and we would run `evselect` as the same way we did in §6.3.

```python
full_filt_event_list = 'mos1_filt.fits'

inargs = ['table={0}'.format(mos1), 
          'withfilteredset=yes', 
          expression, 
          'filteredset={0}'.format(full_filt_event_list), 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```

Finally we can compare the result with what we made before.

```python
make_fits_image(full_filt_event_list, image_file='final_image4.fits')
plot_light_curve(full_filt_event_list)
```

### Conclusion

We have demonstrated various filtering techniques to remove noise from the raw observation data. Note: How you filter on `RATE` or `TIME` will depend on the light curve of each individual observation. For exceptionally bright sources you may only have to apply the standard filter.

In Part 2 we will cover source detection, spectra extraction, pile up, and preparing the spectra for analysis by creating a redistribution matrix file (RMF) and an ancillary response file (ARF).


---

Below we have included a short script that incorporates all of the filtering steps for a single observation for MOS1, but without making any plots or image files. 

<!-- #region -->
```python
obsid = '0123700101'
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName
data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')
odf = pysas.odfcontrol.ODFobject(obsid)
odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False)

os.chdir(odf.work_dir)
unfiltered_event_list = odf.files['m1evt_list'][0]

# The User can change these file names
temporary_event_list = 'temporary_event_list.fits' # Created by the "standard" filter
light_curve_file = 'mos1_ltcrv.fits'               # Light curve file name
gti_rate_file = 'gti_rate.fits'                    # GTI file name
filtered_event_list = 'filtered_event_list.fits'   # Final filtered 

# "Standard" Filter
inargs = ['table={0}'.format(unfiltered_event_list), 
          'withfilteredset=yes', 
          "expression='(PATTERN <= 12)&&(PI in [200:4000])&&#XMMEA_EM'", 
          'filteredset={0}'.format(temporary_event_list), 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()

# Make Light Curve File
inargs = ['table={0}'.format(temporary_event_list), 
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
inargs = ['table={0}'.format(temporary_event_list),
          'withfilteredset=yes', 
          "expression='GTI({0},TIME)'".format(gti_rate_file), 
          'filteredset={0}'.format(filtered_event_list),
          'filtertype=expression', 
          'keepfilteroutput=yes',
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```
<!-- #endregion -->
