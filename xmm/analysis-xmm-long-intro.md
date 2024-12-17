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

# pySAS Introduction -- Long Version
<hr style="border: 2px solid #fadbac" />

- **Description:** A longer introduction to pySAS on sciserver.
- **Level:** Beginner
- **Data:** XMM observation of NGC 3079 (obsid=0802710101)
- **Requirements:** Must be run using the `HEASARCv6.34` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (April 2024)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 1 May 2024, for SAS v21

<hr style="border: 2px solid #fadbac" />


## 1. Introduction

This tutorial provides a much more detailed explanation on how to use pySAS than the one found in the [Short pySAS Introduction](./analysis-xmm-short-intro.md "Short pySAS Intro"), but like the Short Intro it only covers how to download observation data files, how to calibrate the data, and how to run any SAS task through pySAS. For explanations on how to use different SAS tasks inside of pySAS see the exmple notebooks provided. A tutorial on how to learn to use SAS and pySAS for XMM analysis can be found in [The XMM-Newton ABC Guide](./analysis-xmm-ABC-guide-ch6-p1.md "XMM ABC Guide").

#### SAS Tasks to be Used

- `sasver`[(Documentation for sasver)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/sasver/index.html)
- `startsas`[(Documentation for startsas)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/startsas/index.html)
- `cifbuild`[(Documentation for cifbuild)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/cifbuild/index.html)
- `odfingest`[(Documentation for odfingest)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/odfingest/index.html)
- `emproc`[(Documentation for emproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/emproc/index.html "emproc Documentation")
- `epproc`[(Documentation for epproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/epproc/index.html "epproc Documentation")
- `rgsproc`[(Documentation for rgsproc)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/rgsproc/index.html "rgsproc Documentation")
- `omichain`[(Documentation for omichain)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/omichain/index.html "omichain Documentation")

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


## 2. Procedure
 
Lets begin by asking three questions:

1. What XMM-Newton Observation data do I want to process?
2. Which directory will contain the XMM-Newton Observation data I want to process?
3. Which directory am I going to use to work with (py)SAS?

For the first question, you will need an Observation ID. In this tutorial we use the ObsID `0802710101`. 

For the second question, you will also have to choose a directory for your data (`data_dir`). You can set your data directory to any path you want, but for now we will use your scratch space.

For the third question, a working directory will automatically be created for each ObsID, as explained below. You can change this manually, but using the default is recommended.
___

```python
import os
import pysas
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')
obsid = '0802710101'
```

By running the cell below, an Observation Data File (`odf`) object is created. By itself it doesn't do anything, but it has several helpful functions to get your data ready to analyse.

```python
odf = pysas.odfcontrol.ODFobject(obsid)
```

## 3. Run `odf.basic_setup`

When you run the cell below the following things will happen.

1. `basic_setup` will check if `data_dir` exists, and if not it will create it.
2. Inside data_dir `basic_setup` will create a directory with the value for the obs ID (i.e. `$data_dir/0802710101/`).
3. Inside of that, `basic_setup` will create two directories:

    a. `$data_dir/0802710101/ODF` where the observation data files are kept.
    
    b. `$data_dir/0802710101/work` where the `ccf.cif`, `*SUM.SAS`, and output files are kept.
4. `basic_setup` will automatically transfer the data for `obsid` to `$data_dir/0802710101/ODF` from the HEASARC archive.
5. `basic_setup` will run `cfibuild` and `odfingest`.
6. `basic_setup` will then run the basic pipeline tasks `emproc`, `epproc`, and `rgsproc`. The output of these three tasks will be in the `work_dir`.

That is it! Your data is now calibrated, processed, and ready for use with all the standard SAS commands!

```python
odf.basic_setup(data_dir=data_dir,repo='sciserver',overwrite=False)
```

If you need to include options for either or both `cfibuild` and `odfingest`, these can be passed to `odfcompile` using the inputs `cifbuild_opts='Insert options here'` and `odfingest_opts='Insert options here'`.

Input arguments for `epproc`, `emproc`, and `rgsproc` can also be passed in using `epproc_args`, `emproc_args`, or `rgsproc_args` respectively (or `epchain_args` and `emchain_args` if using the chains). By defaut `epproc`, `emproc`, and `rgsproc` will not rerun if output files are found, but they can be forced to rerun by setting `rerun=True` as an input to `basic_setup`.
 
Another important input is `overwrite=True/False`. If set to true, it will erase **all data**, including any previous analysis output, in the obsid directory (i.e. `$data_dir/0802710101/`) and download the original files again.
 
You can also choose the level of data products you download. If you set `level=ODF` then it will download the raw, uncalibrated data and calibrate it. If you set `level=PPS` this will download previously calibrated data products that can be used directly for analysis.


The `odf` object will also store some useful information for analysis. For example, it stores `data_dir`, `odf_dir`, and `work_dir`:

```python
print("Data directory: {0}".format(odf.data_dir))
print("ODF  directory: {0}".format(odf.odf_dir))
print("Work directory: {0}".format(odf.work_dir))
```

The location and name of important files are also stored in a Python dictionary in the odf object.

```python
data_files = list(odf.files.keys())
print(data_files,'\n')
for list_name in data_files:
    print(f'File Type: {list_name}')
    print('>>> {0}'.format(odf.files[list_name]),'\n')
```

If you want more information on the function `basic_setup` run the cell below to see the function documentation.

```python
odf.basic_setup?
```

## 4. Invoking SAS tasks from notebooks

Now we are ready to execute any SAS task needed to analize our data. To execute any SAS task within a Notebook, we need to import from `pysas` a component known as `Wrapper`. The following cell shows how to do that,

```python
from pysas.wrapper import Wrapper as w
```

Any SAS task accepts arguments which can be either specific options, e.g. <tt>--version</tt>, which shows the task's version, or parameters with format <tt>param=value</tt>. When the task is invoked from the command line, these arguments follow the name of the task. However, in Notebooks we have to pass them to the task in a different way. This is done using a Python list, whose name you are free to choose. Let the name of such list be <tt>inargs</tt>.

To pass the option <tt>--version</tt> to the task to be executed, we must define <tt>inargs</tt> as,

```python
inargs = ['--version']
```

To execute the task, we will use the <tt>Wrapper</tt> component imported earlier from <tt>pysas</tt>, as <tt>w</tt> (which is a sort of alias), as follows,

```python
t = w('sasver', inargs)
```

In Python terms, <tt>t</tt> is an *instantiation* of the object <tt>Wrapper</tt> (or its alias <tt>w</tt>).

To run `sasver` [(click here for sasver documentation)](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/sasver/index.html "Documentation for sasver"), we can now do as follows,

```python
t.run()
```

This output is equivalent to having run `sasver` in the command line with argument <tt>--version</tt>.

Each SAS task, regardless of the task being a Python task or not, accepts a predefined set of options. To list which are these options, we can always invoke the task with option <tt>--help</tt> (or <tt>-h</tt> as well).

With `sasver`, as with some other SAS tasks, we could define <tt>inargs</tt> as an empty list, which is equivalent to run the task in the command line without options, like this,

```python
inargs = []
t = w('sasver', inargs)
t.run()
```

That is indeed the desired output of the task `sasver`.

A similar result can be achieved by combining all the previous steps into a single expression, like this,

```python
w('sasver', []).run()
```

The output of `sasver` provides useful information on which version of SAS is being run and which SAS environment variables are defined.

**Note**: It is important to always use [ ] when passing parameters to a task when using the wrapper, as parameters and options have to be passed in the form of a list. For example,  <tt>w('evselect', ['-h']).run()</tt>, will execute the SAS task `evselect` with option <tt>-h</tt>.


### Listing available options
As noted earlier, we can list all options available to any SAS task with option <tt>--help</tt> (or <tt>-h</tt>),

```python
w('sasver', ['-h']).run()
```

As explained in the help text shown here, if the task would have had any available parameters, we would get a listing of them immediately after the help text.

As shown in the text above, the task `sasver` has no parameters.


## 5. How to continue from here?

This depends on your experience level with SAS and what you are using the data for. For a tutorial on preparing and filtering your data for analysis or to make images see [The XMM-Newton ABC Guide](./analysis-xmm-ABC-guide-ch6-p1.md), or check out any of the example notebooks.

In the next cells we show how to run four typical SAS tasks, three `procs` and one `chain`, to process exposures taken with the EPIC PN and MOS instruments, RGS, and OM. You can run these SAS tasks to see what they do. Some of them may take some time to run.

```python
os.chdir(odf.work_dir)
```

```python
inargs = []
w('epproc', inargs).run()
```

The most common SAS tasks to run are: `epproc`, `emproc`, `rgsproc`, and `omichain`. Each one can be run without inputs (but some inputs are needed for more advanced analysis).

You can list all input arguments available to any SAS task with option `'--help'` (or `'-h'`),

```python
w('epproc', ['-h']).run()
```

Here is an example of how to apply a "standard" filter. This is equivelant to running the following SAS command:

```
evselect table=unfiltered_event_list.fits withfilteredset=yes \
    expression='(PATTERN $<=$ 12)&&(PI in [200:12000])&&#XMMEA_EM' \
    filteredset=filtered_event_list.fits filtertype=expression keepfilteroutput=yes \
    updateexposure=yes filterexposure=yes
```
The input arguments should be in a list, with each input argument a separate string. Note: Some inputs require single quotes to be preserved in the string. This can be done using double quotes to form the string. i.e. `"expression='(PATTERN <= 12)&&(PI in [200:4000])&&#XMMEA_EM'"`. An explanation of this filter, and other filters, can be found in [The XMM-Newton ABC Guide](./analysis-xmm-ABC-guide-ch6-p1.md).

```python
unfiltered_event_list = "3278_0802710101_EMOS1_S001_ImagingEvts.ds"

inargs = ['table={0}'.format(unfiltered_event_list), 
          'withfilteredset=yes', 
          "expression='(PATTERN <= 12)&&(PI in [200:4000])&&#XMMEA_EM'", 
          'filteredset=filtered_event_list.fits', 
          'filtertype=expression', 
          'keepfilteroutput=yes', 
          'updateexposure=yes', 
          'filterexposure=yes']

w('evselect', inargs).run()
```

## 6. Alternative to `basic_setup`

<!-- #region -->
The function `basic_setup` is there for convienvience and checks if things have already been run, all with a single command. Running `basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=True)` is the same as running the following commands:

```python
odf.download_data(data_dir=data_dir,overwrite=False,repo='sciserver')
odf.calibrate_odf()
w('epproc',[]).run()
w('emproc',[]).run()
w('rgsproc',[]).run()
```
For more information on the functions `download_data` and `calibrate_odf` see the function documentation by running the cells below.
<!-- #endregion -->

```python
odf.download_data?
```

```python
odf.calibrate_odf?
```

## 7. Just the Raw Data

If you want to just copy the raw data, and not do anything with it, you can use the function `download_data`. The function can accept a number of inputs depending on the type of data required. If the directory `data_dir` does not exist, it will create it. It will also create a subdirectory for the `obsid`.

```python
odf.download_data(data_dir=data_dir,repo='sciserver')
```
