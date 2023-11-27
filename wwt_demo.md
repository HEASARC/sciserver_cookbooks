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

## Visualization Demo

This demonstration of visualizatioin uses the [PyWWT package](https://pywwt.readthedocs.io/en/stable/)  as well as catalog access and image retrieval with [PyVO](https://pyvo.readthedocs.io/en/latest/).  For more about how to use the latter, see the [python notebooks](https://heasarc.gsfc.nasa.gov/navo/summary/python.html) developed by the NASA archives.  

```python
## Two ways to do this.  If you open the WWT App through 
##  the JupyterLab Launcher, here's how to connect to it:
#from pywwt.jupyter import connect_to_app
#wwt = connect_to_app()
## Or you can open the widget in this notebook
import warnings
from astropy.io import fits
from astropy.utils.data import download_file
from astropy import units as u

import matplotlib.pyplot as plt


import astropy.coordinates as coord
import pyvo as vo
warnings.filterwarnings('ignore', '.*Unknown element mirrorURL.*', vo.utils.xml.elements.UnknownElementWarning)

from pywwt.jupyter import WWTJupyterWidget
wwt = WWTJupyterWidget()
wwt
```

The widget opens up with a default view. Let's set the background to Halpha emission and the field of view to center on the crab.  You can do the pan and zoom with your mouse or with the command below.  

```python
wwt.background = 'Hydrogen Alpha Full Sky Map' 
coords=coord.SkyCoord.from_name('crab')
from astropy import units as u
wwt.center_on_coordinates(coords,fov=5*u.arcmin)

```

Now we're going to look for Chandra observations of the crab using a query to the HEASARC catalog service.  Let's just get the top 10 deepest exposures:

```python
#  Get the TAP service from the Registry.  
heasarc=vo.regsearch(servicetype='tap',keywords=['heasarc'])[0]
query=f"""SELECT top 10 * 
    FROM chanmaster
    WHERE 1=CONTAINS(POINT('ICRS', ra, dec),CIRCLE('ICRS', {coords.ra.deg}, {coords.dec.deg}, 1))  
 """

results=heasarc.search(query)
results.to_table()
```

Now that we have a list of observations, we can see what data products are available for them using the getdatalink() function look for a FITS image to display.  Each observation has a list of things you can retrieve, some of which are further links to browse deeper into the HEASARC archive.  This function below recurses down a given observation to find products of a given type:

```python
def linkwalker( result, level, keyword=None, ctype=None,returnFirst=True):
    try:
        result2=result.getdatalink()
        if keyword is None and ctype is None:
            print(result2.to_table()['description','content_type'])
        else:
            for i,r in enumerate(result2.to_table()):
                if keyword is not None and keyword.lower() not in r['description'].lower():
                    continue 
                if ctype is not None and ctype.lower() not in r['content_type'].lower():
                    continue
                print(f"Found match in level {level}")
                return(result2[i])
    except Exception as e:
        print("Exception {}".format(e))
        return
    for link in [l for l in result2 if "datalink" in l.content_type]:
        x=linkwalker(link, level+1, keyword,ctype)
        if x is not None:
            return(x)
    return
```

Not all of these observations have a FITS image available.  You can browse them, or loop over them, as you wish.  You'll find that the 9th row (counting from 0) has a decent looking image:

```python
#  This returns the (first) Record corresponding to the 
#   Center Image in FITS for the given observation:
r=linkwalker(results[9],0,keyword='Center',ctype='fits')
hdu_list = fits.open(r.getdataurl())
plt.imshow(hdu_list[0].data)
```

```python
hdu_list[0].data.shape
```

Let's just cut out the central region:

```python
from astropy.nddata import Cutout2D
from astropy.wcs import WCS
from astropy import units as u
w = WCS(hdu_list[0].header, hdu_list)
cutout = Cutout2D(hdu_list[0].data, coords, (2*u.arcmin,2*u.arcmin), wcs=w)
```

```python
plt.imshow(hdu_list[0].data,origin='lower')
cutout.plot_on_original(color='white')
```

So now let's add it to the viewing widget on top of the background Halpha emission:

```python
layer2= wwt.layers.add_image_layer(image=(cutout.data,cutout.wcs))
layer2.opacity=0.5
```

```python

```
