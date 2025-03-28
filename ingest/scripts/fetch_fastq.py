import csv
import subprocess
import os
import concurrent.futures

# Define paths
input_file = "data/metadata_raw.tsv"  # TSV file with sample IDs
output_file = "data/samples_downloaded.tsv"  # Final TSV file listing successful downloads
fastq_dir = "data/fastq"  # Directory where FASTQ files are stored

# Ensure required directories exist
os.makedirs(fastq_dir, exist_ok=True)
os.makedirs("data", exist_ok=True)  # Ensure the "data" directory exists

# Read sample names from the first column (excluding the header)
samples = []
with open(input_file, "r", newline='') as f:
    reader = csv.reader(f, delimiter='\t')
    next(reader)  # Skip header
    for row in reader:
        if row:
            samples.append(row[0].strip())

def process_sample(sample):
    fastq1_path = os.path.join(fastq_dir, f"{sample}_1.fastq.gz")
    if os.path.exists(fastq1_path):
        print(f"Skipping {sample}: FASTQ file already exists.")
        return False  # Not downloaded because file exists.
    
    print(f"Fetching FASTQ for sample: {sample}")
    try:
        subprocess.run(["scripts/fetch_fastq_sample.sh", sample], check=True)
        return True  # Download successful.
    except subprocess.CalledProcessError:
        print(f"Error: Failed to download FASTQ for {sample}.")
        return False

# Parallelize the download process using ThreadPoolExecutor
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    # Map the process_sample function to each sample concurrently.
    results = list(executor.map(process_sample, samples))

# After processing, check which samples have their _1.fastq.gz files present
downloaded_samples = []
for sample in samples:
    fastq1_path = os.path.join(fastq_dir, f"{sample}_1.fastq.gz")
    if os.path.exists(fastq1_path):
        downloaded_samples.append(sample)

# Write the list of successfully downloaded samples to the final TSV file
with open(output_file, "w", newline='') as f:
    writer = csv.writer(f, delimiter='\t', lineterminator='\n')
    writer.writerow(["accession"])  # Header
    for sample in downloaded_samples:
        writer.writerow([sample])

print(f"Download process completed. Successfully downloaded samples are listed in {output_file}.")
