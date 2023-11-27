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

# HEASARC data access on SciServer

Here we show several methods for getting the lists of the files you're interested in.  

```python
import sys,os
import pyvo as vo
import astropy.coordinates as coord
import requests
import glob
import numpy as np
# Ignore unimportant warnings
import warnings
warnings.filterwarnings('ignore', '.*Unknown element mirrorURL.*', 
                        vo.utils.xml.elements.UnknownElementWarning)
```

### Get the HEASARC TAP service

We can use the Virtual Observatory interfaces to the HEASARC to find the data we're  interested in.  Specifically, we want to look at the observation tables.  So first we get a list of all the tables HEASARC serves and then look for the ones related to RXTE. If you are interested in finding and downloading data from a specific telescope, you can use the tutorial in the other [data access notebook](data_find_download.ipynb).

We start with the Registry of all VO services.  The HEASARC table service is using the same backend as our [Xamin web interface](https://heasarc.gsfc.nasa.gov/xamin/), the same database that [Browse](https://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3browse.pl) also uses.  

```python
tap_services=vo.regsearch(servicetype='tap',keywords=['heasarc'])
```

We then ask the service for all of the tables that are available at the HEASARC:

```python
heasarc_tables=tap_services[0].service.tables
```

And then we look for the ones related to XTE:

```python
for tablename in heasarc_tables.keys():
    if "xte" in tablename:  
        print(" {:20s} {}".format(tablename,heasarc_tables[tablename].description))

```

The "xtemaster" catalog is the one that we're interested in.  

Let's see what this table has in it.  Alternatively, we can google it and find the same information here:

https://heasarc.gsfc.nasa.gov/W3Browse/all/xtemaster.html


```python
for c in heasarc_tables['xtemaster'].columns:
    print("{:20s} {}".format(c.name,c.description))
```

We're interested in Eta Carinae, and we want to get the RXTE cycle, proposal, and observation ID etc. for every observation it took of this source based on its position.  (Just in case the name has been entered differently, which can happen.)  This constructs a query in the ADQL language to select the columns (target_name, cycle, prnb, obsid, time, exposure, ra, dec) where the point defined by the observation's RA and DEC lies inside a circle defined by our chosen source position.  The results will be sorted by time.  See the [NAVO website](https://heasarc.gsfc.nasa.gov/vo/summary/python.html) for more information on how to use these services with python and how to construct ADQL queries for catalog searches.

```python
# Get the coordinate for Eta Car
pos=coord.SkyCoord.from_name("eta car")
query="""SELECT target_name, cycle, prnb, obsid, time, exposure, ra, dec 
    FROM public.xtemaster as cat 
    where 
    contains(point('ICRS',cat.ra,cat.dec),circle('ICRS',{},{},0.1))=1 
    and 
    cat.exposure > 0 order by cat.time
    """.format(pos.ra.deg, pos.dec.deg)
```

```python
results=tap_services[0].search(query).to_table()
results
```

###  Xamin's servlet API 


An alternative, if for some reason you don't want to use PyVO, is to use the Xamin API specifically:

The base URL for the Xamin query servelet is 

 https://heasarc.gsfc.nasa.gov/xamin/QueryServlet?
 
 And it then takes options
 * table:  e.g., "table=xtemaster"
 * constraint:   eg., "obsid=10004-01-40-00"
 * object:  "object=andromeda" or "object=10.68,41.27"
  
 So we can do:

```python
url="https://heasarc.gsfc.nasa.gov/xamin/QueryServlet?products&"
result=requests.get(url,params={"table":"xtemaster",
                                "object":"eta car",
                                "resultmax":"10"
                               })
result.text.split('\n')[0:2]
```

```python

```

And then you can construct a file list from the second to last field in each row, the *obs_root.  


###  Know the archive structure

With either method, you're still going to have to know how to find the specific files you're interested in for the given mission.  (We are working on making this easier.)  Then you can take the list of observations from XTE above and find the specific files of the type you want for each of those observations.  

Let's collect all the standard product light curves for RXTE.  (These are described on the [RXTE analysis pages](https://heasarc.gsfc.nasa.gov/docs/xte/recipes/cook_book.html).)

```python
## Need cycle number as well, since after AO9, 
##  no longer 1st digit of proposal number
ids=np.unique( results['cycle','prnb','obsid','time'])
ids.sort(order='time')
ids
```

```python
## Construct a file list.
## Though Jupyter Lab container, either works:
#rootdir="/home/idies/workspace/headata/FTP"
## This one is a link
rootdir="/FTP"
rxtedata="rxte/data/archive"
filenames=[]
for (k,val) in enumerate(ids['obsid']):
    fname="{}/{}/AO{}/P{}/{}/stdprod/xp{}_n2a.lc.gz".format(
        rootdir,
        rxtedata,
        ids['cycle'][k],
        ids['prnb'][k],
        ids['obsid'][k],
        ids['obsid'][k].replace('-',''))
    #print(fname)
    f=glob.glob(fname)
    if (len(f) > 0):
        filenames.append(f[0])
print("Found {} out of {} files".format(len(filenames),len(ids)))
```

```python

```
