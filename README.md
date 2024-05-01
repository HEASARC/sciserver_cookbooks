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

This directory is a place to collect helpful Jupyter notebooks specifically
designed for HEASARC@SciServer. For a general introduction of the notebooks,
see [the introduction notebook](introduction.md)


Community feedback and contribution are welcomed and encouraged!
Contributed notbeooks will be reviewed by HEASARC scientists and added
to the collection. If you plan to contribute,
please follow the general format shown in the [template file](_files/template.md)

The tutorials are in `markdown` format, and need `jupytext` to run them.
On Sciserver, this is included in the `heasoft` conda environment.
If you want to run the notebooks elsewhere, make sure `jupytext` is installed
with `pip install jupytext` before starting `jupyterlab`.

Once `jupytext` is installed, the markdown notebooks can be used like
classical `ipynb` notebooks. The markdown format can be converted to the
classical format by running:

```sh
jupytext --to notebook markdown-file.md
```
