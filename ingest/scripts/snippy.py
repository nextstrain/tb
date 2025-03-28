import csv
import subprocess
import os
import concurrent.futures
import sys

samples_file = "data/samples_downloaded.tsv"
snippy_dir = "data/snippy"
summary_script = "scripts/summarize_snippy.py"

# Read sample list, skipping the header
with open(samples_file, "r") as f:
    reader = csv.reader(f, delimiter='\t')
    next(reader)  # Skip header
    samples = [row[0].strip() for row in reader if row]

def process_sample(sample):
    sample_outdir = os.path.join(snippy_dir, sample)
    snps_path = os.path.join(sample_outdir, "snps.vcf")
    if os.path.exists(snps_path):
        print(f"Skipping {sample}: snippy output already exists.")
        return
    print(f"Running snippy for sample: {sample}")
    try:
        subprocess.run(["scripts/snippy_sample.sh", sample], check=True)
    except subprocess.CalledProcessError:
        print(f"Error running snippy for sample: {sample}")

# Parallelize snippy processing using ThreadPoolExecutor
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    executor.map(process_sample, samples)

# Run summarization
print("Running summarize_snippy.py...")
subprocess.run([sys.executable, summary_script, "--base_dir", snippy_dir], check=True)

print("Snippy analysis and summary complete.")
