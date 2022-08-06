import glob
import os
import re
import json
import itertools
import bisect
import functools
import scipy
import math
from collections import defaultdict

import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from PIL import Image


mpl.rcParams['figure.figsize'] = (10,10)
FONT_SIZE = 24
plt.rc('font', size=FONT_SIZE)          # controls default text sizes
plt.rc('axes', titlesize=FONT_SIZE)    # fontsize of the axes title
plt.rc('axes', labelsize=FONT_SIZE)    # fontsize of the x and y labels
plt.rc('xtick', labelsize=FONT_SIZE)    # fontsize of the tick labels
plt.rc('ytick', labelsize=FONT_SIZE)    # fontsize of the tick labels
plt.rc('legend', fontsize=FONT_SIZE)    # legend fontsize
plt.rc('figure', titlesize=FONT_SIZE)  # fontsize of the figure title


def get_pvalue_mapping(values):
    sz = len(values)
    return [(val, (sz-idx)/sz) for idx, val in enumerate(sorted(values))]

def get_pvalue(mapping, val):
    idx = bisect.bisect_left(mapping, (val, -1))
    if idx == 0:
        return 1.0
    else:
        return mapping[idx-1][1]

def get_datatype(dataset):
    return dataset.split(':')[0]

def get_experiment_id(dataset):
    return dataset.split(':')[1]


def load_dataset_correlations(heatmaps_glob):
    dataset_correlation_triples = []
    for dataset_correlation_heatmap_fn in glob.glob(heatmaps_glob):
        tf = re.sub(r'\.json$', '', os.path.basename(dataset_correlation_heatmap_fn))
        with open(dataset_correlation_heatmap_fn) as f:
            data = json.load(f)['data']
        #
        for ds_info in data:
            ds_1 = ds_info['name']
            for corr_info in ds_info['data']:
                ds_2 = corr_info['x']
                val = corr_info['y']
                if ds_1 < ds_2:
                    dataset_correlation_triples.append((ds_1, ds_2, val))
    return dataset_correlation_triples

def collect_pvalue_mappings(dataset_correlation_triples):
    datatypes_1 = []
    datatypes_2 = []
    values = []
    for ds_1, ds_2, val in dataset_correlation_triples:
        dt_1, dt_2 = get_datatype(ds_1), get_datatype(ds_2)
        datatypes_1.append(dt_1)
        datatypes_2.append(dt_2)
        values.append(val)
        if dt_1 != dt_2:
            datatypes_1.append(dt_2)
            datatypes_2.append(dt_1)
            values.append(val)
    #
    df = pd.DataFrame({
        'datatype_1': datatypes_1,
        'datatype_2': datatypes_2,
        'value': values,
    })
    #
    pvalue_mappings = defaultdict(dict)
    for dt1 in DATA_TYPES:
        for dt2 in DATA_TYPES:
            vals = list(df[(df.datatype_1 == dt1) & (df.datatype_2 == dt2)]['value'])
            pvalue_mappings[dt1][dt2] = get_pvalue_mapping(vals)
    return pvalue_mappings

def collect_pvalue_lists_by_dataset_and_datatype(dataset_correlation_triples):
    pvalue_mappings = collect_pvalue_mappings(dataset_correlation_triples)
    dataset_pvalues = defaultdict(lambda: defaultdict(list))
    for (ds_1, ds_2, val) in dataset_correlation_triples:
        dt_1, dt_2 = get_datatype(ds_1), get_datatype(ds_2)
        pvalue = get_pvalue(pvalue_mappings[dt_1][dt_2], val)
        dataset_pvalues[ds_1][dt_2].append(pvalue)
        dataset_pvalues[ds_2][dt_1].append(pvalue)
    return dataset_pvalues


def logpval(pvalue):
    if pvalue:
        return -math.log10(pvalue)
    else:
        return None

def aggregate_pvalues(pvalues, aggregation_method):
    if len(pvalues) == 0:
        return None
    #
    if aggregation_method == 'min':
        return min(pvalues)
    elif aggregation_method == 'fisher':
        _, agg_pval = scipy.stats.combine_pvalues(pvalues, method='fisher')
        return agg_pval
    elif aggregation_method == 'tippett':
        _, agg_pval = scipy.stats.combine_pvalues(pvalues, method='tippett')
        return agg_pval
    elif aggregation_method == 'mudholkar_george':
        _, agg_pval = scipy.stats.combine_pvalues(pvalues, method='mudholkar_george')
        return agg_pval
    elif aggregation_method == 'mudholkar_george_filtered':
        small_pvalues = [pval for pval in pvalues if pval < 0.5]
        if len(small_pvalues) == 0:
            return min(pvalues)
        _, agg_pval = scipy.stats.combine_pvalues(small_pvalues, method='mudholkar_george')
        return agg_pval
    else:
        raise Exception(f'Unknown aggregation method `{aggregation_method}`')

def collect_aggregated_pvalues(pvalue_lists_by_dataset_and_datatype, aggregation_method):
    datasets = []
    tfs = []
    experiment_types = []
    aggregated_pvalues = defaultdict(list)
    datatype_counts = defaultdict(list)
    is_curated = []
    is_artifact = []
    for dataset in pvalue_lists_by_dataset_and_datatype:
        intra_datatype = get_datatype(dataset)
        exp_id = get_experiment_id(dataset)
        tf = tf_by_expname[exp_id]
        #
        datasets.append(dataset)
        tfs.append(tf)
        experiment_types.append(intra_datatype)
        #
        for datatype in DATA_TYPES:
            pvalues = pvalue_lists_by_dataset_and_datatype[dataset].get(datatype, [])
            aggregated_pvalues[datatype].append( logpval(aggregate_pvalues(pvalues, aggregation_method)) )
            datatype_counts[datatype].append( len(pvalues) )
        #
        intra_pvalues = pvalue_lists_by_dataset_and_datatype[dataset].get(intra_datatype, [])
        inter_pvalues = []
        for dt, pvals in pvalue_lists_by_dataset_and_datatype[dataset].items():
            if dt != intra_datatype:
                inter_pvalues += pvals
        #
        aggregated_pvalues['intra'].append( logpval(aggregate_pvalues(intra_pvalues, aggregation_method)) )
        aggregated_pvalues['inter'].append( logpval(aggregate_pvalues(inter_pvalues, aggregation_method)) )
        aggregated_pvalues['all'].append( logpval(aggregate_pvalues(intra_pvalues + inter_pvalues, aggregation_method)) )
        datatype_counts['intra'].append( len(intra_pvalues) )
        datatype_counts['inter'].append( len(inter_pvalues) )
        datatype_counts['all'].append( len(intra_pvalues + inter_pvalues) )
        #
        is_curated.append('Curated'  if exp_id in good_datasets else 'Non-curated')
        is_artifact.append('Artifact'  if exp_id in artifact_datasets else 'Non-artifact')
    #
    df = pd.DataFrame({
       'tf': tfs, 'experiment_type': experiment_types, 'dataset': datasets,
       'is_curated': is_curated, 'is_artifact': is_artifact,
    })
    #
    for dt in ['all', 'inter', 'intra', *DATA_TYPES]:
        df[f'{dt}_logpval'] = aggregated_pvalues[dt]
        df[f'{dt}_count'] = datatype_counts[dt]
    #
    return df

###########

def make_violinplot(df, filename):
    df_intra = pd.DataFrame({'kind': 'intra', 'logpvalue': df.intra_logpval, 'dataset': df.dataset, 'is_curated': df.is_curated, 'is_artifact': df.is_artifact})
    df_inter = pd.DataFrame({'kind': 'inter', 'logpvalue': df.inter_logpval, 'dataset': df.dataset, 'is_curated': df.is_curated, 'is_artifact': df.is_artifact})
    df_by_kind = pd.concat([df_intra, df_inter]).dropna(subset=['logpvalue'])
    plt.figure()
    sns.violinplot(x='kind', hue='is_curated', hue_order=['Non-curated', 'Curated'], y='logpvalue', data=df_by_kind)
    plt.savefig(filename)

###########

def make_scatterplot(df, filename, max_logpval=float('inf')):
    plt.figure()
    bounded_df = df[(df.inter_logpval <= max_logpval) & (df.intra_logpval <= max_logpval)]
    sns.scatterplot(x='intra_logpval', y='inter_logpval', hue='is_curated', hue_order=['Non-curated', 'Curated'], alpha=1.0, data=bounded_df)
    # sns.scatterplot(x='intra_logpval', y='inter_logpval', hue='is_artifact', hue_order=['Non-artifact', 'Artifact'], alpha=1.0, data=bounded_df)
    # plt.xlim(0, 13)
    # plt.ylim(0, 13)
    plt.savefig(filename)

###########


DATA_TYPES = ['PBM', 'CHS', 'SMS', 'AFS-LYS', 'AFS-IVT', 'AFS-GFPIVT', 'HTS-LYS', 'HTS-IVT', 'HTS-GFPIVT']

with open('good_datasets.txt') as f:
    good_datasets = set(l.strip() for l in f.readlines())

with open('artifact_datasets.json') as f:
    artifact_datasets = set(json.load(f))


metadata = []
with open('metadata_release_8d.json') as f:
    for line in f:
        metadata.append(json.loads(line))

tf_by_expname = {}
for info in metadata:
    exp = info['experiment_id']
    replica = info.get('experiment_params', {}).get('replica')
    if replica:
        exp = f'{exp}.Rep-{replica}'
    tf = info['tf']
    if (exp in tf_by_expname) and tf_by_expname[exp] != tf:
        raise Exception('Error')
    tf_by_expname[exp] = tf

dataset_correlation_triples = load_dataset_correlations('heatmaps/*.json')
pvalue_lists_by_dataset_and_datatype = collect_pvalue_lists_by_dataset_and_datatype(dataset_correlation_triples)



for aggregation_method in ['min', 'fisher', 'mudholkar_george', 'mudholkar_george_filtered', 'tippett']:
    df = collect_aggregated_pvalues(pvalue_lists_by_dataset_and_datatype, aggregation_method)
    df.to_csv(f'{aggregation_method}_dataset_pvalues.tsv', sep='\t')
    make_violinplot(df, f'{aggregation_method}_logpval_distribution.png')
    make_scatterplot(df, f'{aggregation_method}_ds_pvals_scatterplot.png')
    make_scatterplot(df, f'{aggregation_method}_ds_pvals_scatterplot_lowpval.png', max_logpval=1.0)
