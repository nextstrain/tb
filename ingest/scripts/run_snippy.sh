#!/bin/bash
set -euo pipefail
set -x  # DEBUGGING

sample="$1"
s3_bucket="$2"
snippy_output_path="$3"
fastq_outdir="$4"
reference="$5"
threads="$6"

# If TMPDIR doesn't exist, use fastq_outdir. This enables this script
# to run on the Fred Hutch cluster, which doesn't allow use of Scratch
# storage with fasterq-dump, and therefore requires files to be
# saved on TMPDIR before being moved to fastq_outdir

if [[ -z "${TMPDIR:-}" || ! -d "$TMPDIR" ]]; then
    echo "TMPDIR not set or doesn't exist. Using fastq_outdir as TMPDIR." >&2
    TMPDIR="$fastq_outdir"
fi

s3_path="files/workflows/tb/${snippy_output_path}"

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not available." >&2
    exit 1
fi

if ! aws s3 ls "s3://${s3_bucket}" > /dev/null 2>&1; then
    echo "Error: Unable to access s3://${s3_bucket}." >&2
    exit 1
fi

if [ "$(aws s3api list-objects-v2 --bucket "${s3_bucket}" --prefix "$s3_path" --query 'Contents[]')" != "null" ]; then
    echo "Found snippy results on S3. Downloading to ${snippy_output_path} …" >&2
    mkdir -p "$(dirname "${snippy_output_path}")" "${snippy_output_path}"
    aws s3 cp "s3://${s3_bucket}/${s3_path}/snps.aligned.fa" "${snippy_output_path}/snps.aligned.fa"
    aws s3 cp "s3://${s3_bucket}/${s3_path}/snps.vcf"         "${snippy_output_path}/snps.vcf"
else
    fastq1="${fastq_outdir}/${sample}_1.fastq.gz"
    fastq2="${fastq_outdir}/${sample}_2.fastq.gz"

    if [[ ! -f "$fastq1" ]]; then
        echo "Downloading fastq files…" >&2
        mkdir -p "${fastq_outdir}"

        # Default split-3 behavior: may produce _1.fastq, _2.fastq, and/or ${sample}.fastq
        fasterq-dump "${sample}" -e "${threads}" --temp "${TMPDIR}" --outdir "${TMPDIR}"

        echo "Compressing & moving FASTQ files…" >&2

        # Paired reads (if present)
        if [[ -f "${TMPDIR}/${sample}_1.fastq" ]]; then
            gzip -f "${TMPDIR}/${sample}_1.fastq"
            mv "${TMPDIR}/${sample}_1.fastq.gz" "${fastq1}"
        fi
        if [[ -f "${TMPDIR}/${sample}_2.fastq" ]]; then
            gzip -f "${TMPDIR}/${sample}_2.fastq"
            mv "${TMPDIR}/${sample}_2.fastq.gz" "${fastq2}"
        fi

        # Single-end case: only ${sample}.fastq exists
        if [[ ! -f "$fastq1" && -f "${TMPDIR}/${sample}.fastq" ]]; then
            gzip -f "${TMPDIR}/${sample}.fastq"
            mv "${TMPDIR}/${sample}.fastq.gz" "${fastq1}"
        fi

        # Sanity check
        if [[ ! -f "${fastq1}" ]]; then
            echo "Error: No usable FASTQ generated for ${sample}." >&2
            ls -l "${TMPDIR}" || true
            exit 1
        fi
        # Note: orphan reads (${sample}.fastq) are intentionally ignored if _1/_2 exist.
    fi

    mkdir -p "${snippy_output_path}"
    if [[ -f "$fastq2" ]]; then
        snippy --outdir "${snippy_output_path}" \
               --R1 "$fastq1" --R2 "$fastq2" \
               --ref "${reference}" --force --cpus "${threads}"
    else
        snippy --outdir "${snippy_output_path}" \
               --se "$fastq1" \
               --ref "${reference}" --force --cpus "${threads}"
    fi

    aws s3 cp "${snippy_output_path}/snps.aligned.fa" "s3://${s3_bucket}/${s3_path}/snps.aligned.fa"
    aws s3 cp "${snippy_output_path}/snps.vcf"         "s3://${s3_bucket}/${s3_path}/snps.vcf"
fi
