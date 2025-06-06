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

if [ "$(aws s3api list-objects-v2 --bucket "${s3_bucket}" --prefix "$s3_path" --query 'Contents[]')" != "null" ]; then
    echo "Found snippy results on S3. Downloading to ${output_path} …" >&2
    mkdir -p "$(dirname "${output_path}")"
    aws s3 cp "s3://${s3_bucket}/${s3_path}/snps.aligned.fa" "${output_path}/snps.aligned.fa"
    aws s3 cp "s3://${s3_bucket}/${s3_path}/snps.vcf" "${output_path}/snps.vcf"
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

    mkdir -p "${output_path}"
    if [[ -f "$fastq2" ]]; then
        snippy --outdir "${output_path}" --R1 "$fastq1" --R2 "$fastq2" --ref "${reference}" --force
    else
        snippy --outdir "${output_path}" --se "$fastq1" --ref "${reference}" --force
    fi

    aws s3 cp "${output_path}/snps.aligned.fa" "s3://${s3_bucket}/${s3_path}/snps.aligned.fa"
    aws s3 cp "${output_path}/snps.vcf" "s3://${s3_bucket}/${s3_path}/snps.vcf"
fi
