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

# RXTE Spectral Analysis with Minimal Machine Learning
<hr style="border: 2px solid #fadbac" />

- **Description:** A basic example of using Machine Learning to explore X-ray spectra.
- **Level:** Intermediate.
- **Data:** RXTE observations of **eta car** taken over 16 years.
- **Requirements:** `pyvo`, `matplotlib`, `tqdm`, `xspec`, `sklearn`, `umap`
- **Credit:** Tess Jaffe, Brian Powell (Sep 2021).
- **Support:** Contact the [HEASARC helpdesk](https://heasarc.gsfc.nasa.gov/cgi-bin/Feedback).
- **Last verified to run:** 02/02/2024.

<hr style="border: 2px solid #fadbac" />


## 1. Introduction
In this tutorial, we will do some data exploration of the RXTE spectra of **Eta Car**. We assume that we know nothing about the stellar system, but want to gain a broad understanding of its behavior and spectral changes in a model-independent way. We can achieve this with very litte code and some basic machine learning techniques.

We will first use the HEASARC Virtual Observatory services to find the data (You can also see the [Getting Started](getting-started.md), [Data Access](data-access.md) and  [Finding and Downloading Data](data-find-download.md) tutorials for more example on finding HEASARC data using `pyvo`).

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On Sciserver:</b><br>
When running this notebook inside Sciserver, make sure the HEASARC data drive is mounted when initializing the Sciserver compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br>
Also, the required python modules are available in the (heasoft) conda environment. You should see (heasoft) at the top right of the notebook. If not, click there and select it.

<b>Running Outside Sciserver:</b><br>
If running outside Sciserver, some changes will be needed, including:<br>
&bull; Make sure <code>pyxspec</code> and heasoft are installed (<a href='https://heasarc.gsfc.nasa.gov/docs/software/lheasoft/'>Download and Install heasoft</a>).<br>
&bull; Unlike on Sciserver, where the data is available locally, you will need to download the data to your machine.<br>
</div>



## 2. Module Imports
We need the following python modules:


```python
import os
# pyvo is used for querying the data from the archive
import pyvo as vo
import numpy as np
from astropy.io import fits
from astropy.coordinates import SkyCoord
from tqdm import tqdm
import matplotlib.pyplot as plt

# sklearn is used for the machine learning modeling
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE
from sklearn.cluster import DBSCAN
from umap import UMAP

# xspec is used to read the spectra
import xspec
```

## 2. Finding the Data
First, we will need to find the spectra data for **Eta Car**. We will use `pyvo` to query the HEASARC archive for XTE observations of the sources.

We first initalize a table access protocol (TAP) service, and use it to submit a query to the archive to retrieve the information we need.

`xtemaster` is the name of the table we will query.
For more information and examples on finding and access data, se the [Data Access](data-access.md) and [Finding and Downloading Data](data-find-download.md) tutorials. 

There, you will find information on how to find the table and column names. For the `xtemaster` table, the columns are also available on the [Browse](https://heasarc.gsfc.nasa.gov/W3Browse/all/xtemaster.html) page. In this example, we query the following columns: `target_name`, `cycle`, `prnb`, `obsid`, `time`, `exposure`, `ra` and `dec`

### 2.1 Query the Archive for Relevant Data

```python
# Set up the catalog
tap_services = vo.regsearch(servicetype='tap',keywords=['heasarc'])
heasarc_tables = tap_services[0].service.tables
```

```python
# create a query
pos = SkyCoord.from_name("Eta Car")
query="""SELECT target_name, cycle, prnb, obsid, time, exposure, ra, dec 
    FROM public.xtemaster as cat 
    where 
    contains(point('ICRS',cat.ra,cat.dec),circle('ICRS',{},{},0.1))=1 
    and 
    cat.exposure > 0 order by cat.time
    """.format(pos.ra.deg, pos.dec.deg)
```

```python
# submit the query and get a table back
results = tap_services[0].search(query).to_table()
```

```python
# Let's keep only the columns we will be using
results  = np.unique( results['cycle', 'prnb', 'obsid'])
```

### 2.2 Identify the Spectral Data
Next, we create a list of spectral files based on the list of observations

`filenames` is a list of existing spectral data products that we will use in subsequent analyses.

```python
## Construct a file list.
rxtedata = "/FTP/rxte/data/archive"
filenames = []
times = []
for id in tqdm(results):
    #  Skip some for a quicker test case
    fname = "{}/AO{}/P{}/{}/stdprod/xp{}_s2.pha.gz".format(
        rxtedata,
        id['cycle'],
        id['prnb'],
        id['obsid'],
        id['obsid'].replace('-',''))
    # keep only files that exist in the archive
    if os.path.exists(fname):
        filenames.append(fname)
        # get the start time
        with fits.open(fname) as fp:
            times.append(fp[0].header['TSTART'])
print(f"Found {len(filenames)} spectra")
```


## 3. Read and Plot the Spectra
Since the spectra are stored in channel space, forward modeling is generally needed to fit them with some physical model. Since we are **not** fitting physical models, we use `xspec` to load the spectra, and the export them as arrays of normalized counts per second versus keV.

Additionally, to allow these spectra to be manipulated with standard Machine Learning tools such as `sklearn`, we put all the spectra into a common energy grid that runs between 2 and 12 keV, in steps of 0.1 keV. This is generally not a recommended way of analyzing X-ray spectra, but this is reasonable given that we interested in the general spectral shape.


```python

xspec.Xset.chatter = 0

# other xspec settings
xspec.Plot.area = True
xspec.Plot.xAxis = "keV"
xspec.Plot.background = True


# Setup some energy grid that the spectra will interpolate over.
# start at 2 keV due to low-resolution noise below that energy - specific to RXTE
# stop at 12 keV due to no visible activity from Eta Carinae above that energy
xref = np.arange(2., 12, 0.1)

# number of spectra to read. We limit it to 500. Change as desired.
nspec = len(filenames)

# current working directory
cwd = os.getcwd()

# The spectra will be saved in a list
specs = []
for file in tqdm(filenames[:nspec]):
    # clear out any previously loaded dataset
    xspec.AllData.clear()

    # change location to the spectrum folder before reading it
    os.chdir(os.path.dirname(file))
    spec = xspec.Spectrum(file)
    os.chdir(cwd)
    

    xspec.Plot("data")
    xVals = xspec.Plot.x()
    yVals = xspec.Plot.y()
    yref  = np.interp(xref, xVals, yVals)
    specs.append(yref)

specs = np.array(specs)
stimes = np.array(times)[:nspec]
```

Plot the collected spectra in log-log scale.

```python
xvals = np.tile(xref, (specs.shape[0],1))
plt.figure(figsize=(10,6));
plt.loglog(xvals.T, specs.T, linewidth=0.4);
plt.xlabel('Energy (keV)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('Eta Carinae RXTE Spectra (log-log)');
```

## 4. Exploring the Data with Unsupervized Machine Learning 
In the following, we will use different models from the `sklearn` module.

As a general rule, ML models work best when they are normalized, so the shape is important, not just the magnitude. We use [StandardScaler](https://scikit-learn.org/stable/modules/generated/sklearn.preprocessing.StandardScaler.html).

Note that after applying the scaler, we switch to plots in a linear scale.

### 4.1 Normalize the Spectra

```python

scaled_specs = []
for i in tqdm(range(specs.shape[0])):
    s = StandardScaler()
    scaled_specs.append(s.fit_transform(specs[i].reshape(-1,1)).T[0])
scaled_specs = np.array(scaled_specs)

```

Visualize the scaled and unscaled spectra for comparison

```python
plt.figure(figsize=(10,6));
plt.plot(xvals.T, scaled_specs.T, linewidth=0.3);
plt.xlabel('Energy (keV)');
plt.ylabel('Scaled Normalized Count Rate (C/s)');
plt.title('Scaled Eta Carinae RXTE Spectra (lin-lin)');

plt.figure(figsize=(10,6));
plt.plot(xvals.T, specs.T, linewidth=0.3);
plt.xlabel('Energy (keV)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('Unscaled Eta Carinae RXTE Spectra (lin-lin)');
```

Note that the scaled spectra all have a similiar shape AND magnitude, whereas the unscaled spectra have a similar shape but not mangitude.

Scaling has the effect of making big features smaller, but small features bigger. So, let's cut off the spectra at 9 keV in order to avoid noise driving the analysis, then rescale.

```python
specs = specs[:,:xref[xref<=9.0001].shape[0]]
xref = xref[:xref[xref<=9.0001].shape[0]]

scaled_specs = []
for i in tqdm(range(specs.shape[0])):
    s = StandardScaler()
    scaled_specs.append(s.fit_transform(specs[i].reshape(-1,1)).T[0])
scaled_specs = np.array(scaled_specs)
```

Plot the scaled and unscaled spectra for comparison again.

```python
xvals=np.tile(xref,(specs.shape[0],1))
plt.figure(figsize=(10,6));
plt.plot(xvals.T, scaled_specs.T, linewidth=0.4);
plt.xlabel('Energy (keV)');
plt.ylabel('Scaled Normalized Count Rate (C/s)');
plt.title('Scaled Eta Carinae RXTE Spectra (lin-lin)');

plt.figure(figsize=(10,6));
plt.plot(xvals.T, specs.T, linewidth=0.4);
plt.xlabel('Energy (keV)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('Unscaled Eta Carinae RXTE Spectra (lin-lin)');
```

### 4.2 Dimension Reduction: Principle Component Analysis
The scaled spectra are now ready for analysis.  Let's see what we can learn by using [Principal Component Analysis (PCA)](https://scikit-learn.org/stable/modules/generated/sklearn.decomposition.PCA.html) in two dimensions...

We first decompose the spectra and then plot the components.

```python
# For comparison, compute PCA
pca = PCA(n_components=2)
scaled_specs_pca = pca.fit_transform(scaled_specs)
plt.figure(figsize=(8,8))
plt.scatter(scaled_specs_pca[:,0],scaled_specs_pca[:,1]);
plt.title('PCA-reduced Eta Carinae RXTE Spectra');
plt.axis('off');
```

### 4.3 Dimension Reduction: T-distributed Stochastic Neighbor Embedding (TSNE)

`PCA` preserves distance, but has no concept of high-dimensional groupings.

For comparison, compute [`TSNE`](https://scikit-learn.org/stable/modules/generated/sklearn.manifold.TSNE.html), which can extract local high-dimensional relationships.

```python
tsne = TSNE(n_components=2)
scaled_specs_tsne = tsne.fit_transform(scaled_specs)
plt.figure(figsize=(8,8))
plt.scatter(scaled_specs_tsne[:,0],scaled_specs_tsne[:,1]);
plt.title('TSNE-reduced Eta Carinae RXTE Spectra');
plt.axis('off');
```

### 4.4 UMAP: Uniform Manifold Approximation and Projection for Dimension Reduction
`TSNE` indeed finds some local groupings, so let's check `UMAP`, which will allow us to understand local and global relationships.


```python
um = UMAP(random_state=1)
scaled_specs_umap = um.fit_transform(scaled_specs)
plt.figure(figsize=(8,8))
plt.scatter(scaled_specs_umap[:,0], scaled_specs_umap[:,1]);
plt.title('UMAP-reduced Eta Carinae RXTE Spectra');
plt.axis('off');
```

### 4.5 Clustering the Data
`PCA` only represents distance between the high dimensional samples whereas `TSNE` can find local groupings.

`UMAP` combines the two into a more intelligent representation that understands both local and global distance.
Let's cluster the `UMAP` representation using `DBSCAN` ...

```python
dbs = DBSCAN(eps=.6, min_samples=2)
clusters = dbs.fit(scaled_specs_umap)
labels = np.unique(clusters.labels_)
plt.figure(figsize=(8,8))
for i in range(len(np.unique(labels[labels>=0]))):
    plt.scatter(scaled_specs_umap[clusters.labels_==i,0],scaled_specs_umap[clusters.labels_==i,1],label='Cluster '+str(i));
plt.legend()
plt.title('Clustered UMAP-reduced Eta Carinae RXTE Spectra');
plt.axis('off');
```

Notice how the `DBSCAN` clustering produced some interesting groupings - we should examine the spectra of each group.
For a less crowded plot of the spectra clusters, plot the mean spectrum of each cluster.
</font>

```python
# Plot the scaled spectra mean
plt.figure(figsize=(10,6))
for i in range(len(np.unique(labels[labels>=0]))):
    plt.plot(xref,scaled_specs[clusters.labels_==i].mean(axis=0),label='Cluster '+str(i))
plt.legend();
plt.xlabel('Energy (keV)');
plt.ylabel('Scaled Normalized Count Rate (C/s)');
plt.title('Scaled Eta Carinae RXTE Spectra Cluster Mean (lin-lin)');

# Plot the unscaled spectra mean
plt.figure(figsize=(10,6))
for i in range(len(np.unique(labels[labels>=0]))):
    plt.plot(xref,specs[clusters.labels_==i].mean(axis=0),label='Cluster '+str(i))
plt.legend();
plt.xlabel('Energy (keV)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('Unscaled Eta Carinae RXTE Spectra Cluster Mean (lin-lin)');

```

### 4.6 Exploring the Spectral Clusters
It appears that the strangest spectra belong to cluster 1 (orange).
How many spectra are in this group?

```python
scaled_specs[clusters.labels_==1].shape[0]
```

So, we can say that this group is not likely an isolated incident caused by an instrument effect
since similar spectra occur in seven different observations.  Let's look at the overall light curve to see where these odd spectra are occuring.


```python
# Sum the count rate across the energy range
specsum = specs.sum(axis=1)

# plot the overall light curve
plt.figure(figsize=(10,6))
plt.scatter(stimes, specsum)
plt.xlabel('Time (s)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('2-9 keV Eta Carinae RXTE Light Curve');


# plot the clustered light curve
plt.figure(figsize=(10,6))
for i in range(len(np.unique(labels[labels>=0]))):
    plt.scatter(stimes[clusters.labels_==i],specsum[clusters.labels_==i],label='Cluster '+str(i),alpha=1-.1*i)
plt.xlabel('Time (s)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('2-9 keV Eta Carinae RXTE Light Curve with Clustered Spectra');
plt.legend();
```

We can see that the orange group occurred near the beginning of the RXTE mission.
Let's take a closer look ...

```python
# plot the clustered light curve
plt.figure(figsize=(10,6))
for i in range(len(np.unique(labels[labels>=0]))):
    plt.scatter(stimes[clusters.labels_==i],specsum[clusters.labels_==i],label='Cluster '+str(i))
plt.xlabel('Time (s)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('2-9 keV Eta Carinae RXTE Light Curve with Clustered Spectra');
plt.legend();
plt.xlim(.6e8,1e8);
```

Indeed, the orange group were the first seven observations of Eta Car from RXTE.
Given that this type of spectra does not repeat again, the earlier hypothesis that these
spectra are not due to an instrument issue will need to be revisted.

Also, given that the blue group also lacks the 2-3 keV noise peak and is only located toward 
the beginning of the mission, it may be the case that the background estimation from 
that period of time differs substantially.

So, what else is interesting?
Cluster 5 (the brown group) occurs exclusively at the overall light curve minima.
Looking again at the unscaled spectra means:

```python
# Plot the unscaled spectra mean
plt.figure(figsize=(10,6))
for i in range(len(np.unique(labels[labels>=0]))):
    plt.plot(xref,specs[clusters.labels_==i].mean(axis=0),label='Cluster '+str(i))
plt.legend();
plt.xlabel('Energy (keV)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('Unscaled Eta Carinae RXTE Spectra Cluster Mean (lin-lin)');
```

<!-- #region -->

We can see that the broad peak associated with the 3-5 keV energy range is completely absent from the brown group.
Since this phenomena is documented at both X-ray minimums from the latter part of the mission (the earlier minimum may be skewed by background estimation as well) we can say that this spectral difference is likely due to a substantial change in the nature of the Eta Carina stellar system at this time.


Also interesting is the green and purple group relationship.  Let's exlude the earlier measurements, where we suspect the background estimation may be wrong, and show the overall light curve again:

<!-- #endregion -->

```python
plt.figure(figsize=(10,6))
for i in range(len(np.unique(labels[labels>=0]))):
    plt.scatter(stimes[clusters.labels_==i],specsum[clusters.labels_==i],label='Cluster '+str(i),alpha=1-.1*i)
plt.xlabel('Time (s)');
plt.ylabel('Normalized Count Rate (C/s)');
plt.title('2-9 keV Eta Carinae RXTE Light Curve with Clustered Spectra');
plt.legend();
plt.xlim(2.1e8,5.8e8);
```


The green group, which has a lower 3-5 keV peak and a slightly higher energy peak in the 6-7 keV range than the purple group,  appears to occur in conjunction with the purple group.  This may indicate the presence of two competing behaviors, or spectral states.


```python

```
