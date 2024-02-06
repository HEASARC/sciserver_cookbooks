---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.16.0
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
---

# Descriptive Title of the Content of the Notebook
<hr style="border: 2px solid #fadbac" />
Header Section: include the following information.

- **Description:** A template on how to write a notebook tutorial on sciserver.
- **Level:** Beginner | Intermediate | Advanced.
- **Data:** Descirbe what data, if any will be use. If None, write: NA
- **Requirements:** Describe what is needed to run the notebooks. For example: "Run in the (heasof) conda environment on Sciserver". Or "python packages: [`heasoftpy`, `astropy`, `numpy`]".
- **Credit:** Who wrote the notebebook and when.
- **Support:** How to get help.
- **Last verified to run:** (00/00/000) When was this last tested.

<hr style="border: 2px solid #fadbac" />


## 1. Introduction
Describe the content. It can contain 0plain text, bullets, and/or images as needed. 
Use `Markdown` when writing.

The following are suggested subsections. Not all are needed:
- Motivation / Science background.
- Learning goals.
- Details about the requirements, and on running the notebook outside Sciserver. 
- Type of outcome or end product.

You may want to include the following section on how to run the notebook outise sciserver.
<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br><br>
<b>Running Outside Sciserver:</b><br>
This notebook runs in the heasoftpy conda environment on Sciserver.
If running outside Sciserver, some changes will be needed, including:<br>
&bull; Make sure heasoftpy and heasoft are correctly installed (<a href='https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/'>Download and Install heasoft</a>).<br>
&bull; Unlike on Sciserver, where the data is available locally, you will need to download the data to your machine.<br>
</div>

The following gives an example sections.


## 2. Imports

```python
# add imports here
import heasoftpy as hsp
```

## 3.0 Define Input if needed
This section will include things like:
- obsIDs
- Plot settings
- Work directory
- Detector settings
- etc

```python
obsid = '000000000'
```

## 4. Data Access
How is the data used here can be found, and accessed (e.g. copied, downloaded etc.)


## 5. Data Processing or Extraction
Include this section if needed (choose a relevant title)


## 6. Data Products
If the notebook produces some data products, describe them here, and how the user will be using them.

```python

```
