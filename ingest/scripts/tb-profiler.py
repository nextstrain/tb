import csv
import subprocess
import os
import concurrent.futures

# Define file paths
input_file = "data/samples_downloaded.tsv"  # Successfully downloaded samples
output_dir = "data/tbprofiler"  # tb-profiler output directory
collate_output_dir = "data/tbprofiler/results"  # Directory for collated results

# Ensure required directories exist, including the 'bam' directory
os.makedirs(output_dir, exist_ok=True)
os.makedirs(collate_output_dir, exist_ok=True)
os.makedirs(os.path.join(output_dir, "bam"), exist_ok=True)
os.makedirs(os.path.join(output_dir, "vcf"), exist_ok=True)
os.makedirs(os.path.join(output_dir, "results"), exist_ok=True)

# Read successfully downloaded sample IDs
samples = []
with open(input_file, "r") as f:
    reader = csv.reader(f, delimiter='\t')
    next(reader)  # Skip header
    for row in reader:
        if row:
            samples.append(row[0].strip())  # Extract SampleID

def run_tbprofiler(sample):
    output_path = os.path.join(output_dir, f"{sample}.results.txt")
    # Skip already completed analyses
    if os.path.exists(output_path):
        print(f"Skipping {sample}: tb-profiler results already exist.")
        return

    print(f"Running tb-profiler for sample: {sample}")
    try:
        subprocess.run(["scripts/tb-profiler_sample.sh", sample], check=True)
    except subprocess.CalledProcessError:
        print(f"Error: tb-profiler failed for {sample}.")

# Parallelize the tb-profiler processing using ThreadPoolExecutor
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    executor.map(run_tbprofiler, samples)

# After all samples are processed, run tb-profiler collate
print("Collating tb-profiler results...")
subprocess.run([
    "tb-profiler", "collate",
    "--prefix", "data/tbprofiler/results/tbprofiler_all",
    "--dir", "data/tbprofiler/results"
], check=True)

print("tb-profiler analysis and collation completed successfully.")
