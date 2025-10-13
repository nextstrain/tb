# Nextstrain workflow for VCF input tutorial

This repository provides the data and scripts associated with the tutorial for [creating a phylogenetic workflow with VCF input](https://docs.nextstrain.org/en/latest/tutorials/creating-a-phylogenetic-workflow-with-VCF-input.html). The tutorial uses *Mycobacterium tuberculosis* sequences as an example. 

The workflow encompasses preparing data for analysis, doing quality control, performing analyses, and saving the results in a format suitable for visualization (with [auspice](https://github.com/nextstrain/auspice)). 
This involves running components of Nextstrain such as [augur](https://github.com/nextstrain/augur) and [auspice](https://github.com/nextstrain/auspice).

## Installation

Follow the [standard installation instructions](https://docs.nextstrain.org/en/latest/install.html) for Nextstrain's suite of software tools.

## Quickstart

Run the default workflow via:
```
nextstrain build .
nextstrain view .
```

## Documentation

- [Running a pathogen workflow](https://docs.nextstrain.org/en/latest/tutorials/running-a-workflow.html)
- [Contributor documentation](./CONTRIBUTING.md)
