from Bio import SeqIO
import sys
from collections import defaultdict

counts = {
    "total_sites": 0,
    "skipped_no_alts": 0,
    "skipped_only_missing_data_alts": 0,
    "biallic": 0,
    "in_vcf": 0,
}

ATGC = set(['A', 'T', 'C', 'G'])

def write_vcf(reference_seq, sample_seqs, sample_ids, output_file):
    with open(output_file, "w") as vcf:
        chrom = "FASTA"

        # Write VCF header
        vcf.write("##fileformat=VCFv4.2\n")
        vcf.write("##source=fasta_to_vcf_biopython\n")
        vcf.write(f"##contig=<ID={chrom},length={len(reference_seq)}>\n")
        vcf.write("##INFO=<ID=AA,Number=1,Type=String,Description=\"Ancestral Allele\">\n")
        vcf.write("##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n")
        vcf.write("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t" + "\t".join(sample_ids) + "\n")

        for i in range(len(reference_seq)):
            ref_base = reference_seq[i]
            alt_bases = defaultdict(int)
            alt_set = set()
            genotypes = []

            counts['total_sites'] += 1

            for seq in sample_seqs:
                sample_base = seq[i].upper()
                if sample_base not in ATGC:
                    sample_base = 'N'

                if sample_base == ref_base:
                    genotypes.append(ref_base)
                else:
                    alt_bases[sample_base] += 1
                    alt_set.add(sample_base)
                    genotypes.append(sample_base)

            if len(alt_set) == 0:
                counts['skipped_no_alts'] += 1
                continue
            elif len(alt_set) == 1 and 'N' in alt_set:
                counts['skipped_only_missing_data_alts'] += 1
                continue

            counts['in_vcf'] += 1

            alt_list = list(alt_set - {'N'})
            if len(alt_list) == 1:
                counts['biallic'] += 1

            formatted_genotypes = []
            for gt in genotypes:
                if gt == ref_base:
                    formatted_genotypes.append("0")
                elif gt == 'N':
                    formatted_genotypes.append(".")
                else:
                    formatted_genotypes.append(str(alt_list.index(gt) + 1))

            info = f"AA={ref_base}"

            vcf.write(f"{chrom}\t{i + 1}\t.\t{ref_base}\t{','.join(alt_list)}\t.\t.\t{info}\tGT\t" + "\t".join(formatted_genotypes) + "\n")

def main(ref_fasta, aln_fasta, output_vcf):
    ref_record = next(SeqIO.parse(ref_fasta, "fasta"))
    reference_seq = str(ref_record.seq).upper()

    sample_records = list(SeqIO.parse(aln_fasta, "fasta"))
    sample_ids = [rec.id for rec in sample_records]
    sample_seqs = [str(rec.seq).upper() for rec in sample_records]

    aln_len = len(reference_seq)
    for s in sample_seqs:
        if len(s) != aln_len:
            print(f"Error: All sequences (including reference) must be the same length - {len(s)} vs {aln_len}")
            sys.exit(1)

    write_vcf(reference_seq, sample_seqs, sample_ids, output_vcf)
    print("\ncounts", counts)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python fasta_to_vcf.py reference.fasta alignment.fasta output.vcf")
        sys.exit(1)

    main(sys.argv[1], sys.argv[2], sys.argv[3])
