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

# HEASARC Data Access on SciServer
<hr style="border: 2px solid #fadbac" />

- **Description:** A general overview on accessing data on Sciserver.
- **Level:** Intermediate.
- **Data:** Access XTE data on Eta Car as an example.
- **Requirements:** `pyvo`.
- **Credit:** Tess Jaffe (Sep 2021).
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 02/28/2024.

<hr style="border: 2px solid #fadbac" />


<!-- #region -->
## 1. Introduction
This notebook presents a tutorial of how to access HEASARC data using the virtual observatory (VO) python client `pyvo`.

We handle the general case of using the Tabel Access Protocol (TAP) to query any information about the HEASARC tables. A more specific data access tutorial when the table is known, is given in the [notebook on Finding and Downloading Data](data-find-download.md).

The case will be illustrated by querying for XTE observations of **Eta Car** .


<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
The notebook requires <code>pyvo</code>, and on Sciserver, it is available on the <code>heasoft</code> conda kernel. Make sure you run the notbeook using that kernel by selecting it in the top right.
</div>

<!-- #endregion -->

## 2. Module Imports
We need the following python modules:


```python
import sys
import os
import pyvo
from astropy.coordinates import SkyCoord
import requests
import glob
import numpy as np
```

## 3. Get the HEASARC TAP service

We can use the Virtual Observatory interfaces to the HEASARC to find the data we're  interested in.  Specifically, we want to look at the observation tables.  So first we get a list of all the tables HEASARC serves and then look for the ones related to RXTE.

### 3.1 Find the Tables

We start with the Registry of all VO services.  The HEASARC table service is using the same backend as our [Xamin web interface](https://heasarc.gsfc.nasa.gov/xamin/), the same database that [Browse](https://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3browse.pl) also uses.  


```python
tap_services = pyvo.regsearch(servicetype='tap', keywords=['heasarc'])
```

We then ask the service for all of the tables that are available at the HEASARC:

```python
heasarc_tables = tap_services[0].service.tables
```

And then we look for the ones related to XTE:

```python
for tablename in heasarc_tables.keys():
    if "xte" in tablename:  
        print(" {:20s} {}".format(tablename, heasarc_tables[tablename].description))

```

The `xtemaster` catalog is the one that we're interested in.  

Let's see what this table has in it.  The same information is availabe in the table description in the website:

https://heasarc.gsfc.nasa.gov/W3Browse/all/xtemaster.html


```python
for column in heasarc_tables['xtemaster'].columns:
    print("{:20s} {}".format(column.name, column.description))
```

### 3.2 Build a Search Query


We're interested in Eta Carinae, and we want to get the RXTE cycle, proposal, and observation ID etc. for every observation it took of this source based on its position (Just in case the name has been entered differently, which can happen.)  

The following constructs a query in the ADQL language to select the columns (`target_name`, `cycle`, `prnb`, `obsid`, `time`, `exposure`, `ra`, `dec`) where the point defined by the observation's RA and DEC lies inside a circle defined by our chosen source position.  

The results will be sorted by time.  See the [NAVO website](https://heasarc.gsfc.nasa.gov/vo/summary/python.html) for more information on how to use these services with python and how to construct ADQL queries for catalog searches.

You can also find more detailed on using these services in the [NASA Virtual Observatory workshop tutorials (NAVO)](https://nasa-navo.github.io/navo-workshop/)

```python
# Get the coordinate for Eta Car
pos = SkyCoord.from_name("eta car")
query = """SELECT target_name, cycle, prnb, obsid, time, exposure, ra, dec 
    FROM public.xtemaster as cat 
    where 
    contains(point('ICRS',cat.ra,cat.dec),circle('ICRS',{},{},0.1))=1 
    and 
    cat.exposure > 0 order by cat.time
    """.format(pos.ra.deg, pos.dec.deg)
```

```python
results = tap_services[0].search(query).to_table()
results
```

## 4.  Using Xamin's API 


An alternative method to access the data is to use the Xamin API specifically. [Xamin](https://heasarc.gsfc.nasa.gov/xamin/) is the main web portal for accessing HEASARC data, and it offers an API that can be used to query the same tables.

The base URL for the Xamin query servelet is, which will be queries using the `requests` module.

`https://heasarc.gsfc.nasa.gov/xamin/QueryServlet?`
 
And it takes the options:
 * table:  e.g., "table=xtemaster"
 * constraint:   eg., "obsid=10004-01-40-00"
 * object:  "object=andromeda" or "object=10.68,41.27"
  
So we can do:

```python
url = "https://heasarc.gsfc.nasa.gov/xamin/QueryServlet?products&"
result = requests.get(url,params = {"table":"xtemaster",
                                    "object":"eta car",
                                    "resultmax":"10"
                                   })
result.text.split('\n')[0:2]
```

And then you can construct a file list from the second to last field in each row, the *obs_root.  


## 5. Obtain the Data

If you know structure of the mission data, you can take the list of observations from XTE above and find the specific files of the type you want for each of those observations.

For example, let's collect all the standard product light curves for RXTE.  (These are described on the [RXTE analysis pages](https://heasarc.gsfc.nasa.gov/docs/xte/recipes/cook_book.html).)

A second approach is to use the [Xamin](https://heasarc.gsfc.nasa.gov/xamin/) protal, find the data prodcuts and obtain the links there.

Yet another approach is to use VO datalinks service (via `pyvo`) to find the links to the data. An example of how to do it is shown in the [Finding and Downloading Data notebook](data-find-download.md).

We are working on making more ways to find the data products from the notebook.

The following will use the first approach.

```python
# obtain information about the observations
ids = np.unique( results['cycle','prnb','obsid','time'])
ids.sort(order='time')
ids
```

```python
# Construct a file list.
rootdir = "/FTP"
rxtedata = "rxte/data/archive"
filenames = []

for (k,val) in enumerate(ids['obsid']):
    fname="{}/{}/AO{}/P{}/{}/stdprod/xp{}_n2a.lc.gz".format(
        rootdir,
        rxtedata,
        ids['cycle'][k],
        ids['prnb'][k],
        ids['obsid'][k],
        ids['obsid'][k].replace('-',''))
    
    f = glob.glob(fname)
    if (len(f) > 0):
        filenames.append(f[0])

print("Found {} out of {} files".format(len(filenames),len(ids)))

```

On Sciserver, the data can be copied directly from the mount archive located under `/FTP/`

```python

```
