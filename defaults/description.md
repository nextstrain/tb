We gratefully acknowledge the authors, originating and submitting laboratories of the genetic sequences and metadata for sharing their work. Please note that although data generators have generously shared data in an open fashion, that does not mean there should be free license to publish on this data. Data generators should be cited where possible and collaborations should be sought in some circumstances. Please try to avoid scooping someone else's work. Reach out if uncertain.

#### Analysis
Our bioinformatic processing workflow can be found at [github.com/nextstrain/tb](https://github.com/nextstrain/tb) and includes:
- Fetch metadata for *M. tuberculosis* samples with Illumina shotgun sequence data from [NCBI SRA](https://www.ncbi.nlm.nih.gov/sra) using [DuckDB CLI](https://duckdb.org/docs/stable/clients/cli/overview.html)
- Subsample the metadata across time and geography
- Download fastq files for subsampled metadata from NCBI SRA using [fasterq-dump](https://github.com/ncbi/sra-tools/wiki/HowTo:-fasterq-dump)
- Assign lineages and identify drug resistance variants for each sample using [tb-profiler](https://github.com/jodyphelan/TBProfiler)
- Create a multi-sample fasta alignment using [snippy](https://github.com/tseemann/snippy) with low-confidence regions masked following [Marin et al. 2022](https://academic.oup.com/bioinformatics/article/38/7/1781/6502279)
- Create a multi-sample VCF of informative sites using a custom script
- Perform phylogenetic reconstruction using [IQTREE](http://www.iqtree.org/)

---

Screenshots may be used under a [CC-BY-4.0 license](https://creativecommons.org/licenses/by/4.0/) and attribution to nextstrain.org must be provided.
