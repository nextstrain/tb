# tb analysis: using input fastq files from NCBI SRA
This repo includes three workflows:

* ingest
	* Fetches fastq files from [NCBI SRA](https://www.ncbi.nlm.nih.gov/sra) (does not fetch metadata)
	* Creates a multi-sequence fasta alignment and vcf file using [snippy](https://github.com/tseemann/snippy) 
	* Identifies drug resistance variants for each assembly using [tb-profiler](https://github.com/jodyphelan/TBProfiler), and adds that info to the metadata file
* phylogenetic_fasta: Performs phylogenetic analysis starting from a multi-sequence fasta alignment 
* phylogenetic_vcf: Performs phylogenetic analysis starting from a multi-sequence vcf file


## Usage: ingest workflow
Required input files:
* `ingest/defaults/samplelist.tsv`: List of SRA accessions to be downloaded and analyzed.
* `ingest/defaults/metadata.tsv`: Metadata for each sample.

Example input files for 5 samples are provided in `ingest/example_data`

Running the workflow:
```
cd ingest
snakemake --cores 1 --use-conda --conda-frontend conda
```

## Usage: phylogenetic_fasta workflow
Required input files:
* `phylogenetic_fasta/data/clean.full.aln`
* `phylogenetic_fasta/data/metadata.tsv`

Running the workflow:
```
cd phylogenetic_fasta
nextstrain build .
```

## Usage: phylogenetic_vcf workflow
Required input files:
* `phylogenetic_vcf/data/all.vcf.gz`
* `phylogenetic_vcf/data/metadata.tsv`

Running the workflow:
```
cd phylogenetic_vcf
nextstrain build .
```

## Example output 

Example output from running phylogenetic analysis with 71 samples can be found here:
* [phylgenetic_fasta output](https://nextstrain.org/staging/tb/fastqs/aln)
* [phylogenetic_vcf output](https://nextstrain.org/staging/tb/fastqs/vcf)
