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

# HEASARC Sciserver Tutorials
<hr style="border: 2px solid #fadbac" />

Sciserver is a science platform where you get access to both data and analysis software in the same place. No need to download the data nor install the software.

The following notebook tutorials provide some examples of how to use the software already installed on sciserver and accecss the data from the browser. 

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
&#9672; Please make sure the HEASARC data drive is mounted when initializing the sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.

<p>
&#9672; Note also that files under <code>/home/idies/workspace/sciserver_cookbooks</code> are <b style='color:red'>not saved</b> if you close the Sciserver session. If you want data or notebook modifications to be saved, you can copy them into the persistent storage area: <code>/home/idies/workspace/Storage/{user}/persistent</code>.
</p>

</div>

---

<!-- #region -->
## 1. Notebook Tutorials

### 1.1. General Introduction

&#9672; [Quick Start](quick-start.md): A quick start guide on finding, accessing and analyzing HEASARC data.

### 1.2. Finding and Accessing Data

&#9672; [HEASARC Data Access Tutorial](data-access.md): Detailed examples of accessing HEASARC data holdings with the Virtual Observatory protocols using [pyVO](https://pyvo.readthedocs.io/en/latest/). 

&#9672; [Finding and Downloading Data For an Object Using Python](data-find-download.md): A basic example of finding HEASARC data on a specific object using [pyvo](https://pyvo.readthedocs.io/en/latest/) and downloading it.

&#9672; [Query a List of Sources in a Large Catalog (Cross-matching)](data-catalog-cross-match.md): An example of cross-matching the HEASARC master tables against a large list of sources supplied by the user using SQL and TAP services.  


### 1.3 Data Analysis

&#9672; [IXPE Data Example](analysis-ixpe-example.md): This tutorial walks through an example of analyzing data from IXPE, illustrating how to extract source and background spectra and perform spectro-polarimetric fits.

&#9672; [NuSTAR Light Curves Example](analysis-nustar-lightcurve.md): This tutorial shows how extract and start analyzing the light curve of an AGN from one NuSTAR observation.

&#9672; [NICER Analysis Example](analysis-nicer-example.md): This tutorial goes through the steps of analyzing a NICER observation of `PSR_B0833-45` (`obsid = 4142010107`) using `heasoftpy`.

&#9672; [RXTE Light Curve Example](analysis-rxte-lightcurve.md): An example of using the standard products from the PCA detector, and example of re-extracting data products using custom energy channel selection.

&#9672; [RXTE Spectral Extraction and Analysis Example](analysis-rxte-spectra.md): An example for collecting and analyzing a large number of spectral products using [pyXspec](https://heasarc.gsfc.nasa.gov/xanadu/xspec/python/html/index.html).

&#9672; [XMM Short Introduction](./xmm/analysis-xmm-short-intro.md): A short introduction to using [`pysas`](https://github.com/XMMGOF/pysas) on SciServer.

&#9672; [XMM Long Introduction](./xmm/analysis-xmm-long-intro.md): A longer introduction to using [`pysas`](https://github.com/XMMGOF/pysas) on SciServer.

&#9672; [XMM ABC Guide: Part 1](./xmm/analysis-xmm-ABC-guide-ch6-p1.md):  A tutorial on how to apply filters to XMM data. Based on [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide").

&#9672; [XMM ABC Guide: Part 2](./xmm/analysis-xmm-ABC-guide-ch6-p2.md): A tutorial on how to extract the spectra of a point source. Based on [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide").

&#9672; [XMM EPIC Reprocessing](./xmm/analysis-xmm-epic-reprocessing.md): An introduction to processing data from all three EPIC cameras on XMM.

### 1.4 Machine Learning Modeling

&#9672; [Machine Learning Demo using RXTE PCA data](analysis-rxte-ml.md): This tutorial uses some basic machine learning techniques to gain a broad understanding of the behavior of the stellar system **Eta Carinae**.

### 1.5 Other Tutorials

&#9672; [Working with Region Files Using jdaviz](misc-jdaviz-demo.md): An example of using [jdaviz](https://jdaviz.readthedocs.io/en/latest/) inside a jupyter notebook to create region files that can be used in heasoft analysis pipelines. 

&#9672; [Interactive Image Visualization With the World Wide Telescope](misc-wwt-demo.md): An example working interactive image display using WWT.



<!-- #endregion -->

<br />
<br />

<hr style="border: 1px solid #fadbac" />
Last updated: 05/06/2024
