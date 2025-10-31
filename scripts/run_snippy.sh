#!/bin/bash
set -euo pipefail

sample="$1"
s3_bucket="$2"
snippy_output_path="$3"
fastq_outdir="$4"
reference="$5"
threads="$6"

s3_path="files/workflows/tb/${snippy_output_path}"

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "Error: required command '$1' not found." >&2
    exit 1
  fi
}

require_cmd aws
require_cmd zstd

# Upload a file as .zst to S3, then remove local .zst
upload_zstd() {
  local src="$1"
  local dst_s3="$2"   # without .zst extension

  if [[ ! -f "$src" ]]; then
    echo "Error: file to compress not found: $src" >&2
    exit 1
  fi

  # Compress with zstd using multiple threads
  zstd -f -T"${threads}" -19 "$src" -o "${src}.zst"

  # Upload compressed file
  aws s3 cp "${src}.zst" "${dst_s3}.zst"

  # Remove local .zst after successful upload
  rm -f "${src}.zst"
}

# Verify bucket access
if ! aws s3 ls "s3://${s3_bucket}" > /dev/null 2>&1; then
    echo "Error: Unable to access s3://${s3_bucket}." >&2
    exit 1
fi

# Only download if BOTH expected .zst files exist on S3
if aws s3 ls "s3://${s3_bucket}/${s3_path}/snps.aligned.fa.zst" >/dev/null 2>&1 \
   && aws s3 ls "s3://${s3_bucket}/${s3_path}/snps.vcf.zst" >/dev/null 2>&1; then
    echo "Found snippy results on S3 (.zst). Downloading to ${snippy_output_path} …" >&2
    mkdir -p "$(dirname "${snippy_output_path}")" "${snippy_output_path}"

    # Download and decompress aligned.fa, then remove local .zst
    aws s3 cp "s3://${s3_bucket}/${s3_path}/snps.aligned.fa.zst" "${snippy_output_path}/snps.aligned.fa.zst"
    zstd -d -f "${snippy_output_path}/snps.aligned.fa.zst" -o "${snippy_output_path}/snps.aligned.fa"
    rm -f "${snippy_output_path}/snps.aligned.fa.zst"

    # Download and decompress vcf, then remove local .zst
    aws s3 cp "s3://${s3_bucket}/${s3_path}/snps.vcf.zst" "${snippy_output_path}/snps.vcf.zst"
    zstd -d -f "${snippy_output_path}/snps.vcf.zst" -o "${snippy_output_path}/snps.vcf"
    rm -f "${snippy_output_path}/snps.vcf.zst"

else
    # No compressed results found, run Snippy
    fastq1="${fastq_outdir}/${sample}_1.fastq.gz"
    fastq2="${fastq_outdir}/${sample}_2.fastq.gz"

    if [[ ! -f "$fastq1" ]]; then
        echo "Downloading fastq files…" >&2
        mkdir -p "${fastq_outdir}"

        # Default split-3 behavior: may produce _1.fastq, _2.fastq, and/or ${sample}.fastq
        fasterq-dump "${sample}" -e "${threads}" --outdir "${fastq_outdir}"

        echo "Compressing FASTQ files…" >&2

        # Paired reads (if present)
        if [[ -f "${fastq_outdir}/${sample}_1.fastq" ]]; then
            gzip -f "${fastq_outdir}/${sample}_1.fastq"
        fi
        if [[ -f "${fastq_outdir}/${sample}_2.fastq" ]]; then
            gzip -f "${fastq_outdir}/${sample}_2.fastq"
        fi

        # Single-end case: only ${sample}.fastq exists
        if [[ ! -f "$fastq1" && -f "${fastq_outdir}/${sample}.fastq" ]]; then
            gzip -f "${fastq_outdir}/${sample}.fastq"
            mv "${fastq_outdir}/${sample}.fastq.gz" "${fastq1}"
        fi

        # Sanity check
        if [[ ! -f "${fastq1}" ]]; then
            echo "Error: No usable FASTQ generated for ${sample}." >&2
            ls -l "${fastq_outdir}" || true
            exit 1
        fi
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

    # Compress with zstd before uploading, then remove local .zst
    upload_zstd "${snippy_output_path}/snps.aligned.fa" "s3://${s3_bucket}/${s3_path}/snps.aligned.fa"
    upload_zstd "${snippy_output_path}/snps.vcf"         "s3://${s3_bucket}/${s3_path}/snps.vcf"
fi
