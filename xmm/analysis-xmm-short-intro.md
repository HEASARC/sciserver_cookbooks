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

# pySAS Introduction -- Short Version
<hr style="border: 2px solid #fadbac" />

- **Description:** A short introduction to pySAS on sciserver.
- **Level:** Beginner
- **Data:** XMM observation of NGC 3079 (obsid=0802710101)
- **Requirements:** Must be run using the `HEASARCv6.33.1` image. Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (April 2024)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 1 May 2024, for SAS v21

<hr style="border: 2px solid #fadbac" />


## 1. Introduction
This tutorial provides a short, basic introduction to using pySAS on SciServer. It only covers how to download observation data files and how to calibrate the data.  A much more comprehensive introduction can be found in the [Long pySAS Introduction](./analysis-xmm-long-intro.md "Long pySAS Intro")Long pySAS Introduction</a>. This tutorial is intened for those who are already familiar with SAS commands and want to use Python to run SAS commands. A tutorial on how to learn to use SAS and pySAS for XMM analysis can be found in [The XMM-Newton ABC Guide](./analysis-xmm-ABC-guide-ch6-p1.md "XMM ABC Guide"). In this tutorial we will demonstrate,

1. How to select a directory for data and analysis.
2. How to copy XMM data from the HEASARC archive.
3. How to run the standard XMM SAS commands `cfibuild` and `odfingest`.

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


## 2. Import pySAS and Set `obsid`

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

## 3. Run `odf.odfcompile`

When you run the cell below the following things will happen.

1. `odfcompile` will check if `data_dir` exists, and if not it will create it.
2. Inside data_dir `odfcompile` will create a directory with the value for the obs ID (i.e. `$data_dir/0802710101/`).
3. Inside of that, `odfcompile` will create two directories:

    a. `$data_dir/0802710101/ODF` where the observation data files are kept.
    
    b. `$data_dir/0802710101/work` where the `ccf.cif`, `*SUM.SAS`, and output files are kept. All SAS tasks should be run from this directory.
4. `odfcompile` will automatically transfer the data for `obsid` to `$data_dir/0802710101/ODF` from the HEASARC archive.
5. `odfcompile` will run `cfibuild` and `odfingest`.

That is it! Your data is now calibrated and ready for use with all the standard SAS commands!

```python
odf = pysas.odfcontrol.ODFobject(obsid)
odf.odfcompile(data_dir=data_dir,repo='sciserver',overwrite=False)
```

If you want more information on the function `odfcompile` run the cell below or see the long introduction tutorial.

```python
odf.odfcompile?
```

## 4. Running SAS Tasks
To run SAS tasks, especially ones not written in Python, you will need to import a wrapper from pySAS. SAS tasks should be run from the work directory. The location of the work direcotry is stored as a variable in `odf.work_dir`.

```python
from pysas.wrapper import Wrapper as w
os.chdir(odf.work_dir)
```

The wrapper, imported as `w`, takes two inputs, the name of the SAS task to run, and a Python list of all the input arguments for that task. For example, to run a task with no input arguments you simply provide an empty list as the second argument.

```python
inargs = []
w('epproc', inargs).run()
```

The most common SAS tasks to run are: `epproc`, `emproc`, `rgsproc`, and `omichain`. Each one can be run without inputs (but some inputs are needed for more advanced analysis).

You can list all input arguments available to any SAS task with option `'--help'` (or `'-h'`),

```python
w('epproc', ['-h']).run()
```

If there are multiple input arguments then each needs to be a separate string in the Python list. For example, here is how to apply a "standard" filter. This is equivelant to running the following SAS command:

```
evselect table=unfiltered_event_list.fits withfilteredset=yes \
    expression='(PATTERN $<=$ 12)&&(PI in [200:12000])&&#XMMEA_EM' \
    filteredset=filtered_event_list.fits filtertype=expression keepfilteroutput=yes \
    updateexposure=yes filterexposure=yes
```

The input arguments should be in a list, with each input argument a separate string. Note: Some inputs require single quotes to be preserved in the string. This can be done using double quotes to form the string. i.e. `"expression='(PATTERN <= 12)&&(PI in [200:4000])&&#XMMEA_EM'"`

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

## 5. `basic_setup`


For convenience there is a function called `basic_setup` which will run `odfcompile`, and then run both `epproc` and `emproc`. This allows for data to be copied into your personal data space, calibrated, and run two of the most common SAS tasks, all with a single command.

```python
odf = pysas.odfcontrol.ODFobject(obsid)
odf.basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver',rerun=False)
```

Running `basic_setup(data_dir=data_dir,overwrite=False,repo='sciserver')` is the same as running the following commands:

    odf.odfcompile(data_dir=data_dir,overwrite=False,repo='sciserver')
    w('epproc',[]).run()
    w('emproc',[]).run()
    
Using the function `odf.basic_setup` with <tt>rerun=False</tt> will check if `epproc` or `emproc` have already been run and will not overwrite existing output files. If <tt>rerun=True</tt> then previous output files will be ignored and overwritten.
    
For more information see the function documentation.

```python
odf.basic_setup?
```
