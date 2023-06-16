
### Welcome To The HEASARC Sciserver Tutorials

Sciserver is a science platform where you get access to both data and analysis software in the same place. No need to download the data nor install the software.

The following notebook tutorials provide some examples of how to use the software already installed on sciserver and accecss the data from the browser. 

<div style='color: #666; background: #eee; padding:10px'>
Please make sure the HEASARC data drive is mounted when initializing the sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<p>Also, make sure to run the notebooks using the (heasoft) kernel</p>
</div>

---



&#9672; [Getting Started](Getting-Started.ipynb): A quick guide on accessing the data and using [heasoftpy](https://github.com/HEASARC/heasoftpy) for analysis.

&#9672; [Data Access Tutorial](data_access.ipynb): Detailed examples of accessing HEASARC data holdings with the Virtual Observatory protocols using [pyvo](https://pyvo.readthedocs.io/en/latest/). 

&#9672; [Querying A List of Sources](source_list_querying.ipynb): An example searching the HEASARC master tables for a large list of sources supplied by the user using SQL and TAP services. 

&#9672; [Simple Data Access Tutorial](data_find_download.ipynb): A simple example of finding HEASARC data on a specific source using [pyvo](https://pyvo.readthedocs.io/en/latest/) and downloading it. 

&#9672; [Working with Region Files Using jdaviz](jdaviz-demo.ipynb): An example of using [jdaviz](https://jdaviz.readthedocs.io/en/latest/) inside a jupyter notebook to create region files that can be used in heasoft analysis pipelines. 
>>>>>>> bede84c (added jdaviz demo with a link in the intro doc)

&#9672; [IXPE Introduction](ixpe_intro.ipynb): This tutorial walks through an example of analyzing data from IXPE, illustrating how to extract source and background spectra and perform spectro-polarimetric fits.

&#9672; [NuSTAR Light Curves](nustar_lightcurve_example.ipynb): This tutorial shows how extract and start analyzing the light curve of an AGN from one NuSTAR observation.

&#9672; [NICER Example](nicer-example.ipynb): This tutorial goes through the steps of analyzing a NICER observation of `PSR_B0833-45` (`obsid = 4142010107`) using `heasoftpy`.

&#9672; [RXTE Light Curve Example](rxte_example_lightcurves.ipynb): An example of using the standard products from the PCA detector, and example of re-extracting data products using custom energy channel selection.

&#9672; [RXTE Spectral Example](rxte_example_spectral.ipynb): An example for collecting and analyzing a large number of spectral products using [pyXspec](https://heasarc.gsfc.nasa.gov/xanadu/xspec/python/html/index.html).

&#9672; [Machine Learning Demo using RXTE PCA data](demo_rxte_ml.ipynb): This tutorial uses some basic machine learning techniques to gain a broad understanding of the behavior of the stellar system Eta Carinae.


<br />
<br />

---
Last updated: 05/03/2023
