#!/bin/bash
set -euo pipefail
set -x  # DEBUGGING

sample="$1"
s3_bucket="$2"
output_path="$3"
outdir="$4"
tb_outdir="$5"
threads="$6"

s3_path="files/workflows/tb/${output_path}"

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not available." >&2
    exit 1
fi

if ! aws s3 ls "s3://${s3_bucket}" > /dev/null 2>&1; then
    echo "Error: Unable to access s3://${s3_bucket}." >&2
    exit 1
fi

if aws s3api head-object --bucket "${s3_bucket}" --key "$s3_path" > /dev/null 2>&1; then
    echo "Found tb-profiler results on S3. Downloading to ${output_path} …" >&2
    mkdir -p $(dirname "${output_path}")
    aws s3 cp "s3://${s3_bucket}/$s3_path" "${output_path}"
else
    fastq1="${outdir}/${sample}_1.fastq.gz"
    fastq2="${outdir}/${sample}_2.fastq.gz"

    if [[ ! -f "$fastq1" ]]; then
        echo "Downloading fastq files…" >&2
        mkdir -p "${outdir}"  # <-- ADDED SAFEGUARD
        parallel-fastq-dump --split-files --gzip \
            --sra-id "${sample}" --threads "${threads}" \
            --outdir "${outdir}"
    fi

    mkdir -p "${tb_outdir}"
    if [[ -f "$fastq2" ]]; then
        tb-profiler profile -1 "$fastq1" -2 "$fastq2" -p "${sample}" --txt --dir "${tb_outdir}"
    else
        tb-profiler profile -1 "$fastq1" -p "${sample}" --txt --dir "${tb_outdir}"
    fi

    echo "Uploading results to S3…" >&2
    aws s3 cp "${output_path}" "s3://${s3_bucket}/$s3_path"
fi
