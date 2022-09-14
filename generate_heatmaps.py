import sys
import os
import json
from itertools import groupby
import scipy

def drop_key_combined(hsh):
    return {k: v  for k,v in hsh.items() if k != 'combined'}

def dataset_motif_ranks_by_tf_info(tf_info):
    for motif, motif_info in tf_info.items():
        yield from dataset_motif_ranks_by_motif_info(motif, motif_info)

def dataset_motif_ranks_by_motif_info(motif, motif_info):
    for datatype, datatype_info in drop_key_combined(motif_info).items():
        for dataset, dataset_info in drop_key_combined(datatype_info).items():
            yield {'datatype': datatype, 'dataset': dataset, 'motif': motif, 'rank': dataset_info['combined']}

def dataset_ranks(tf_info):
    motifs_order = sorted(tf_info.keys(), key=lambda motif: tf_info[motif]['combined'])
    datatype_dataset_fn = lambda info: (info['datatype'], info['dataset'])
    for (datatype, dataset), grp in groupby(sorted(dataset_motif_ranks_by_tf_info(tf_info), key=datatype_dataset_fn), key=datatype_dataset_fn):
        rank_by_motif = {info['motif']: info['rank']  for info in grp}
        ranks = [rank_by_motif.get(motif) for motif in motifs_order]
        yield ((datatype, dataset), ranks)

results_folder = sys.argv[1] # # ./heatmaps
ranks_fn = sys.argv[2] # ./benchmarks/release_8d/ranks_7e+8c_pack_1+2+3+4.json
os.makedirs(results_folder, exist_ok=True)

with open(ranks_fn) as f:
    all_ranks_dataset = json.load(f)

for tf, tf_info in all_ranks_dataset.items():
    ranks_by_dataset = dict(dataset_ranks(tf_info))
    #
    ranks_info = {
        'data': [],
        'max_value': -float('inf'),
        'min_value': float('inf'),
    }
    #
    for datatype_1, dataset_1 in ranks_by_dataset:
        ranks_info['data'].append( {'name': f'{datatype_1.replace(".", "-").upper()}:{dataset_1}', 'data': []} )
        for datatype_2, dataset_2 in ranks_by_dataset:
            ranks_1 = ranks_by_dataset[(datatype_1, dataset_1)]
            ranks_2 = ranks_by_dataset[(datatype_2, dataset_2)]
            ranks_1, ranks_2 = zip(* (vs for vs in zip(ranks_1, ranks_2) if None not in vs) )
            corr = scipy.stats.weightedtau(ranks_1, ranks_2).correlation
            ranks_info['data'][-1]['data'].append({'x': f'{datatype_2.replace(".", "-").upper()}:{dataset_2}', 'y': corr})
            ranks_info['min_value'] = min(ranks_info['min_value'], corr)
            ranks_info['max_value'] = max(ranks_info['max_value'], corr)
    #
    with open(f'{results_folder}/{tf}.json', 'w') as fw:
        json.dump(ranks_info, fw)
