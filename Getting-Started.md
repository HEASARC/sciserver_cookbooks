---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.15.2
  kernelspec:
    display_name: (heasoft)
    language: python
    name: heasoft
---

## Getting Started

This notebooks contains some tips on getting started with accessing and using HEASARC data on Sciserver.


### Finding and Exploring the data

The Heasarc data holdings can be searched and explored in different ways:
- Using the powerful [Xamin Web Interface](https://heasarc.gsfc.nasa.gov/xamin/xamin.jsp).

- Using a virtual observatory (VO) client such as [pyVO](https://github.com/astropy/pyvo) (see below) or [Topcat](http://www.star.bris.ac.uk/~mbt/topcat/).

- Using the classical [Browse Mission Interface](https://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3browse.pl).

In Section 1. below, we give a quick example on how to use pyVO to search for NuSTAR data on a specific object. Alternatively, in section 2 assumes you can use Xamin to obtain a list of observations you are interested in. 

The outcome of sections 1 and 2 is the same, so you can follow either of them.

<!-- #region jp-MarkdownHeadingCollapsed=true -->
---
#### 1. pyVO Example
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

nu_master = master[3].get_service('conesearch')
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

---
#### 2. Using Xamin:


Here, we use Xamin to find the data. We again use *numaster*, the master catalog for *NuSTAR*, and search for data the X-ray binary **Cyg X-1**.

When using Xamin to find the data, there is an option in the `Data Products Cart` to select `FTP Paths`, which, when selecting the first 4 datasets, provides a text similar to the following:

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
---
### Accessing The Data
All the heasarc data is mounted into the compute under `/FTP/`, so once we have the path to the data (though `pyVO` or Xamin), we can directly access it without the need to download it.

So to check the content of the observational folder for the first observations of `cyg x-1`, we can do:

```python
import glob
glob.glob(f'{paths[0]}/*')
```

---
---
### Analyzing The Data
To Analyze the data within the notebook, we use `heasoftpy`. In the *NuSTAR* example, we can call the `nupipeline` tool to re-prodduce the cleaned event files.

```python
import heasoftpy as hsp


# set some input
indir  = paths[0]
obsid  = indir.split('/')[-2] 
outdir = obsid + '_reproc'
stem   = 'nu' + obsid

# call the tasks; verbose=20 logs the output to nupipeline.log
out = hsp.nupipeline(indir=indir, outdir=outdir, steminputs=stem, instrument='FPMA', 
                     clobber='yes', noprompt=True, verbose=20)
```

Once the task finishes running, we see the new cleaned event files in the local `./30001011002_reproc/` directory


---
---
### Subsequent Analysis
For subsequent analysis, you can use `heasoftpy` which provides a python access to all tools in `heasoft`, as well as `pyxspec` to spectral modeling.
