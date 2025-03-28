#!/bin/bash

sample=$1
fastq_dir="data/fastq"
outdir="data/snippy/${sample}"
ref="defaults/GCF_000195955.2_ASM19595v2_genomic.gbff"

# Ensure output directory exists
mkdir -p "$outdir"

# Determine if sample is paired-end or single-end
if [[ -f "${fastq_dir}/${sample}_2.fastq.gz" ]]; then
    # Paired-end
    snippy --outdir "$outdir" \
        --R1 "${fastq_dir}/${sample}_1.fastq.gz" \
        --R2 "${fastq_dir}/${sample}_2.fastq.gz" \
        --ref "$ref" \
        --force
else
    # Single-end
    snippy --outdir "$outdir" \
        --se "${fastq_dir}/${sample}_1.fastq.gz" \
        --ref "$ref" \
        --force
fi
