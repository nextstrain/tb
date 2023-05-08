rule all:
    input:
        auspice_json = "auspice/tb.json",

# names of files used in the analysis
seq_file = "data/lee_2015.vcf.gz"
ref_file = "data/ref.fasta"
meta_file = "data/meta.tsv"
exclude_file = "config/dropped_strains.txt"
mask_file = "config/Locus_to_exclude_Mtb.bed"
drms_file = "config/DRMs-AAnuc.tsv"
sites_file = "config/drm_sites.txt"
generef_file = "config/Mtb_H37Rv_NCBI_Annot.gff"
genes_file = "config/genes.txt"
clades_file = "config/clades.tsv"
colors_file = "config/color.tsv"
auspice_config_file = "config/auspice_config.json"
geo_info_file = "config/lat_longs.tsv"


rule filter:
    input:
        seq = seq_file,
        meta = meta_file,
        exclude = exclude_file
    output:
        "results/filtered.vcf.gz"
    shell:
        """
        augur filter --sequences {input.seq} \
            --metadata {input.meta} \
            --exclude {input.exclude} \
            --output {output}
        """

rule mask:
    input:
        seq = "results/filtered.vcf.gz",
        mask = mask_file
    output:
       "results/masked.vcf.gz"
    shell:
        """
        augur mask --sequences {input.seq} \
            --mask {input.mask} \
            --output {output}
        """

rule tree:
    input:
        aln = "results/masked.vcf.gz",
        ref = ref_file,
        sites = sites_file
    output:
        "results/tree_raw.nwk"
    params:
        method = 'iqtree'
    shell:
        """
        augur tree --alignment {input.aln} \
            --vcf-reference {input.ref} \
            --method {params.method} \
            --exclude-sites {input.sites} \
            --output {output}
        """

rule refine:
    input:
        tree = "results/tree_raw.nwk",
        aln = "results/masked.vcf.gz",
        metadata = meta_file,
        ref = ref_file
    output:
        tree = "results/tree.nwk",
        node_data = "results/branch_lengths.json",
    params:
        root = 'min_dev',
        coal = 'opt'
    shell:
        """
        augur refine --tree {input.tree} \
            --alignment {input.aln} \
            --vcf-reference {input.ref} \
            --metadata {input.metadata} \
            --timetree \
            --root {params.root} \
            --coalescent {params.coal} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data}
        """

rule ancestral:
    input:
        tree = "results/tree.nwk",
        alignment = "results/masked.vcf.gz",
        ref = ref_file
    output:
        nt_data = "results/nt_muts.json",
        vcf_out = "results/nt_muts.vcf"
    params:
        inference = "joint"
    shell:
        """
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
        ref = ref_file,
        gene_ref = generef_file,
        vcf = "results/nt_muts.vcf",
        genes = genes_file
    output:
        aa_data = "results/aa_muts.json",
        vcf_out = "results/translations.vcf",
        vcf_ref = "results/translations_reference.fasta"
    shell:
        """
        augur translate --tree {input.tree} \
            --vcf-reference {input.ref} \
            --ancestral-sequences {input.vcf} \
            --genes {input.genes} \
            --reference-sequence {input.gene_ref} \
            --output-node-data {output.aa_data} \
            --alignment-output {output.vcf_out} \
            --vcf-reference-output {output.vcf_ref}
        """

rule clades:
    input:
        tree = "results/tree.nwk",
        aa_muts = "results/aa_muts.json",
        nuc_muts = "results/nt_muts.json",
        clades = clades_file
    output:
        clade_data = "results/clades.json"
    shell:
        """
        augur clades --tree {input.tree} \
            --mutations {input.nuc_muts} {input.aa_muts} \
            --clades {input.clades} \
            --output-node-data {output.clade_data}
        """

rule traits:
    input:
        tree = "results/tree.nwk",
        meta = meta_file
    output:
        "results/traits.json"
    params:
        traits = 'location'
    shell:
        """
        augur traits --tree {input.tree} \
            --metadata {input.meta} \
            --columns {params.traits} \
            --output-node-data {output}
        """

rule seqtraits:
    input:
        align = "results/nt_muts.vcf",
        ref = ref_file,
        trans_align = "results/translations.vcf",
        trans_ref = "results/translations_reference.fasta",
        drms = drms_file
    output:
        drm_data = "results/drms.json"
    params:
        field_to_count = "traits",
        label = "Drug_Resistance"
    shell:
        """
        augur sequence-traits \
            --ancestral-sequences {input.align} \
            --vcf-reference {input.ref} \
            --translations {input.trans_align} \
            --vcf-translate-reference {input.trans_ref} \
            --features {input.drms} \
            --count {params.field_to_count} \
            --label {params.label} \
            --output-node-data {output.drm_data}
        """

rule export:
    input:
        tree = "results/tree.nwk",
        metadata = meta_file,
        branch_lengths = "results/branch_lengths.json",
        traits = "results/traits.json",
        nt_muts = "results/nt_muts.json",
        aa_muts = "results/aa_muts.json",
        drms = "results/drms.json",
        color_defs = colors_file,
        auspice_config = auspice_config_file,
        geo_info = geo_info_file,
        clades = "results/clades.json"
    output:
        auspice_json = rules.all.input.auspice_json,
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.traits} {input.drms} {input.aa_muts} {input.nt_muts} {input.clades} \
            --auspice-config {input.auspice_config} \
            --colors {input.color_defs} \
            --lat-longs {input.geo_info} \
            --output {output.auspice_json} \
        """

rule clean:
    message: "Removing directories: {params}"
    params:
        "results ",
        "auspice"
    shell:
        "rm -rfv {params}"
