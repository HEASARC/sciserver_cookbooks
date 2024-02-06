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

# Getting Started With HEASARC Data On Sciserver
<hr style="border: 2px solid #fadbac" />

- **Description:** A quick introduction on using HEASARC data on Sciserver.
- **Level:** Beginner
- **Data:** We will use 4 observations of `Cyg X-1` from NuSTAR as an example.
- **Requirements:** Run in the (heasoft) conda environment on Sciserver.
- **Credit:** Abdu Zoghbi (May 2022).
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 02/28/2024

<hr style="border: 2px solid #fadbac" />


## 1. Introduction
In this notebook, we present a brief overview of a typical analysis flow. It can be used as a quick reference.
We will go through an example of **finding**, **accessing** and then **analyzing** some x-ray data data.

We will be using 4 NuSTAR observation of **Cyg-X1**.

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br><br>
<b>Running Outside Sciserver:</b><br>
This notebook runs in the (heasoft) conda environment on Sciserver.
If running outside Sciserver, some changes will be needed, including:<br>
&bull; Make sure heasoftpy and heasoft are correctly installed (<a href='https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/'>Download and Install heasoft</a>).<br>
&bull; Unlike on Sciserver, where the data is available locally, you will need to download the data to your machine.<br>
</div>


## 2. Module Imports
We need the following python modules:


```python
import glob

# for finding data
import pyvo

# import nupipeline from heasoftpy
# for heasoftpy version >= 1.4, it is under heasoftpy.nustar.nupipeline
# for heasoftpy version < 1.4, it is under heasoftpy.nupipeline
try:
    from heasoftpy.nustar import nupipeline
except ModuleNotFoundError:
    from heasoftpy import nupipeline
```

## 3. Finding and Exploring the data

The Heasarc data holdings can be searched and explored in different ways:
- Using [Xamin Web Interface](https://heasarc.gsfc.nasa.gov/xamin/xamin.jsp).

- Using a virtual observatory (VO) client such as [pyVO](https://github.com/astropy/pyvo) (see below) or [Topcat](http://www.star.bris.ac.uk/~mbt/topcat/).

- Using the classical [Browse Mission Interface](https://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3browse.pl).

In [Section 3.1](#3.1-pyvo-example) below, we give an example on how to use `pyVO` to search for NuSTAR data on a specific object. Alternatively, [Section 3.2](#3.2-using-xamin) assumes you can use Xamin to obtain a list of observations you are interested in. For more details on finding and accessing data, see the [notebook on finding and downloading data](data_find_download.md).

The outcome of sections 3.1 and 3.2 is the same, so you can follow either of them.

<!-- #region jp-MarkdownHeadingCollapsed=true -->
### 3.1 Using Virtual Observatory Client pyVO:
<!-- #endregion -->

We first search the Virtual Observatory (VO) *registry* for data provided by `heasarc`. The registry provides an index of all data providers that allow access using VO standards.

In the following example (`heasarc_service`), we search for all entries in the registry that have the keyword `heasarc`. This can a large and general set. The search can be filtered for more specfic datasets.

```python
import pyvo as vo

heasarc_service = vo.regsearch(keywords='heasarc')
print(f'The search returned {len(heasarc_service)} entries. Examples include:\n')

# ivoid is the unique identifier for the dataset
heasarc_service.to_table()[['ivoid', 'res_title']][-5:]
```

---

We can be more specific by selecting only the master catalogs and the services that provide a cone search capability (i.e. search by providing `RA`, `DEC` and a search `radius`).

```python
master = []
for srv in heasarc_service:
    if 'master' in srv.ivoid and 'conesearch' in srv.access_modes():
        master.append(srv)
        print(f'{srv.ivoid}:\t {srv.res_title}')

```

---
Lets focus on *numaster*, the master catalog for *NuSTAR*, and search for data on some object, say the X-ray binary **Cyg X-1**.

We use `astropy` to resolve the name into positional coordinate.
We specify the service we want to use as `conesearch`.

```python
import astropy.coordinates as coord
pos = coord.SkyCoord.from_name("cyg x-1")

nu_master = [m.get_service('conesearch') for m in master if 'numaster' in m.ivoid][0]
result = nu_master.search(pos=pos, radius=0.5)
```

```python
# display the result as an astropy table.
result.to_table()
```

---
Say we are interested in the first 4 datasets. We use another feature of the VO: `datalinks`. 
For each row of interest, we request the related links, and select those that point to a data directory.
They provide `access_url` columns. Here, we collect the paths to the directory containing the event files starting with `FTP`.

```python
paths = []
for i in range(4):
    datalink = result[i].getdatalink().to_table()
    link_to_dirs = datalink[datalink['content_type'] == 'directory']
    link = link_to_dirs['access_url'].value[0]
    path = '/FTP/' + link.split('FTP')[1]
    paths.append(path)
    print(path)
```

### 3.2 Using The Web Portal Xamin:


Here, we use [Xamin](https://heasarc.gsfc.nasa.gov/xamin) to find the data. We again use *numaster*, the master catalog for *NuSTAR*, and search for data the X-ray binary **Cyg X-1**.

When using Xamin to find the data, there is an option in the `Data Products Cart` to select `FTP Paths`, which, when selecting the first 4 datasets, provides a text similar to the following:

> Note that for the purpose of this tutorual, you can choose any observations

```python
paths_txt = """
/FTP/nustar/data/obs/00/3//30001011002/
/FTP/nustar/data/obs/03/3//30302019002/
/FTP/nustar/data/obs/01/1//10102001002/
/FTP/nustar/data/obs/05/8//80502335006/
"""
paths = paths_txt.split('\n')[1:-1]
```


---
## 4. Accessing The Data
All the heasarc data is mounted into the compute under `/FTP/`, so once we have the path to the data (though `pyVO` or Xamin), we can directly access it without the need to download it.

So to check the content of the observational folder for the first observations of `cyg x-1` for example, we can do:

```python
glob.glob(f'{paths[0]}/*')
```

---
---
### 5. Analyzing The Data
To Analyze the data within the notebook, we use `heasoftpy`. In the NuSTAR example, we can call the `nupipeline` tool to produce the cleaned event files.

We focus on the first observation.

```python

# set some input
indir  = paths[0]
obsid  = indir.split('/')[-2] 
outdir = obsid + '_reproc'
stem   = 'nu' + obsid

# call the tasks; verbose=20 logs the output to nupipeline.log
out = nupipeline(indir=indir, outdir=outdir, steminputs=stem, instrument='FPMA',
                 clobber='yes', noprompt=True, verbose=20)
```

Once the task finishes running, we see the new cleaned event files in the local `./30001011002_reproc/` directory


---
---
## 6. Subsequent Analysis
For subsequent analysis, you can use `heasoftpy` which provides a python access to all tools in `heasoft`, as well as `pyxspec` to spectral modeling.

```python

```
