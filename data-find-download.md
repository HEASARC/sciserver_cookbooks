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
    name: conda-env-heasoft-py
---

# Finding and Downloading Data For an Object Using Python
<hr style="border: 2px solid #fadbac" />

- **Description:** Tutorial on how to access HEASARC data using the Virtual Observatory client `pyvo`.
- **Level:** Intermediate
- **Data:** Find and download NuSTAR observations of the AGN **3C 105**
- **Requirements:** `pyvo`.
- **Credit:** Abdu Zoghbi (May 2022).
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 02/28/2024

<hr style="border: 2px solid #fadbac" />


<!-- #region -->
## 1. Introduction
This notebook presents a tutorial of how to access HEASARC data using the virtual observatory (VO) python client `pyvo`.

We handle the case of a user searching for data on a specific astronomical object from a *specific* high energy table. For a more general data access tutorial, see the [data access notebook](data-access.md).

We will find all NuSTAR observations of **3C 105** that have an exposure of less than 10 ks.


This notebook searches the NuSTAR master catalog `numaster` using pyvo. We specifically use the `conesearch` service, which the VO service that allows for searching around a position in the sky (3C 105  in this case).

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
The notebook requires <code>pyvo</code>, and on Sciserver, it is available on the <code>heasoft</code> conda kernel. Make sure you run the notbeook using that kernel by selecting it in the top right.
</div>

<!-- #endregion -->

## 2. Module Imports
We need the following python modules:


```python
import os

# pyvo for accessing VO services
import pyvo

# Use SkyCoord to obtain the coordinates of the source
from astropy.coordinates import SkyCoord

```

## 3. Finding and Downloading the data
This part assumes we know the ID of the VO service. Generally these are of the form: `ivo://nasa.heasarc/{table_name}`.

If you don't know the name of the table, you can search the VO registry, as illustrated in the [data access notebook](data-access.md).

### 3.1 The Search Serivce
First, we create a cone search service:


```python
# Create a cone-search service
nu_services = pyvo.regsearch(ivoid='ivo://nasa.heasarc/numaster')[0]
cs_service = nu_services.get_service('conesearch')

```

### 3.2 Find the Data

Next, we will use the search function in `cs_service` to search for observations around our source, NGC 4151.

The `search` function takes as input, the sky position either as a list of `[RA, DEC]`, or as a an astropy sky coordinate object `SkyCoord`.

The search result is then printed as an astropy Table for a clean display.

```python
# Find the coordinates of the source
pos = SkyCoord.from_name('3c 105')

search_result = cs_service.search(pos)

# display the result as an astropy table
search_result.to_table()
```

### 3.3 Filter the Results

The search returned several entries.

Let's say we are interested only in observations with exposures smaller than 10 ks. We do that with a loop over the search results.



```python
obs_to_explore = [res for res in search_result if res['exposure_a'] <= 10000]
obs_to_explore
```

### 3.4 Find Links for the Data

The exposure selection resulted in 3 observations (this may change as more observations are collected). Let's try to download them for analysis.

To see what data products are available for these 3 observations, we use the VO's datalinks. A datalink is a way to query data products related to some search result.

The results of a datalink call will depend on the specific observation. To see the type of products that are available for our observations, we start by looking at one of them.

```python
obs = obs_to_explore[0]
dlink = obs.getdatalink()

# only 3 summary columns are printed
dlink.to_table()[['ID', 'access_url', 'content_type']]
```

### 3.4 Filter the Links

Three products are available for our selected observation. From the `content_type` column, we see that one is a `directory` containing the observation files. The `access_url` column gives the direct url to the data (The other two include another datalink service for house keeping data, and a document to list publications related to the selected observation).

We can now loop through our selected observations in `obs_to_explore`, and extract the url addresses with `content_type` equal to `directory`.

Note that an empty datalink product indicates that no public data is available for that observation, likely because it is in proprietary mode.

```python
# loop through the observations
links = []
for obs in obs_to_explore:
    dlink = obs.getdatalink()
    dlink_to_dir = [dl for dl in dlink if dl['content_type'] == 'directory']
    
    # if we have no directory product, the data is likely not public yet
    if len(dlink_to_dir) == 0:
        continue
    
    link = dlink_to_dir[0]['access_url']
    print(link)
    links.append(link)
```

<!-- #region -->
### 3.5 Download the Data

On Sciserver, all the data is available locally under `/FTP/`, so all we need is to use the link text after `FTP` and copy them to the current directory.


If this is run ourside Sciserver, we can download the data directories using `wget` (or `curl`)

Set the `on_sciserver` to `False` if using this notebook outside Sciserver
<!-- #endregion -->

```python
on_sciserver = os.environ['HOME'].split('/')[-1] == 'idies'

if on_sciserver:
    # copy data locally on sciserver
    for link in links:
        os.system(f"cp -r /FTP/{link.split('FTP')[1]} .")

else:
    # use wget to download the data
    wget_cmd = ("wget -q -nH --no-check-certificate --no-parent --cut-dirs=6 -r -l0 -c -N -np -R 'index*'"
                " -erobots=off --retr-symlinks {}")

    for link in links:
        os.system(wget_cmd.format(link))
```

```python

```
