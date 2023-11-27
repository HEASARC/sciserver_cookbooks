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

# Example of a large catalog exploration with a list of sources

In this example, a user has a catalog of several thousand sources they are interested in.  They'd like to find out if they've been observed by HEASARC missions and what the total exposure each sources has for that mission.  This can be done in a variety of inefficient ways such as writing a script to call one of the HEASARC APIs for each of the sources.  But we encourage users to discover the power of querying databases with SQL.  

This tutorial is a HEASARC-specific example of a more general workflow querying astronomy databases with Virtual Observatory protocols as described in our <a href="https://heasarc.gsfc.nasa.gov/navo/summary/about_navo.html">NASA Astronomical Virtual Observatories</a>  (NAVO) <a href="https://nasa-navo.github.io/navo-workshop/CS_Catalog_Queries.html">workshop notebook</a>.  

The step in this tutorial are:
1. Prepare the input source list as VO table in XML format.
2. Find the list of HEASARC missions to be queried.
3. Submit and SQL query.

```python
# suppress some specific warnings that are not important
import warnings
warnings.filterwarnings("ignore", module="astropy.io.votable.*")
warnings.filterwarnings("ignore", module="pyvo.utils.xml.*")
warnings.filterwarnings("ignore", module="astropy.units.format.vounit")

## Generic VO access routines
import pyvo as vo
from astropy.table import Table
from astropy.io.votable import from_table, writeto
from astropy.io import ascii
```

As described in the NAVO workshop notebooks linked above, the first step is to create an object that represents a tool to query the HEASARC catalogs.  

```python
#  Get HEASARC's TAP service:
tap_services = vo.regsearch(servicetype='tap',keywords=['heasarc'])
for s in tap_services:
    if 'heasarc' in s.ivoid:
        heasarc = s
        break
heasarc.describe()
```

---
## 1. Prepare the input source list as VO table in XML format:

VO protocols use the VOTable standard for tables, which is both powerful and complicated.  But astropy has easy tools to convert to and from this XML format. 

Typically, you may start from a list of sources you want to query. In this tutorial, we first create this list in comma-separated value (CSV) format to be used as our input. The file `inlist_10k.csv` contains a list of 10000 RA and DEC values.

We then create a VOTable version that can be used in our query below.  

```python
##  This is how I generated my input list in the first place.  Comment out and replace with your own: 
result = heasarc.service.run_sync("select ra, dec from xray limit 10000")
ascii.write(result.to_table(), "inlist_10k.csv", overwrite=True, format='csv')

## Input a list of sources in CSV format
input_table = Table.read("inlist_10k.csv",format="csv")

#  Convert to VOTable
votable = from_table(input_table)
writeto(votable,"longlist.xml")
```

## 2. Find the list of HEASARC missions to be queried.


Note that you may also wish to generate a list of all of our master catalogs.  In the case of the HEASARC, we have of order a thousand different catalogs, most of which are scientific results rather than mission observation tables.  So you don't want to print all of our catalogs but a selection of them.  For instance, you can do it this way:

```python
master_catalogs=[]
for c in heasarc.service.tables:
    if "master" in c.name or "mastr" in c.name:
        master_catalogs.append(c.name)
print(master_catalogs)
```

## 3. Submit and SQL query.

The next step is to construct a query in the SQL language, specifically a dialect created for astronomical queries, the ADQL.  This is also described briefly in the <a href="https://nasa-navo.github.io/navo-workshop/CS_Catalog_Queries.html">workshop notebook</a> among other places.  

Note also that each service can show you examples that its curators have put together to demonstrate, e.g.:

```python
for e in heasarc.service.examples:
    print(e['QUERY'])
```

<br />

For our use case, we need to do something a bit more complicated involving a *cross-match* between our source list and the HEASARC master catalog for a given mission. While it may be possible to construct an even more complicated query that does all of the HEASARC master catalogs in one go, that may overload the servers, as does repeating the same query 10 thousand times for individual sources. The recommended approch is to do a 10 thousand sources cross match in a few dozen queries to the master catalogs.

So let's start with the Chandra master catalog `chanmaster`.  You can then repeat the exercise for all of the others.

For a cross-match, you can simply upload your catalog with your query as an XML file, and at that point, you tell the service what to name it.  In this case, we call it `mytable`.  Then in your SQL, the table name is `tap_upload.mytable` and it otherwise behaves like any other table. Our list of sources had two columns named RA and DEC, so they are likewise refered to that way in the SQL.  

To compare your source list coordinates with the coordinates in the given master observation table, you an use the special `ADQL` functions `POINT`, `CIRCLE`, and `CONTAINS`, which do basically what they sound like.  The query below matches the input source list against `chanmaster` based on a radius of 0.01 degrees.  For each source, it sums all `chanmaster` observations' exposures to give the total exposure and counts how many observations that was:

```python
#  Construct a query to chanmaster to total the exposures
#   for all of the uploaded sources in the list:
query="""
    SELECT cat.name, cat.ra, cat.dec, sum(cat.exposure) as total_exposure, count(*) as num_obs
    FROM chanmaster cat, tap_upload.mytable mt
    WHERE
    CONTAINS(POINT('ICRS',cat.ra,cat.dec),CIRCLE('ICRS',mt.ra,mt.dec,0.01))=1
    GROUP BY cat.name, cat.ra, cat.dec """
```

```python
#  Send the query to the HEASARC server:
result = heasarc.service.run_sync(query, uploads={'mytable': 'longlist.xml'})
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
    CONTAINS(POINT('ICRS',cat.ra,cat.dec),CIRCLE('ICRS',mt.ra,mt.dec,0.01))=1
    GROUP BY cat.name """

```
<!-- #endregion -->

```python

```
