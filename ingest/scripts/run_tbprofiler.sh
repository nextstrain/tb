#!/bin/bash
set -euo pipefail
set -x  # DEBUGGING

sample="$1"
s3_bucket="$2"
output_path="$3"
outdir="$4"
tb_outdir="$5"
threads="$6"

# If TMPDIR doesn't exist, use tb_outdir. This enables this script
# to run on the Fred Hutch cluster, which doesn't allow use of Scratch
# storage with fasterq-dump, and therefore requires files to be
# saved on TMPDIR before being moved to tb_outdir

if [[ -z "${TMPDIR:-}" || ! -d "$TMPDIR" ]]; then
    echo "TMPDIR not set or doesn't exist. Using tb_outdir as TMPDIR." >&2
    TMPDIR="$tb_outdir"
fi

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
        fasterq-dump "${sample}" -e "${threads}" --temp "${TMPDIR}" --outdir "${TMPDIR}"
        
        echo "Compressing FASTQ files…" >&2
        gzip "${TMPDIR}/${sample}_1.fastq"
        if [[ -f "${TMPDIR}/${sample}_2.fastq" ]]; then
            gzip "${TMPDIR}/${sample}_2.fastq"
        fi
    
        echo "Moving compressed FASTQ files to ${outdir}…" >&2
        mv "${TMPDIR}/${sample}_1.fastq.gz" "${fastq1}"
        if [[ -f "${TMPDIR}/${sample}_2.fastq.gz" ]]; then
            mv "${TMPDIR}/${sample}_2.fastq.gz" "${fastq2}"
        fi
        
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
