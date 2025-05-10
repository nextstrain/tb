#!/bin/bash
set -euo pipefail
set -x  # DEBUGGING

sample="$1"
s3_bucket="$2"
output_path="$3"
outdir="$4"
snippy_outdir="$5"
reference="$6"
threads="$7"

s3_path="files/workflows/tb/${output_path}"

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not available." >&2
    exit 1
fi

if ! aws s3 ls "s3://${s3_bucket}" > /dev/null 2>&1; then
    echo "Error: Unable to access s3://${s3_bucket}." >&2
    exit 1
fi

if [ "$(aws s3api list-objects-v2 --bucket "${s3_bucket}" --prefix "$s3_path" --query 'Contents[]')" != "null" ]; then
    echo "Found snippy results on S3. Downloading to ${output_path} …" >&2
    mkdir -p "$(dirname "${output_path}")"
    aws s3 cp --recursive "s3://${s3_bucket}/$s3_path" "${output_path}"
else
    fastq1="${outdir}/${sample}_1.fastq.gz"
    fastq2="${outdir}/${sample}_2.fastq.gz"

    if [[ ! -f "$fastq1" ]]; then
        echo "Downloading fastq files…" >&2
        mkdir -p "${outdir}"
        parallel-fastq-dump --split-files --gzip \
            --sra-id "${sample}" --threads "${threads}" \
            --outdir "${outdir}"
    fi

    mkdir -p "${output_path}"
    if [[ -f "$fastq2" ]]; then
        snippy --outdir "${output_path}" --R1 "$fastq1" --R2 "$fastq2" --ref "${reference}" --force
    else
        snippy --outdir "${output_path}" --se "$fastq1" --ref "${reference}" --force
    fi

    echo "Uploading results to S3…" >&2
    aws s3 cp --recursive "${output_path}" "s3://${s3_bucket}/$s3_path"
fi
