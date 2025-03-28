#!/bin/bash

sample=$1
output_dir="data/fastq"

# Ensure the output directory exists
mkdir -p "$output_dir"

# Run parallel-fastq-dump
parallel-fastq-dump --split-files --gzip --sra-id "$sample" --threads 4 --outdir "$output_dir"

# Check if at least the _1.fastq.gz file exists (sufficient for both single- and paired-end cases)
if [[ -f "$output_dir/${sample}_1.fastq.gz" ]]; then
    exit 0
else
    echo "Error: FASTQ file _1.fastq.gz not found for $sample" >&2
    exit 1
fi
