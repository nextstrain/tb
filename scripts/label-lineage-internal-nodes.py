"""
Label the MRCA branches for TB lineages allowing some mismatches
"""

import argparse
from Bio import Phylo
from augur.io import read_metadata
import json
from collections import Counter

def valid_lineage(lineage):
    return lineage and ";" not in lineage # don't consider recombinant lineages

def lineage_origins(T, metadata, lineage_key="main_lineage", allowed_conflicts = 2):
    """
    Return the best origin node for each (valid) lineage. "Best" here means that we allow
    a small number of tips to be mislabelled within the clade. (For instance, 'ERR4553409'
    is called as lineage4 but phylogenetically groups with lineage1 samples)
    """
    origins = {}
    stack = [*T.root.clades]
    
    while len(stack):
        node = stack.pop(0)
        if node.is_terminal():
            continue
        tips = [n.name for n in node.get_terminals()]
        m = metadata.loc[tips]

        counts = Counter([name for name in m[lineage_key].tolist() if valid_lineage(name)])

        if not counts:
            # No usable lineage labels among these tips (all missing or filtered)
            for child in node.clades:
                stack.append(child)
            continue
        [most_common_name, most_common_count] = counts.most_common(1)[0]

        if most_common_count + allowed_conflicts >= counts.total():
            if most_common_name in origins:
                # Check if this is better match
                if most_common_count >= origins[most_common_name]['num_matches']:
                    print(f"(re-)calling node {node.name} as the MRCA of {most_common_name}", counts)
                    origins[most_common_name] = {'num_matches': most_common_count, 'node': node}
            else:
                print(f"calling node {node.name} as the MRCA of {most_common_name}", counts)
                origins[most_common_name] = {'num_matches': most_common_count, 'node': node}

        for child in node.clades:
            stack.append(child)

    return {name: details['node'] for name,details in origins.items()}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tree", required=True, help="Newick")
    parser.add_argument("--metadata", required=True, help="Metadata TSV")
    parser.add_argument("--output", required=True, help="Node Data JSON")
    parser.add_argument("--id-columns", nargs="+", help="ID columns in Metadata TSV", default=['strain'])
    args = parser.parse_args()

    T = Phylo.read(args.tree, "newick")
    m = read_metadata(args.metadata, id_columns=args.id_columns)
    j = {'branches': {}, 'nodes': {}} # node-data JSON

    # Restrict metadata to terminal nodes (may not change anything depending on the provided metadata)
    tips = {c.name for c in T.get_terminals()}
    m = m.loc[m.index.isin(tips)]

    main_lineage_origins = lineage_origins(T, m)

    # label origin branches, allowing for lineages to be nested.
    # NOTE: If you also want to label nodes care must be taken to not label the internal nodes of
    # small sub-clades whose tips differ from the lineage name. For instance a small sub-clade of
    # recombinants.
    main_lineage_origins_rev = {v:k for k,v in main_lineage_origins.items()}
    for node in T.find_clades(order='preorder'):
        if node in main_lineage_origins_rev:
            j['branches'][node.name] = {
                'labels': {
                    'main_lineage': main_lineage_origins_rev[node]
                }
            }

    with open(args.output, 'w') as fh:
        json.dump(j, fh, indent=2)
