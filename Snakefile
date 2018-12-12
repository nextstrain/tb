rule all:
    input:
        auspice_tree = "auspice/tb_tree.json",
        auspice_meta = "auspice/tb_meta.json"

# Config variables to be used by rules
# Parameters are defined within their own rules

rule config:
    params:
        seq = "data/lee_2015.vcf.gz",
        ref = "data/ref.fasta",
        meta = "data/meta.tsv",
        exclude = "config/dropped_strains.txt",
        mask = "config/Locus_to_exclude_Mtb.bed",
        drms = "config/DRMs-AAnuc.tsv",
        sites = "config/drm_sites.txt",
        generef = "config/Mtb_H37Rv_NCBI_Annot.gff",
        genes = "config/genes.txt",
        clades = "config/clades.tsv",
        colors = "config/color.tsv",
        config = "config/config.json",
        geo_info = "config/lat_longs.tsv"

config = rules.config.params #so we can use config.x rather than rules.config.params.x
#end of config definition

rule filter:
    input:
        seq = config.seq,
        meta = config.meta,
        exclude = config.exclude
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
        seq = rules.filter.output,
        mask = config.mask
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
        aln = rules.mask.output,
        ref = config.ref,
        sites = config.sites
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
        tree = rules.tree.output,
        aln = rules.mask.output,
        metadata = config.meta,
        ref = config.ref
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
        tree = rules.refine.output.tree,
        alignment = rules.mask.output,
        ref = config.ref
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
            --output {output.nt_data} \
            --output-vcf {output.vcf_out}
        """

rule translate:
    input:
        tree = rules.refine.output.tree,
        ref = config.ref,
        gene_ref = config.generef,
        vcf = rules.ancestral.output.vcf_out,
        genes = config.genes
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
            --output {output.aa_data} \
            --alignment-output {output.vcf_out} \
            --vcf-reference-output {output.vcf_ref}
        """

rule clades:
    input:
        tree = rules.refine.output.tree,
        aa_muts = rules.translate.output.aa_data,
        nuc_muts = rules.ancestral.output.nt_data,
        clades = config.clades
    output:
        clade_data = "results/clades.json"
    shell:
        """
        augur clades --tree {input.tree} \
            --mutations {input.nuc_muts} {input.aa_muts} \
            --clades {input.clades} \
            --output {output.clade_data}
        """

rule traits:
    input:
        tree = rules.refine.output.tree,
        meta = config.meta
    output:
        "results/traits.json"
    params:
        traits = 'location'
    shell:
        """
        augur traits --tree {input.tree} \
            --metadata {input.meta} \
            --columns {params.traits} \
            --output {output}
        """

rule seqtraits:
    input:
        align = rules.ancestral.output.vcf_out,
        ref = config.ref,
        trans_align = rules.translate.output.vcf_out,
        trans_ref = rules.translate.output.vcf_ref,
        drms = config.drms
    output:
        drm_data = "results/drms.json"
    params:
        count = "traits",
        label = "Drug_Resistance"
    shell:
        """
        augur sequence-traits \
            --ancestral-sequences {input.align} \
            --vcf-reference {input.ref} \
            --translations {input.trans_align} \
            --vcf-translate-reference {input.trans_ref} \
            --features {input.drms} \
            --count {params.count} \
            --label {params.label} \
            --output {output.drm_data}
        """

rule export:
    input:
        tree = rules.refine.output.tree,
        metadata = config.meta,
        branch_lengths = rules.refine.output.node_data,
        traits = rules.traits.output,
        nt_muts = rules.ancestral.output.nt_data,
        aa_muts = rules.translate.output.aa_data,
        drms = rules.seqtraits.output.drm_data,
        color_defs = config.colors,
        config = config.config,
        geo_info = config.geo_info,
        clades = rules.clades.output.clade_data
    output:
        tree = rules.all.input.auspice_tree,
        meta = rules.all.input.auspice_meta
    shell:
        """
        augur export \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.traits} {input.drms} {input.aa_muts} {input.nt_muts} {input.clades} \
            --auspice-config {input.config} \
            --colors {input.color_defs} \
            --lat-longs {input.geo_info} \
            --output-tree {output.tree} \
            --output-meta {output.meta}
        augur validate --json {output.tree} {output.meta}
        """
