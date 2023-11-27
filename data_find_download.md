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

# Content
This notebook presents a tutorial of how to access HEASARC data using the virtual observatory (VO) python client `pyvo`.

The use case is a user searching for data on a specific Astronomical object from a specific high energy table. The other [data access tutorial](data_access.ipynb) gives examples other ways to search and access the archive with notebooks.

The first steps in this example are:
- Assume we are searching the NuSTAR master catalog `numaster`.
- Use `pyvo` to obtain all the heasarc services that allow access to the table.
- Select the `conesearch` service, which the VO service that allows for a search on a position in the sky.


```python
# import the relevant libraries
import pyvo
import os
```

```python

# select the services
nu_services = pyvo.regsearch(ivoid='ivo://nasa.heasarc/numaster')[0]

# select the cone search service
cs_service = nu_services.get_service('conesearch')

```

Next, we will use the search function in `cs_service` to search for observations around some source, say the AGN `NGC 4151`.

The `search` function takes as input, the sky position as a variable in the form of an astropy sky coordinate object `SkyCoord`.

The search result is then printed as an astropy Table for a clean display.

```python
from astropy.coordinates import SkyCoord

pos = SkyCoord.from_name('ngc 4151')

search_result = cs_service.search(pos)

# display the result as an astropy table
search_result.to_table()
```

The search returned several entries.

Let's say we are interested only in observations with exposures larger than 50 ks. We do that with a loop over the search results.



```python
obs_to_explore = [res for res in search_result if res['exposure_a'] >= 50000]
obs_to_explore
```

The exposure selection resulted in 3 observations (this may change as more observations are collected). Let's try to download them for analysis.

To see what data products are available for these 3 observations, we use the VO's datalinks. A datalink is a way to query data products related to some search result.

The results of a datalink call will depend on the specific observation. To see the type of products that are available for our observations, we start by looking at one of them.

```python
obs = obs_to_explore[0]
dlink = obs.getdatalink()

# only 3 summary columns are printed
dlink.to_table()[['ID', 'access_url', 'content_type']]
```

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
On Sciserver, all the data is available locally under `/FTP/`, so all we need is to use the link text after `FTP` and copy them to the current directory.


If this is run ourside Sciserver, we can download the data directories using `wget` (or `curl`)

Set the `on_sciserver` to `False` if using this notebook outside Sciserver
<!-- #endregion -->

```python
on_sciserver = True

if on_sciserver:
    # copy data locally on sciserver
    for link in links:
        os.system(f"cp /FTP/{link.split('FTP')[1]} .")

else:
    # use wget to download the data
    wget_cmd = ("wget -q -nH --no-check-certificate --no-parent --cut-dirs=6 -r -l0 -c -N -np -R 'index*'"
                " -erobots=off --retr-symlinks {}")

    for link in links:
        os.system(wget_cmd.format(link))
```

---
- Last Updated: 06/05/2023

```python

```
