#!/bin/bash

sample=$1
fastq_dir="data/fastq"
output_dir="data/tbprofiler"

# Ensure output directory exists
mkdir -p "$output_dir"

# Check if paired-end or single-end files exist
fastq1="$fastq_dir/${sample}_1.fastq.gz"
fastq2="$fastq_dir/${sample}_2.fastq.gz"

# Run tb-profiler based on available reads
if [[ -f "$fastq1" && -f "$fastq2" ]]; then
    tb-profiler profile -1 "$fastq1" -2 "$fastq2" -p "$sample" --txt --dir "$output_dir"
elif [[ -f "$fastq1" ]]; then
    tb-profiler profile -1 "$fastq1" -p "$sample" --txt --dir "$output_dir"
else
    echo "Error: No FASTQ files found for $sample" >&2
    exit 1
fi
