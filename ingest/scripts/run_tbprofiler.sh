#!/bin/bash
set -euo pipefail
set -x  # DEBUGGING

sample="$1"
s3_bucket="$2"
tb_output_path="$3"
fastq_outdir="$4"
tb_outdir="$5"
threads="$6"

# If TMPDIR doesn't exist, use fastq_outdir. This enables this script
# to run on the Fred Hutch cluster, which doesn't allow use of Scratch
# storage with fasterq-dump, and therefore requires files to be
# saved on TMPDIR before being moved to fastq_outdir
if [[ -z "${TMPDIR:-}" || ! -d "$TMPDIR" ]]; then
    echo "TMPDIR not set or doesn't exist. Using fastq_outdir as TMPDIR." >&2
    TMPDIR="$fastq_outdir"
fi

s3_path="files/workflows/tb/${tb_output_path}"  # S3 key for the (compressed) tb-profiler output

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "Error: required command '$1' not found." >&2
    exit 1
  fi
}

# Fail-fast dependency checks
require_cmd aws
require_cmd zstd

# Verify bucket access
if ! aws s3 ls "s3://${s3_bucket}" > /dev/null 2>&1; then
    echo "Error: Unable to access s3://${s3_bucket}." >&2
    exit 1
fi

# Only download if expected .zst files exist
if aws s3 ls "s3://${s3_bucket}/${s3_path}.zst" >/dev/null 2>&1; then
    echo "Found tb-profiler results on S3 (.zst). Downloading to ${tb_output_path} …" >&2
    mkdir -p "$(dirname "${tb_output_path}")"

    aws s3 cp "s3://${s3_bucket}/${s3_path}.zst" "${tb_output_path}.zst"
    zstd -d -f "${tb_output_path}.zst" -o "${tb_output_path}"
    rm -f "${tb_output_path}.zst"

    # No compressed results found, run tbprofiler
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

    mkdir -p "${tb_outdir}"
    if [[ -f "$fastq2" ]]; then
        tb-profiler profile -1 "$fastq1" -2 "$fastq2" -p "${sample}" --txt --dir "${tb_outdir}" --threads "${threads}"
    else
        tb-profiler profile -1 "$fastq1" -p "${sample}" --txt --dir "${tb_outdir}" --threads "${threads}"
    fi

    echo "Uploading compressed tb-profiler result to S3…" >&2
    # Compress -> upload -> remove local .zst (leave plain file locally)
    zstd -f -T"${threads}" -19 "${tb_output_path}" -o "${tb_output_path}.zst"
    aws s3 cp "${tb_output_path}.zst" "s3://${s3_bucket}/${s3_path}.zst"
    rm -f "${tb_output_path}.zst"
fi
