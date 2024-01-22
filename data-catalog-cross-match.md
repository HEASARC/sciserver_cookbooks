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

# Searching a Large Catalog With a List of Sources
<hr style="border: 2px solid #fadbac" />

- **Description:** An example of cross-matching a list of sources to data in the archive.
- **Level:** Advanced.
- **Data:** A source list of 10,000 source is generate (simulating the user input) and used to find the match in the HEASARC archive.
- **Requirements:** [`pyvo`, `astropy`]".
- **Credit:** Tess Jaffe (May 2023).
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 01/26/2024.

<hr style="border: 2px solid #fadbac" />



## 1. Introduction

In this example, a user has a catalog of several thousand sources they are interested in.  They'd like to find out if they've been observed by HEASARC missions and what the total exposure each sources has for that mission. 

This can be done in a variety of inefficient ways such as writing a script to call one of the HEASARC APIs for each of the sources.  But we encourage users to discover the power of querying databases with Astronomical Data Query Language (ADQL).

This tutorial is a HEASARC-specific example of a more general workflow querying astronomy databases with Virtual Observatory protocols as described in our [NASA Astronomical Virtual Observatories](https://heasarc.gsfc.nasa.gov/navo/summary/about_navo.html) (NAVO) [workshop notebook](https://nasa-navo.github.io/navo-workshop/content/reference_notebooks/catalog_queries.html).

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
The notebook requires `pyvo`, and on Sciserver, it is available on the `heasoft` conda kernel. Make sure you run the notbeook using that kernel by selecting it in the top right.
</div>



## 2. Module Imports
We need the following python modules:


```python
## Generic VO access routines
import pyvo as vo
from astropy.table import Table
from astropy.io import ascii, votable
```

<!-- #region -->
## 3. Find the HEASARC VO Service
The step in this tutorial are:
1. Prepare the input source list as VO table in XML format.
2. Find the list of HEASARC missions to be queried.
3. Submit and ADQL query.


As described in the NAVO workshop notebooks linked above, the first step is to create an object that represents a tool to query the HEASARC catalogs.  
<!-- #endregion -->

```python
#  Get HEASARC's TAP service:
tap_services = vo.regsearch(servicetype='tap',keywords=['heasarc'])
for service in tap_services:
    if 'heasarc' in service.ivoid:
        heasarc = service
        break
heasarc.describe()
```

<!-- #region -->
## 4. Prepare the Input Source List:

To include our list of source with the query, VO protocols use the `VOTable`, which is both powerful and complicated.  But `astropy` has easy tools to handle it. 

As we will show, when submitting that query that includes table data (the list of source coordinates in our case), these can be passed to `pyvo` as either an `astropy` table, or as a file name of the VO table in XML format.


Typically, you may start from a list of sources you want to query. In this tutorial, we first create this list in comma-separated value (CSV) format to be used as our input. The file `source_list.csv` contains a list of 10000 RA and DEC values.

We then create a VOTable that can be used in our query below.  
<!-- #endregion -->

```python
# Write a list of ra,dec values to a CSV file to simulate the input of interest
# Comment out and replace with your own source list file
result = heasarc.service.run_sync("select ra, dec from xray limit 10000")
ascii.write(result.to_table(), "source_list.csv", overwrite=True, format='csv')

# Read the list of sources
input_table = Table.read("source_list.csv",format="csv")

```

## 5. Find the list of HEASARC missions to be queried.


Note that you may also wish to generate a list of all of our master catalogs.  In the case of the HEASARC, we have of order a thousand different catalogs, most of which are scientific results rather than mission observation tables.  So you don't want to print all of our catalogs but a selection of them.  For instance, you can do it this way:

```python
master_catalogs=[]
for table in heasarc.service.tables:
    if "master" in table.name or "mastr" in table.name:
        master_catalogs.append(table.name)
print(master_catalogs)
```

## 6. Submit and ADQL query.

The next step is to construct a query in the SQL language, specifically a dialect created for astronomical queries, the ADQL.  This is also described briefly in the <a href="https://nasa-navo.github.io/navo-workshop/CS_Catalog_Queries.html">workshop notebook</a> among other places.  

Note also that each service can show you examples that its curators have put together to demonstrate, e.g.:

```python
for example in heasarc.service.examples:
    print(example['QUERY'])
```

<br />

For our use case, we need to do something a bit more complicated involving a *cross-match* between our source list and the HEASARC master catalog for a given mission. This is done by uploading our list of sources as part of the query.

While it may be possible to construct an even more complicated query that does all of the HEASARC master catalogs in one go, that may overload the servers, as does repeating the same query 10 thousand times for individual sources. The recommended approch is to do a 10 thousand sources cross match in a few dozen queries to the master catalogs.

So let's start with the Chandra master catalog `chanmaster`.  You can then repeat the exercise for all of the others.

For a cross-match, you can simply upload your catalog with your query as astropy table object or as an XML file, and tell the service what to name it.  In this case, we call it `mytable`.  Then you refer to it in the query as `tap_upload.mytable`.

Our list of sources had two columns named RA and DEC, so they are likewise refered to that way in the SQL query.  

To compare your source list coordinates with the coordinates in the given master observation table, you can use the special `ADQL` functions `POINT`, `CIRCLE`, and `CONTAINS`, which do basically what they sound like.  The query below matches the input source list against `chanmaster` based on a radius of 0.01 degrees.  For each source, it gives back the number of observations (`count(*) as num_obs`) and the total exposures (`sum(cat.exposure) as total_exposure`):


```python
#  Construct a query to chanmaster to total the exposures
#   for all of the uploaded sources in the list:
query="""
    SELECT cat.name, cat.ra, cat.dec, sum(cat.exposure) as total_exposure, count(*) as num_obs
    FROM chanmaster cat, tap_upload.mytable mt
    WHERE
    CONTAINS(POINT('ICRS', cat.ra, cat.dec),CIRCLE('ICRS', mt.ra, mt.dec, 0.01))=1
    GROUP BY cat.name, cat.ra, cat.dec """
```

```python
#  Send the query to the HEASARC server:
result = heasarc.service.run_sync(query, uploads={'mytable': input_table})
#  Convert the result to an Astropy Table
mytable = result.to_table()
mytable
```

The above shows that of our 10k sources, roughly a dozen (since the catalogs are updated daily and the row order may change, these numbers will change between runs of this notebook) were observed anywhere from once to over a thousand times.  

Lastly, you can convert the results back into CSV if you wish:

```python
ascii.write(mytable, "results_chanmaster.csv", overwrite=True, format='csv')
```

<!-- #region -->
Note that sources with slightly different coordinates in the catalogs are summed separately here. If you want to group by the **average** `RA` and `DEC`, the query can be modified to the following, which will average the RA and DEC values that are slightly different for the same source.

```python
query="""
    SELECT cat.name, AVG(cat.ra) as avg_ra, AVG(cat.dec) as avg_dec, sum(cat.exposure) as total_exposure, count(*) as num_obs
    FROM chanmaster cat, tap_upload.mytable mt
    WHERE
    CONTAINS(POINT('ICRS', cat.ra, cat.dec),CIRCLE('ICRS', mt.ra, mt.dec,0.01))=1
    GROUP BY cat.name """

```
<!-- #endregion -->

```python

```
