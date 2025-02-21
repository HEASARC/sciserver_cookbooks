---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.16.0
  kernelspec:
    display_name: (xmmsas)
    language: python
    name: conda-env-xmmsas-py
---

# ABC Guide for XMM-Newton -- Fitting an EPIC Spectrum in XSPEC
<hr style="border: 2px solid #fadbac" />

- **Description:** XMM-Newton ABC Guide, Chapter 13.
- **Level:** Beginner
- **Data:** XMM observation of the Lockman Hole (obsid=0123700101)
- **Requirements:** Must be run using the `HEASARCv6.34` image.  Run in the <tt>(xmmsas)</tt> conda environment on Sciserver. You should see <tt>(xmmsas)</tt> at the top right of the notebook. If not, click there and select <tt>(xmmsas)</tt>.
- **Credit:** Ryan Tanner (February 2025)
- **Support:** <a href="https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html">XMM Newton GOF Helpdesk</a>
- **Last verified to run:** 17 February 2025, for SAS v21 and pySAS v1.4.6

<hr style="border: 2px solid #fadbac" />


## Introduction
This tutorial is based on Chapter 13 from the The XMM-Newton ABC Guide prepared by the NASA/GSFC XMM-Newton Guest Observer Facility. This notebook assumes you are at least minimally familiar with pySAS on SciServer (see the [Long pySAS Introduction](./analysis-xmm-long-intro.md "Long pySAS Intro")) and that you have already worked through the Jupyter Notebooks on filtering EPIC data and extracting a spectra from a region ([Part 1](./analysis-xmm-ABC-guide-ch6-p1.ipynb) and [Part 2](./analysis-xmm-ABC-guide-ch6-p2.ipynb)). In this tutorial we will demonstrate how to use PyXSPEC to load a spectra a set up a simple power law model.

#### SAS Tasks to be Used

**None**

#### Useful Links

- [`pysas` Documentation](https://xmm-tools.cosmos.esa.int/external/sas/current/doc/pysas/index.html "pysas Documentation")
- [`pysas` on GitHub](https://github.com/XMMGOF/pysas)
- [Common SAS Threads](https://www.cosmos.esa.int/web/xmm-newton/sas-threads/ "SAS Threads")
- [Users' Guide to the XMM-Newton Science Analysis System (SAS)](https://xmm-tools.cosmos.esa.int/external/xmm_user_support/documentation/sas_usg/USG/SASUSG.html "Users' Guide")
- [The XMM-Newton ABC Guide](https://heasarc.gsfc.nasa.gov/docs/xmm/abc/ "ABC Guide")
- [PyXSPEC Documentation](https://heasarc.gsfc.nasa.gov/xanadu/xspec/python/html/index.html)
- [XMM Newton GOF Helpdesk](https://heasarc.gsfc.nasa.gov/docs/xmm/xmm_helpdesk.html "Helpdesk") - Link to form to contact the GOF Helpdesk.

<div style='color: #333; background: #ffffdf; padding:20px; border: 4px solid #fadbac'>
<b>Running On SciServer:</b><br>
When running this notebook inside SciServer, make sure the HEASARC data drive is mounted when initializing the SciServer compute container. <a href='https://heasarc.gsfc.nasa.gov/docs/sciserver/'>See details here</a>.
<br><br>
<b>Running Outside SciServer:</b><br>
This notebook was designed to run on SciServer, but an equivelent notebook can be found on <a href="https://github.com/XMMGOF/pysas">GitHub</a>. You will need to install the development version of pySAS found on GitHub (<a href="https://github.com/XMMGOF/pysas">pySAS on GitHub</a>). There are installation instructions on GitHub and example notebooks can be found inside the directory named 'documentation'.
<br>
</div>

<div class="alert alert-block alert-warning">
    <b>Warning:</b> By default this notebook will place observation data files in your <tt>scratch</tt> space. The <tt>scratch</tt> space on SciServer will only retain files for 90 days. If you wish to keep the data files for longer move them into your <tt>persistent</tt> directory.
</div>

```python
# pySAS imports
import pysas

# Importing PyXSPEC
import xspec

# Useful imports
import os

# Imports for plotting
from matplotlib.ticker import StrMethodFormatter
import matplotlib.pyplot as plt
from IPython.display import Image
```

```python
obsid = '0123700101'

# To get your user name. Or you can just put your user name in the path for your data.
from SciServer import Authentication as auth
usr = auth.getKeystoneUserWithToken(auth.getToken()).userName

data_dir = os.path.join('/home/idies/workspace/Temporary/',usr,'scratch/xmm_data')
odf = pysas.odfcontrol.ODFobject(obsid,data_dir=data_dir)
```

<div class="alert alert-block alert-warning">
<b>Important:</b> This notebook assumes that you worked through the notebooks for Chapter 6 of the ABC Guide (see <a href="./analysis-xmm-ABC-guide-ch6-p1.ipynb">Part 1</a> and <a href="./analysis-xmm-ABC-guide-ch6-p2.ipynb">Part 2</a>) and that at the end you produced a grouped spectra file named <tt>'mos1_grp.fits'</tt> with links in the header of the FITS file to the ARF, RMF, and background spectra.
</div>

```python
os.chdir(odf.work_dir)
```

This will load the spectrum into XSPEC. We set an energy range appropriate for the data by ignoring bins (or channels) below 0.2 keV and above 6.6 keV. We are left with 18 of the original 20 bins (channels).

```python
grouped_spectra = 'mos1_grp.fits'
s = xspec.Spectrum(grouped_spectra)
s.ignore('0.0-0.2,6.6-**')
```

We now create a power law model and set the photon index to 2.0. We then renormalize the model and refit it.

```python
m = xspec.Model('pow')
m.powerlaw.PhoIndex = 2.0
xspec.Fit.renorm()
xspec.Fit.perform()
```

To create a plot of the spectrum and the model we include a convenient function. It takes as an input the spectrum object created by PyXSPEC. A lot of what goes into this function is for formatting the plot.

(For more advanced users: The function is written so that it returns the `figure` and two `axis` objects created by `Matplotlib`. You can use these to make additional changes to the formatting of the plot.)

```python
def plot_data_model(spectrum,plot_file_name='data_model_plot.png'):
    xspec.Plot.device='/null'
    xspec.Plot.xAxis = 'keV'

    # Pull off data for main plot
    xspec.Plot('data')
    energy = xspec.Plot.x()
    counts = xspec.Plot.y()
    folded = xspec.Plot.model()
    xErrs = xspec.Plot.xErr()
    yErrs = xspec.Plot.yErr()

    # Pull off data for ratio plot
    xspec.Plot('ratio')
    ratio = xspec.Plot.y()
    r_xerror = xspec.Plot.xErr()
    r_yerror = xspec.Plot.yErr()

    # Get bin edges for "stairs" plot
    bin_edges = []
    for i in spectrum.energies: bin_edges.append(i[0])
    bin_edges.append(spectrum.energies[-1][1])

    # Make the figure and two subplots
    fig, (ax0, ax1) = plt.subplots(nrows=2, sharex=True, height_ratios=[2.5, 1],figsize=(9, 7))

    # Main plot
    ax0.errorbar(energy, counts, yerr=yErrs, xerr=xErrs, linestyle='', marker='')
    ax0.stairs(folded,bin_edges, color='r')
    ax0.set_xscale('log')
    ax0.set_yscale('log')
    ax0.set_xlim([bin_edges[0], bin_edges[-1]])
    ax0.tick_params(top=True,axis="x",direction="in",which='both')
    ax0.tick_params(axis="y",direction="in",which='both',right=True)
    ax0.set_ylabel('counts sec$^{-1}$ keV$^{-1}$')
    ax0.set_title('Data and Folded Model')

    # Ratio plot
    ax1.errorbar(energy, ratio, yerr=r_yerror, xerr=r_xerror, linestyle='', marker='')
    ax1.axhline(y=1, color='g')
    ax1.set_xscale('log')
    ax1.tick_params(top=True,axis="x",direction="in",which='both')
    ax1.tick_params(axis="y",direction="in",which='both')
    ax1.xaxis.set_major_formatter(StrMethodFormatter('{x:.1f}'))
    ax1.xaxis.set_minor_formatter(StrMethodFormatter('{x:.1f}'))
    ax1.set_xlabel('Energy (keV)')
    ax1.set_ylabel('Ratio')

    # This puts the plots together with no space in between
    plt.subplots_adjust(hspace=.0)

    # Save plot to file
    fig.savefig(plot_file_name)

    return fig, ax0, ax1
```

Now we display our plot. The points with error bars are our data, the red "stairs" line is the model created in XSPEC. The bottom plot shows the ratio between the data points and the model.

```python
fig, ax0, ax1 = plot_data_model(s)
```

For comparison we will use XSPEC to generate a GIF file with the same plot. This is the type of plot you would get if you used XSPEC from the command line.

```python
xspec.Plot.splashPage = None
xspec.Plot.device = 'spectrum.gif/GIF'
xspec.Plot.xAxis = 'keV'
xspec.Plot('ldata','ratio')
xspec.Plot.device='/null'
```

```python
with open('spectrum.gif','rb') as f:
    display(Image(data=f.read(), format='gif',width=500))
```

Both plots are saved in the `work_dir` with the rest of the data files.

```python
print(odf.work_dir)
```
