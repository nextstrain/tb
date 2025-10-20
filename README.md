# Nextstrain repository for *Mycobacterium tuberculosis*
This workflow performs the following analysis:

* Fetches metadata for *M. tuberculosis* samples with Illumina shotgun sequence data from [NCBI SRA](https://www.ncbi.nlm.nih.gov/sra) using [DuckDB CLI](https://duckdb.org/docs/stable/clients/cli/overview.html)
* Subsamples the metadata across time and geography
* Downloads fastq files for subsampled metadata from NCBI SRA using [fasterq-dump](https://github.com/ncbi/sra-tools/wiki/HowTo:-fasterq-dump)
* Assigns lineages and identifies drug resistance variants for each sample using [tb-profiler](https://github.com/jodyphelan/TBProfiler)
* Creates a multi-sample fasta alignment using [snippy](https://github.com/tseemann/snippy) with low-confidence regions masked following [Marin et al. 2022](https://academic.oup.com/bioinformatics/article/38/7/1781/6502279)
* Creates a multi-sample VCF of informative sites using a custom script
* Performs phylogenetic reconstruction using [IQTREE](http://www.iqtree.org/)

The results of running this workflow are publicly visible at [nextstrain.org/tb/global](https://nextstrain.org/tb/global).

## Installation

This workflow requires installation of the [Nextstrain CLI](https://docs.nextstrain.org/en/latest/install.html#install-nextstrain-cli) and [Docker](https://www.docker.com/).


## Usage:

> NOTE: Running this workflow will most likely require more compute resources than what is available on your local computer.

```
nextstrain build --image ghcr.io/nextstrain/tb:latest .
```

## Storing tbprofiler and snippy results
For SRA samples that have already been analyzed in previous runs of this workflow, results of tb-profiler and snippy analyses are stored in an S3 bucket:
### tb-profiler
* `s3://nextstrain-data/files/workflows/tb/data/tbprofiler/results/{sample}.results.json.zst`
### snippy 
* `s3://nextstrain-data/files/workflows/tb/data/snippy/{sample}/snps.aligned.fa.zst`
* `s3://nextstrain-data/files/workflows/tb/data/snippy/{sample}/snps.vcf.zst`

These results files should be deleted from the S3 bucket if changes are made to the workflow that would influence the files, such as changes to the parameters used in the tb-profiler or snippy analysis steps, updates to the tb-profiler or snippy installations, or addition of new sequence quality filtering steps prior to running tb-profiler or snippy.

## Repo history
The current Nextstrain github repo differs substantially from the original version of the repo.

The original version was created to perform phylogenetic analyses for a subset of the data from [Lee et al. 2015](https://www.pnas.org/doi/10.1073/pnas.1507071112), but with geographic location randomized for each sample. The code and VCF file for that workflow are still available [in a separate github repo](https://github.com/nextstrain/vcf-input-tutorial). That repo is used in the [Nextstrain tutorial for creating a phylogenetic workflow with VCF input](https://docs.nextstrain.org/en/latest/tutorials/creating-a-phylogenetic-workflow-with-VCF-input.html).

In addition, a phylogenetic tree was previously available at `nextstrain.org/tb/global` that was generated using a separate workflow and a different dataset which included global tb sequences. The code for that analysis is no longer available, but the tree is still [available on Nextstrain.org](https://nextstrain.org/tb/global@2018-10-03).

One of the main differences of the current workflow compared to the original workflow is that it starts from raw sequence data from the NCBI SRA rather than starting from a VCF file. This necessitates extra steps in the workflow, including:
* Ingest sequence data from NCBI SRA
* Perform genotyping using snippy
* Create a VCF file for phylogenetic analysis

Other major differences include:
* Assign lineages and identify drug resistance variants using tb-profiler
* Automate all analyses to enable continually updated global genomic surveillance
