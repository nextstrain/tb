# tb analysis: using input genome assemblies from the BV-BRC
This repo includes an ingest workflow which performs the following steps:
* Fetches fastq files from [BV-BRC](https://www.bv-brc.org/)
* Creates a multi-sequence fasta alignment and vcf file using [snippy](https://github.com/tseemann/snippy) 
* Identifies drug resistance variants for each assembly using [tb-profiler](https://github.com/jodyphelan/TBProfiler), and adds that info to the metadata file

The output of this workflow can be used for downstream phylogenetic analysis (not included here).


## Usage
Required input file:
* `ingest/defaults/samplelist_assemblies.tsv`: List of BV-BRC accessions to be analyzed. An example file with 5 assemblies is provided in the repo. 

Running the workflow:
```
cd ingest
snakemake --cores 1 --use-conda --conda-frontend conda
```

## Example output 

Example output from running phylogenetic analysis with 71 samples can be found here:
* [phylgenetic_fasta output](https://nextstrain.org/staging/tb/assemblies/aln)
* [phylogenetic_vcf output](https://nextstrain.org/staging/tb/assemblies/vcf)
