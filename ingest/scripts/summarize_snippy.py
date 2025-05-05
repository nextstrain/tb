import os
import sys
from Bio import SeqIO
import argparse

def count_bases(seq):
    return {
        "length": len(seq),
        "aligned": sum(1 for c in seq if c.upper() in "AGCT"),
        "unaligned": seq.count('-'),
        "variant": sum(1 for c in seq if c in "agct"),
        "het": seq.count('n'),
        "masked": seq.count('X'),
        "lowcov": seq.count('N')
    }

def process_fasta(fasta_file, seq_id):
    sequences = {}
    with open(fasta_file, "r") as handle:
        for record in SeqIO.parse(handle, "fasta"):
            sequences[seq_id] = str(record.seq)
    return sequences

def find_files(base_dir, extension):
    files = []
    for root, _, file_list in os.walk(base_dir):
        for file in file_list:
            if file.endswith(extension):
                files.append(os.path.join(root, file))
    return files

def parse_vcf(vcf_file):
    variant_positions = set()
    with open(vcf_file, "r") as f:
        for line in f:
            if line.startswith("#"):
                continue
            columns = line.strip().split("\t")
            if len(columns) > 1:
                variant_positions.add(int(columns[1]))
    return variant_positions

def generate_core_txt(base_dir):
    fasta_files = find_files(base_dir, "snps.aligned.fa")
    vcf_files = {os.path.basename(os.path.dirname(f)): f for f in find_files(base_dir, "snps.vcf")}
    
    sequences = {}
    variants = {}
    
    for fasta_file in fasta_files:
        seq_id = os.path.basename(os.path.dirname(fasta_file))
        sequences.update(process_fasta(fasta_file, seq_id))
        
        if seq_id in vcf_files:
            variants[seq_id] = parse_vcf(vcf_files[seq_id])
        else:
            variants[seq_id] = set()
    
    output_file = os.path.join(base_dir, "snippy_summary_stats.tsv")
    with open(output_file, "w") as out:
        header = "\t".join(["ID", "LENGTH", "ALIGNED", "UNALIGNED", "VARIANT", "HET", "MASKED", "LOWCOV"]) + "\n"
        out.write(header)
        
        for sample_id, seq in sequences.items():
            stats = count_bases(seq)
            variant_count = len(variants.get(sample_id, set()))
            line = "\t".join(map(str, [sample_id, stats["length"], stats["aligned"], stats["unaligned"], variant_count, stats["het"], stats["masked"], stats["lowcov"]])) + "\n"
            out.write(line)
    
    print(f"Generated {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate snippy_summary_stats.tsv from aligned FASTA files and VCF files.")
    parser.add_argument("--base_dir", required=True, help="Base directory containing subdirectories with aligned FASTA and VCF files")
    
    args = parser.parse_args()
    generate_core_txt(args.base_dir)
