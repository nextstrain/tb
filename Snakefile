"""
Fetch metadata from NCBI SRA, filter and subsample, 
fetch fastq files, run snippy & tbprofiler,
run phylogenetic workflow

"""
# The workflow filepaths are written relative to this Snakefile's base directory
workdir: workflow.current_basedir

configfile: "defaults/config.yaml"

rule all:
    input:
        auspice_json = "auspice/tb_global.json",
        tip_frequencies_json="auspice/tb_global_tip-frequencies.json",

rule fetch_sra:
    output:
        metadata_raw = "data/metadata_raw.tsv"
    params:
        query = "scripts/query.sql"
    log:
        "logs/fetch_sra.txt",
    benchmark:
        "benchmarks/fetch_sra.txt"
    shell:
        """
        exec &> >(tee {log:q})

        eval "$(conda shell.bash hook)"
        conda activate duckdb
        duckdb -f {params.query} >{output.metadata_raw}
        """

def format_field_map(field_map: dict[str, str]) -> str:
    """
    Format dict to `"key1"="value1" "key2"="value2"...` for use in shell commands.
    """
    return " ".join([f'"{key}"="{value}"' for key, value in field_map.items()])

rule curate:
    input:
        metadata_raw = "data/metadata_raw.tsv",
        annotations=config["curate"]["annotations"],
    output:
        metadata_curate = "data/metadata_curate.tsv"
    log:
        "logs/curate.txt"
    benchmark:
        "benchmarks/curate.txt"
    params:
        field_map=format_field_map(config["curate"]["field_map"]),
        strain_regex=config["curate"]["strain_regex"],
        strain_backup_fields=config["curate"]["strain_backup_fields"],
        date_fields=config["curate"]["date_fields"],
        expected_date_formats=config["curate"]["expected_date_formats"],
        articles=config["curate"]["titlecase"]["articles"],
        abbreviations=config["curate"]["titlecase"]["abbreviations"],
        titlecase_fields=config["curate"]["titlecase"]["fields"],
        annotations_id=config["curate"]["annotations_id"],
        id_field=config["curate"]["output_id_field"],
    shell:
        """
        exec &> >(tee {log:q})

        augur curate passthru \
            --metadata {input.metadata_raw} \
            | augur curate rename \
                --field-map {params.field_map} \
            | augur curate normalize-strings \
            | augur curate transform-strain-name \
                --strain-regex {params.strain_regex} \
                --backup-fields {params.strain_backup_fields} \
            | augur curate format-dates \
                --date-fields {params.date_fields} \
                --expected-date-formats {params.expected_date_formats} \
                --failure-reporting silent \
            | augur curate titlecase \
                --titlecase-fields {params.titlecase_fields} \
                --articles {params.articles} \
                --abbreviations {params.abbreviations} \
            | augur curate apply-record-annotations \
                --annotations {input.annotations} \
                --id-field {params.annotations_id} \
                --output-metadata {output.metadata_curate}
        """

checkpoint filter_subsample:
    input:
        metadata_curate = "data/metadata_curate.tsv"
    output:
        metadata_subsample = "data/metadata_subsample.tsv"
    log:
        "logs/filter_subsample.txt",
    benchmark:
        "benchmarks/filter_subsample.txt"
    shell:
        """
        exec &> >(tee {log:q})

        augur filter \
            --metadata {input.metadata_curate} \
            --metadata-id-columns accession \
            --query "(mbases > 180 & mbases < 1500 & (country != 'Uncalculated'))" \
	        --group-by country year \
	        --sequences-per-group 1 \
	        --min-date 1990 \
	        --output-metadata {output.metadata_subsample}
        """

# This rule removes output files that are not needed in subsequent rules.
# If fastq files are downloaded, they will not be deleted so that
# snippy can use them (and then delete them).
rule run_tbprofiler:
    output:
        touch("data/tbprofiler/flags/{sample}_flag.txt"),
    params:
        s3_bucket=config["s3_bucket"],
        tb_output_path="data/tbprofiler/results/{sample}.results.json",
        fastq_outdir="data/fastq",
        tb_outdir="data/tbprofiler",
    threads: 4
    log:
        "logs/tbprofiler_{sample}.txt",
    benchmark:
        "benchmarks/tbprofiler_{sample}.txt",
    shell:
        r'''
        exec &> >(tee {log:q})

        eval "$(conda shell.bash hook)"
        conda activate tb-profiler
        scripts/run_tbprofiler.sh {wildcards.sample} \
        {params.tb_output_path} \
        {params.fastq_outdir} \
        {params.tb_outdir} \
        {threads} \
        {params.s3_bucket} \
        || echo "tbprofiler failed at sample {wildcards.sample}"
        rm -f data/tbprofiler/bam/{wildcards.sample}.bam*
        rm -f data/tbprofiler/vcf/{wildcards.sample}.targets.vcf.gz
        '''

# Ensures that tbprofiler_collate doesn't run until all samples have been processed by tbprofiler
def get_tbprofiler_flag_paths(wildcards):
    subsample_output = checkpoints.filter_subsample.get(**wildcards).output.metadata_subsample
    samples = []
    with open(subsample_output, "r") as f:
        next(f)  # skip header
        for line in f:
            samples.append(line.strip().split("\t")[0])
    return expand("data/tbprofiler/flags/{sample}_flag.txt", sample=samples)

rule tbprofiler_collate:
    input:
        get_tbprofiler_flag_paths
    output:
        "data/tbprofiler/results/tbprofiler_all.txt"
    params:
        prefix="data/tbprofiler/results/tbprofiler_all",
        dir="data/tbprofiler/results"
    log:
        "logs/tbprofiler_collate.txt"
    benchmark:
        "benchmarks/tbprofiler_collate.txt"
    shell:
        """
        exec &> >(tee {log:q})

        eval "$(conda shell.bash hook)"
        conda activate tb-profiler
        tb-profiler collate \
        --prefix {params.prefix} \
        --dir {params.dir}
        """

# Ensures that snippy doesn't start running on a given sample until run_tbprofiler has completed 
# for that sample, so that it doesn't start running on incompletely downloaded fastq files.
# Also, deletes intermediate and unnecessary files after snippy is completed.
# Setting `priority: 1000` makes the rule run_snippy be preferred by the scheduler over other rules that
# are ready to execute at the same time. This ensures that the workflow
# doesn't wait for ALL samples to be run through tbprofiler before starting snippy on 
# individual samples; otherwise large intermediate files would accumulate for each sample and
# take up large amounts of storage space.
def tbprofiler_flag(wildcards):
    return f"data/tbprofiler/flags/{wildcards.sample}_flag.txt"

rule run_snippy:
    input:
        tbprofiler_flag,
    output:
        touch("data/snippy/flags/{sample}_flag.txt"),
    priority: 1000
    params:
        s3_bucket=config["s3_bucket"],
        snippy_output_path="data/snippy/{sample}",
        fastq_outdir="data/fastq",
        reference=config["files"]["reference_genbank"],
    threads: 4
    log:
        "logs/snippy_{sample}.txt",
    benchmark:
        "benchmarks/snippy_{sample}.txt",
    shell:
        r'''
        exec &> >(tee {log:q})

        eval "$(conda shell.bash hook)"
        conda activate snippy
        scripts/run_snippy.sh {wildcards.sample} \
        {params.snippy_output_path} \
        {params.fastq_outdir} \
        {params.reference} \
        {threads} \
        {params.s3_bucket} \
        || echo "snippy failed at sample {wildcards.sample}"
        rm -f data/fastq/{wildcards.sample}_*.fastq.gz
        rm -fr data/snippy/{wildcards.sample}/reference
        rm -f data/snippy/{wildcards.sample}/ref.fa
        rm -f data/snippy/{wildcards.sample}/snps.b*
        rm -f data/snippy/{wildcards.sample}/snps.c*
        rm -f data/snippy/{wildcards.sample}/snps.filt.vcf
        rm -f data/snippy/{wildcards.sample}/snps.gff
        rm -f data/snippy/{wildcards.sample}/snps.html
        rm -f data/snippy/{wildcards.sample}/snps.log
        rm -f data/snippy/{wildcards.sample}/snps.raw.vcf
        rm -f data/snippy/{wildcards.sample}/snps.subs.vcf
        rm -f data/snippy/{wildcards.sample}/snps.t*
        rm -f data/snippy/{wildcards.sample}/snps.vcf.gz*
        '''

# Ensures that snippy_qc doesn't run until all samples have been processed by snippy
def get_snippy_flag_paths(wildcards):
    subsample_output = checkpoints.filter_subsample.get(**wildcards).output.metadata_subsample
    samples = []
    with open(subsample_output, "r") as f:
        next(f)  # skip header
        for line in f:
            samples.append(line.strip().split("\t")[0])
    return expand("data/snippy/flags/{sample}_flag.txt", sample=samples)

# Calculate & collate quality control statistics from snippy alignment
# so that we can remove low quality samples that could cause 
# rule combine_align to fail by causing the core genome to have no SNPs
rule snippy_qc:
    input:
        get_snippy_flag_paths
    output:
        snippy_summary="data/snippy/snippy_summary_stats.tsv"
    log:
        "logs/snippy_qc.txt"
    benchmark:
        "benchmarks/snippy_qc.txt"
    shell:
        """
        exec &> >(tee {log:q})

        python scripts/summarize_snippy.py \
        --base_dir data/snippy
        """

# This is an inner join so that samples that failed tbprofiler or snippy 
# are excluded from the metadata_stats.tsv output.
# Note that augur merge doesn't do inner joins.
# Note that tbprofiler_all.txt has Windows line endings, and tsv-utils
# can't handle those.
rule merge_metadata:
    input:
        metadata_subsample = "data/metadata_subsample.tsv",
        tbprofiler_output="data/tbprofiler/results/tbprofiler_all.txt",
        snippy_summary="data/snippy/snippy_summary_stats.tsv"
    output:
        metadata_stats="data/metadata_stats.tsv",
    log:
        "logs/merge_metadata.txt",
    benchmark:
        "benchmarks/merge_metadata.txt"
    shell:
        """
        exec &> >(tee {log:q})

        csvtk join -t -f 1 {input.metadata_subsample} \
        {input.snippy_summary} \
        {input.tbprofiler_output} \
        > {output.metadata_stats}
        """

# Filter out poor-quality samples and samples that are M. canetti.
checkpoint filter_qc:
    input:
        metadata_stats="data/metadata_stats.tsv",
    output:
        metadata_filtered="data/metadata_filtered.tsv",
    log:
        "logs/filter_qc.txt"
    benchmark:
        "benchmarks/filter_qc.txt"
    shell:
        """
        exec &> >(tee {log:q})

        tsv-filter --header --gt  pct_reads_mapped:80 {input.metadata_stats} \
        | tsv-filter --header --gt  target_median_depth:30 \
        | tsv-filter --header --gt  ALIGNED:3529226 \
        | tsv-filter --header --str-eq main_lineage:M.canetti  --invert \
        | tsv-filter --header --str-not-in-fld main_lineage:';' \
        > {output.metadata_filtered}
        """

# Ensures that only samples that passed all QC are included in the alignment
def get_alignment_samples(wildcards):
    filter_output = checkpoints.filter_qc.get(**wildcards).output.metadata_filtered
    samples = []
    with open(filter_output, "r") as f:
        next(f)  # skip header
        for line in f:
            samples.append(line.strip().split("\t")[0])
    return expand("data/snippy/flags/{sample}_flag.txt", sample=samples)

# Input sample names are taken from metadata_filtered.tsv
# Note that we had to manually change the chromosome name in the reference 
# genome from "NC_000962.3" to "NC_000962" because that is the chromosome 
# name in the gbff file that snippy used for alignment.
rule combine_align:
    input:
        sample=get_alignment_samples,
        mask_file=config["files"]["mask_file"],
    output:
        alignment="data/snippy/core.full.aln",
        snippy_summary="data/snippy/core.txt"
    params:
        ref=config["files"]["reference_fasta"],
        prefix="data/snippy/core"
    log:
        "logs/snippy_combine_align.txt"
    benchmark:
        "benchmarks/snippy_combine_align.txt"
    shell:
        """
        exec &> >(tee {log:q})

        eval "$(conda shell.bash hook)"
        conda activate snippy
        snippy-core --ref {params.ref} \
        $(for f in {input.sample}; do echo data/snippy/$(basename $f _flag.txt); done) \
        --mask {input.mask_file} \
        --prefix {params.prefix}
        rm -f data/snippy/core.aln
        rm -f data/snippy/core.ref.fa
        rm -f data/snippy/core.tab
        rm -f data/snippy/core.vcf
        """

rule clean_align:
    input:
        alignment="data/snippy/core.full.aln"
    output:
        clean_alignment=temp("results/clean.full.aln"),
    log:
        "logs/snippy_clean_align.txt"
    benchmark:
        "benchmarks/snippy_clean_align.txt"
    shell:
        """
        exec &> >(tee {log:q})

        eval "$(conda shell.bash hook)"        
        conda activate snippy
        snippy-clean_full_aln \
        {input.alignment} \
        > {output.clean_alignment}
        """

rule fasta_to_vcf:
    input:
        clean_alignment="results/clean.full.aln",
        ref=config["files"]["reference_fasta"],
    output:
        informative_vcf="results/all_informative.vcf.gz",
        uncompressed_vcf=temp("results/all_informative.vcf")
    log:
        "logs/fasta_to_vcf.txt"
    benchmark:
        "benchmarks/fasta_to_vcf.txt"
    shell:
        """
        exec &> >(tee {log:q})

        python scripts/fasta_to_vcf.py \
        {input.ref} \
        {input.clean_alignment} \
        {output.uncompressed_vcf}
        gzip -c {output.uncompressed_vcf} > {output.informative_vcf}
        """

# Replace the snippy qc metrics with metrics that take into account masking.
# This is accomplished by overwriting the values in data/metadata_filtered.tsv
# (which don't account for masking) with the values in data/snippy/core.txt
# (which do account for masking).
# The data/snippy/core.txt is an output from rule combine_align and it
# includes a row for the Reference sequence, which ends up in the 
# results/metadata.tsv. The Reference sequence is also present in the 
# clean.full.aln and results/all_informative.vcf.gz, but is excluded
# during the phylo workflow
rule replace_snippyqc:
    input:
        metadata_filtered = "data/metadata_filtered.tsv",
        snippy_summary="data/snippy/core.txt"
    output:
        metadata="results/metadata.tsv",
    log:
        "logs/replace_snippyqc.txt"
    benchmark:
        "benchmarks/replace_snippyqc.txt"
    shell:
        """
        exec &> >(tee {log:q})

        augur merge \
        --metadata filtered={input.metadata_filtered} \
        snippy={input.snippy_summary} \
        --metadata-id-columns 'accession' 'ID' \
        --output-metadata {output.metadata}
        """


# Phylogenetic workflow

rule filter:
    input:
        seq = "results/all_informative.vcf.gz",
        meta = "results/metadata.tsv",
        exclude = config["files"]["exclude"],
    output:
        "results/filtered.vcf.gz"
    log:
        "logs/filter.txt"
    benchmark:
        "benchmarks/filter.txt"
    params:
        strain_id = config["strain_id_field"]
    shell:
        """
        exec &> >(tee {log:q})

        augur filter --sequences {input.seq} \
            --metadata {input.meta} \
            --metadata-id-columns {params.strain_id} \
            --exclude {input.exclude} \
            --output {output}
        """

rule tree:
    input:
        aln = "results/filtered.vcf.gz",
        ref = config["files"]["reference_fasta"],
    output:
        "results/tree_raw.nwk"
    params:
        method = 'iqtree'
    log:
        "logs/tree.txt"
    benchmark:
        "benchmarks/tree.txt"
    shell:
        """
        exec &> >(tee {log:q})

        augur tree --alignment {input.aln} \
            --vcf-reference {input.ref} \
            --method {params.method} \
            --output {output}
        """

rule refine:
    input:
        tree = "results/tree_raw.nwk",
        aln = "results/filtered.vcf.gz",
        meta = "results/metadata.tsv",
        ref = config["files"]["reference_fasta"],
    output:
        tree = "results/tree.nwk",
        node_data = "results/branch_lengths.json",
    log:
        "logs/refine.txt"
    benchmark:
        "benchmarks/refine.txt"
    params:
        root = config["refine"]["root"],
        strain_id = config["strain_id_field"],
        coal = config["refine"]["coal"],
    shell:
        """
        exec &> >(tee {log:q})

        augur refine --tree {input.tree} \
            --alignment {input.aln} \
            --vcf-reference {input.ref} \
            --metadata {input.meta} \
            --metadata-id-columns {params.strain_id} \
            --timetree \
            --coalescent {params.coal} \
            --root {params.root} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data}
        """

rule ancestral:
    input:
        tree = "results/tree.nwk",
        alignment = "results/filtered.vcf.gz",
        ref = config["files"]["reference_fasta"],
    output:
        nt_data = "results/nt_muts.json",
        vcf_out = "results/nt_muts.vcf"
    log:
        "logs/ancestral.txt"
    benchmark:
        "benchmarks/ancestral.txt"
    params:
        inference = "joint"
    shell:
        """
        exec &> >(tee {log:q})

        augur ancestral --tree {input.tree} \
            --alignment {input.alignment} \
            --vcf-reference {input.ref} \
            --inference {params.inference} \
            --output-node-data {output.nt_data} \
            --output-vcf {output.vcf_out}
        """

rule translate:
    input:
        tree = "results/tree.nwk",
        ref = config["files"]["reference_fasta"],
        gene_ref = config["files"]["reference_genbank"],
        vcf = "results/nt_muts.vcf",
    output:
        aa_data = "results/aa_muts.json",
        vcf_out = "results/translations.vcf",
        vcf_ref = "results/translations_reference.fasta"
    log:
        "logs/translate.txt"
    benchmark:
        "benchmarks/translate.txt"
    shell:
        """
        exec &> >(tee {log:q})

        augur translate --tree {input.tree} \
            --vcf-reference {input.ref} \
            --ancestral-sequences {input.vcf} \
            --reference-sequence {input.gene_ref} \
            --output-node-data {output.aa_data} \
            --alignment-output {output.vcf_out} \
            --vcf-reference-output {output.vcf_ref}
        """

rule label_lineages:
    input:
        metadata = "results/metadata.tsv",
        tree = "results/tree.nwk",
    output:
        node_data = "results/lineages.json"
    benchmark:
        "benchmarks/label_lineages.txt"
    log:
        "logs/label_lineages.txt"
    params:
        strain_id = config["strain_id_field"]
    shell:
        r"""
        exec &> >(tee {log:q})

        python scripts/label-lineage-internal-nodes.py \
            --metadata {input.metadata} \
            --tree {input.tree} \
            --id-columns {params.strain_id} \
            --output {output.node_data}
        """

# Remove time from from branch_lengths.json so that a time tree is not created
rule remove_time:
    input:
        "results/branch_lengths.json"
    output:
        "results/branch_lengths_div_only.json"
    log:
        "logs/remove_time.txt"
    benchmark:
        "benchmarks/remove_time.txt"
    run:
        import json
        with open(input[0], 'r') as fh:
            data = json.load(fh)
        new_nodes = {}
        for name, attrs in data['nodes'].items():
            new_nodes[name] = {'mutation_length': attrs.get('mutation_length')}
        data['nodes'] = new_nodes
        with open(output[0], 'w') as fh:
            json.dump(data, fh, indent=2)

rule export:
    input:
        tree = "results/tree.nwk",
        meta = "results/metadata.tsv",
        branch_lengths = "results/branch_lengths_div_only.json",
        nt_muts = "results/nt_muts.json",
        aa_muts = "results/aa_muts.json",
        lineages = "results/lineages.json",
        auspice_config = config["files"]["auspice_config"],
        colors = config["files"]["colors"],
        description=config["files"]["description"]
    output:
        auspice_json = "auspice/tb_global.json"
    log:
        "logs/export.txt"
    benchmark:
        "benchmarks/export.txt"
    params:
        strain_id = config["strain_id_field"]
    shell:
        """
        exec &> >(tee {log:q})

        augur export v2 \
            --tree {input.tree} \
            --metadata {input.meta} \
            --metadata-id-columns {params.strain_id} \
            --node-data {input.branch_lengths} {input.nt_muts} {input.aa_muts} {input.lineages} \
            --colors {input.colors} \
            --auspice-config {input.auspice_config} \
            --description {input.description} \
            --output {output.auspice_json}
        """

rule tip_frequencies:
    input:
        tree = "results/tree.nwk",
        metadata = "results/metadata.tsv",
    log:
        "logs/tip_frequencies.txt"
    benchmark:
        "benchmarks/tip_frequencies.txt"
    params:
        strain_id = config["strain_id_field"],
        min_date = config["tip_frequencies"]["min_date"],
        max_date = config["tip_frequencies"]["max_date"],
        narrow_bandwidth = config["tip_frequencies"]["narrow_bandwidth"],
    output:
        tip_freq = "auspice/tb_global_tip-frequencies.json"
    shell:
        r"""
        exec &> >(tee {log:q})

        augur frequencies \
            --method kde \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --min-date {params.min_date} \
            --max-date {params.max_date} \
            --narrow-bandwidth {params.narrow_bandwidth} \
            --output {output.tip_freq}
        """

if "custom_rules" in config:
    for rule_file in config["custom_rules"]:

        include: rule_file
