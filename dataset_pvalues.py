import sys
import glob
import os
import re
import json
import itertools
import bisect
import functools
import scipy
import math
import random
from collections import defaultdict

import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from PIL import Image
from sklearn.linear_model import LogisticRegression, RidgeClassifier
from sklearn.model_selection import train_test_split
from sklearn.impute import SimpleImputer
from sklearn.metrics import average_precision_score, PrecisionRecallDisplay, precision_recall_curve, balanced_accuracy_score

mpl.rcParams['figure.figsize'] = (10,10)
FONT_SIZE = 24
plt.rc('font', size=FONT_SIZE)          # controls default text sizes
plt.rc('axes', titlesize=FONT_SIZE)    # fontsize of the axes title
plt.rc('axes', labelsize=FONT_SIZE)    # fontsize of the x and y labels
plt.rc('xtick', labelsize=FONT_SIZE)    # fontsize of the tick labels
plt.rc('ytick', labelsize=FONT_SIZE)    # fontsize of the tick labels
plt.rc('legend', fontsize=FONT_SIZE)    # legend fontsize
plt.rc('figure', titlesize=FONT_SIZE)  # fontsize of the figure title

plt.rc('figure', max_open_warning=50)

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
        # try:
        dt_1, dt_2 = get_datatype(ds_1), get_datatype(ds_2)
        pvalue = get_pvalue(pvalue_mappings[dt_1][dt_2], val)
        dataset_pvalues[ds_1][dt_2].append(pvalue)
        dataset_pvalues[ds_2][dt_1].append(pvalue)
        # except:
        #     print(ds_1, ds_2)
        #     print(dataset_pvalues.keys())
        #     print(dt_1, dt_2)
        #     print(pvalue_mappings.keys())
        #     raise
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
    elif aggregation_method == 'mudholkar-george':
        _, agg_pval = scipy.stats.combine_pvalues(pvalues, method='mudholkar_george')
        return agg_pval
    elif aggregation_method == 'mudholkar-george-filtered':
        small_pvalues = [pval for pval in pvalues if pval < 0.5]
        if len(small_pvalues) == 0:
            return min(pvalues)
        _, agg_pval = scipy.stats.combine_pvalues(small_pvalues, method='mudholkar_george')
        return agg_pval
    else:
        raise Exception(f'Unknown aggregation method `{aggregation_method}`')

def collect_aggregated_pvalues(pvalue_lists_by_dataset_and_datatype, aggregation_methods=None):
    datasets = []
    tfs = []
    experiment_types = []
    aggregated_pvalues = defaultdict(list)
    datatype_counts = defaultdict(list)
    is_curated = []
    # is_artifact = []
    artifact_metrics = defaultdict(list)
    best_artifact_types = []
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
            datatype_counts[datatype].append( len(pvalues) )
            for aggregation_method in aggregation_methods:
                aggregated_pvalues[f'{datatype}_{aggregation_method}'].append( logpval(aggregate_pvalues(pvalues, aggregation_method)) )
        #
        intra_pvalues = pvalue_lists_by_dataset_and_datatype[dataset].get(intra_datatype, [])
        inter_pvalues = []
        for dt, pvals in pvalue_lists_by_dataset_and_datatype[dataset].items():
            if dt != intra_datatype:
                inter_pvalues += pvals
        #
        datatype_counts['intra'].append( len(intra_pvalues) )
        datatype_counts['inter'].append( len(inter_pvalues) )
        datatype_counts['all'].append( len(intra_pvalues + inter_pvalues) )
        for aggregation_method in aggregation_methods:
            aggregated_pvalues[f'intra_{aggregation_method}'].append( logpval(aggregate_pvalues(intra_pvalues, aggregation_method)) )
            aggregated_pvalues[f'inter_{aggregation_method}'].append( logpval(aggregate_pvalues(inter_pvalues, aggregation_method)) )
            aggregated_pvalues[f'all_{aggregation_method}'].append( logpval(aggregate_pvalues(intra_pvalues + inter_pvalues, aggregation_method)) )
        #
        is_curated.append('Curated'  if exp_id in good_datasets else 'Non-curated')
        # is_artifact.append('Artifact'  if exp_id in artifact_datasets else 'Non-artifact')
        best_artifact_type = 'None'
        best_artifact_quantile = 2.0
        for artifact_type in artifact_types:
            if exp_id in dataset_artifact_metrics:
                quantile = dataset_artifact_metrics[exp_id].get(artifact_type, 2.0)
            else:
                quantile = 2.0
            artifact_metrics[artifact_type].append(quantile)
            if quantile < best_artifact_quantile:
                best_artifact_type = artifact_type
                best_artifact_quantile = quantile
        best_artifact_types.append(best_artifact_type  if best_artifact_quantile <= ARTIFACT_QUANTILE_THRESHOLD  else 'None')
    #
    df = pd.DataFrame({
       'tf': tfs, 'experiment_type': experiment_types, 'dataset': datasets,
       'is_curated': is_curated, #'is_artifact': is_artifact,
       'artifact_type': best_artifact_types,
    })
    #
    for dt in ['all', 'inter', 'intra', *DATA_TYPES]:
        df[f'{dt}_count'] = datatype_counts[dt]
        for aggregation_method in aggregation_methods:
            df[f'{dt}_{aggregation_method}_logpval'] = aggregated_pvalues[f'{dt}_{aggregation_method}']
    #
    for artifact_type in artifact_types:
        df[f'{artifact_type}_quantile'] = artifact_metrics[artifact_type]
    #
    return df

###########

def make_violinplot(df, filename, aggregation_method):
    df_intra = pd.DataFrame({'kind': 'intra', 'logpvalue': df[f'intra_{aggregation_method}_logpval'], 'dataset': df.dataset, 'is_curated': df.is_curated}) #, 'is_artifact': df.is_artifact})
    df_inter = pd.DataFrame({'kind': 'inter', 'logpvalue': df[f'inter_{aggregation_method}_logpval'], 'dataset': df.dataset, 'is_curated': df.is_curated}) #, 'is_artifact': df.is_artifact})
    df_by_kind = pd.concat([df_intra, df_inter]).dropna(subset=['logpvalue'])
    plt.figure()
    sns.violinplot(x='kind', hue='is_curated', hue_order=['Non-curated', 'Curated'], y='logpvalue', data=df_by_kind)
    plt.savefig(filename)
    plt.close()

###########

def make_scatterplot(df, filename, aggregation_method, max_logpval=float('inf')):
    plt.figure()
    bounded_df = df[(df[f'inter_{aggregation_method}_logpval'] <= max_logpval) & (df[f'intra_{aggregation_method}_logpval'] <= max_logpval)]
    # sns.scatterplot(x=f'intra_{aggregation_method}_logpval', y=f'inter_{aggregation_method}_logpval', hue='is_curated', hue_order=['Non-curated', 'Curated'], alpha=1.0, data=bounded_df[bounded_df.artifact_type != 'None'])
    sns.scatterplot(x=f'intra_{aggregation_method}_logpval', y=f'inter_{aggregation_method}_logpval', hue='is_curated', hue_order=['Non-curated', 'Curated'], alpha=1.0, data=bounded_df)
    # sns.scatterplot(x='intra_logpval', y='inter_logpval', hue='is_artifact', hue_order=['Non-artifact', 'Artifact'], alpha=1.0, data=bounded_df)
    # plt.xlim(0, 13)
    # plt.ylim(0, 13)
    plt.savefig(filename)
    plt.close()

###########

def classifier_name(feature_list):
    clf_name = feature_list if isinstance(feature_list, str) else "+".join(feature_list)
    clf_name = clf_name.replace('/', '-')
    if len(clf_name) > 200:
        clf_name = "+".join(f'{ftr[:5]}..{ftr[-5:]}' for ftr in feature_list)
    return clf_name

###########

def prediction_rates_by_recall(labels, predictions, recall_thresholds):
    num_positives = sum(labels)
    for recall_threshold in recall_thresholds:
        num_positives_recalled = 0
        for idx, (score,label) in enumerate(sorted(zip(predictions, labels), reverse=True), start = 1):
            num_positives_recalled += label
            if num_positives_recalled >= recall_threshold * num_positives:
                num_negatives = len(labels) - num_positives
                num_negatives_recalled = idx - num_positives_recalled
                yield (recall_threshold, (num_positives_recalled, num_positives), (num_negatives_recalled, num_negatives))
                break

def precision_by_recall(labels, predictions, recall_thresholds):
    if len(labels) != len(predictions):
        raise 'Labels and predictions are of inconsistent length'
    if len(predictions) == 0:
        raise 'Empty predictions'
    precision, recall, thresholds = precision_recall_curve(labels, predictions)
    precision, recall, thresholds = precision[::-1], recall[::-1], thresholds[::-1]
    for recall_threshold in recall_thresholds:
        idx = bisect.bisect_left(recall, recall_threshold)
        if idx != len(recall):
            yield (recall[idx], precision[idx])
        else:
            yield (recall[idx - 1], precision[idx - 1])


def positive_negative_curve(labels, predictions):
    num_positives = sum(labels)
    num_positives_recalled = 0
    for idx, (score,label) in enumerate(sorted(zip(predictions, labels), reverse=True), start = 1):
        num_positives_recalled += label
        num_negatives = len(labels) - num_positives
        num_negatives_recalled = idx - num_positives_recalled
        yield (score, (num_positives_recalled, num_positives), (num_negatives_recalled, num_negatives))

###########

results_folder = sys.argv[1] # ./dataset_classifier
heatmaps_folder = sys.argv[2] # ./heatmaps

os.makedirs(results_folder, exist_ok=True)


# flank_filter_fns = ['HTS_flanks_hits_recalc.tsv', 'AFS_flanks_hits_recalc.tsv', 'SMS_unpublished_flanks_hits_recalc.tsv', 'SMS_published_flanks_hits_recalc.tsv']
# flank_threshold = 4.0

# motifs_in_flanks = set()
# for flank_filter_fn in flank_filter_fns:
#     with open(flank_filter_fn) as f:
#         for line in f:
#             motif_wo_ext, tf, exp_id, flank_type, logpval, pos, strand = line.rstrip().split("\t")
#             if exp_id == 'all':
#                 raise "Can't handle non-dataset ids"
#             logpval = float(logpval)
#             if logpval >= flank_threshold:
#                 motifs_in_flanks.add(motif_wo_ext)

# all_metric_infos.select!{|info|
#   motif_wo_ext = ['.pcm', '.ppm', '.pwm'].inject(info[:motif]){|fn, ext| File.basename(fn, ext) }
#   if filter_out_motifs.include?(motif_wo_ext)
#     info = ["discarded motif due to sticky flanks",  info[:motif]]
#     $stderr.puts(info.join("\t"))
#     false
#   else
#     true
#   end
# }


DATA_TYPES = ['PBM', 'CHS', 'SMS', 'AFS-LYS', 'AFS-IVT', 'AFS-GFPIVT', 'HTS-LYS', 'HTS-IVT', 'HTS-GFPIVT']
AGGREGATION_METHODS = ['min', 'fisher', 'mudholkar-george', 'mudholkar-george-filtered', 'tippett']

ARTIFACT_QUANTILE_THRESHOLD = 0.05
dataset_artifact_metrics_fn = 'dataset_artifact_metrics.json'

with open(dataset_artifact_metrics_fn) as f:
    dataset_artifact_metrics = json.load(f)

artifact_types = set()
for art_hsh in dataset_artifact_metrics.values():
    for artifact_type in art_hsh.keys():
        artifact_types.add(artifact_type)

artifact_types = sorted(artifact_types)

with open('good_datasets.txt') as f:
    good_datasets = set(l.strip() for l in f.readlines())


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

dataset_correlation_triples = load_dataset_correlations(f'{heatmaps_folder}/*.json')
pvalue_lists_by_dataset_and_datatype = collect_pvalue_lists_by_dataset_and_datatype(dataset_correlation_triples)

df = collect_aggregated_pvalues(pvalue_lists_by_dataset_and_datatype, AGGREGATION_METHODS)
df.to_csv(f'{results_folder}/dataset_pvalues.tsv', sep='\t')

# df = pd.read_csv('dataset_pvalues.tsv', sep='\t')

for aggregation_method in AGGREGATION_METHODS:
    make_violinplot(df, f'{results_folder}/{aggregation_method}_logpval_distribution.png', aggregation_method)
    make_scatterplot(df, f'{results_folder}/{aggregation_method}_ds_pvals_scatterplot.png', aggregation_method)
    make_scatterplot(df, f'{results_folder}/{aggregation_method}_ds_pvals_scatterplot_lowpval.png', aggregation_method, max_logpval=1.0)


feature_lists = []
for feature_type in ['intra', 'inter', 'all']:
    for feature_meth in AGGREGATION_METHODS:
        feature_lists.append([f'{feature_type}_{feature_meth}_logpval'])
    feature_lists.append([f'{feature_type}_count'])

for artifact_type in artifact_types:
    feature_lists.append( [f'{artifact_type}_quantile'] )
feature_lists.append( ['inter_fisher_logpval', 'intra_fisher_logpval'] )
feature_lists.append( ['inter_fisher_logpval', 'intra_fisher_logpval'] + [f'{artifact_type}_quantile' for artifact_type in artifact_types] )
feature_lists.append( ['all_fisher_logpval',] + [f'{artifact_type}_quantile' for artifact_type in artifact_types] )
feature_lists.append( ['inter_fisher_logpval', 'intra_fisher_logpval', 'intra_count', 'inter_count'] + [f'{artifact_type}_quantile' for artifact_type in artifact_types] )
feature_lists.append( ['all_fisher_logpval', 'intra_count', 'inter_count'] + [f'{artifact_type}_quantile' for artifact_type in artifact_types] )
feature_lists.append( ['inter_tippett_logpval', 'intra_tippett_logpval'] )
feature_lists.append( ['inter_mudholkar-george_logpval', 'intra_mudholkar-george_logpval'] )
feature_lists.append( ['inter_mudholkar-george-filtered_logpval', 'intra_mudholkar-george-filtered_logpval'] )
feature_lists.append( ['inter_fisher_logpval', 'intra_fisher_logpval', 'inter_count', 'intra_count'] )
feature_lists.append( ['inter_tippett_logpval', 'intra_tippett_logpval', 'inter_count', 'intra_count'] )
feature_lists.append( ['inter_mudholkar-george_logpval', 'intra_mudholkar-george_logpval', 'inter_count', 'intra_count'] )
feature_lists.append( ['inter_mudholkar-george-filtered_logpval', 'intra_mudholkar-george-filtered_logpval', 'inter_count', 'intra_count'] )
feature_lists.append( '_random' )
feature_lists.append( '_all' )


y = (df['is_curated'] == 'Curated').astype(int)

with open(f'{results_folder}/dataset_classifier.tsv', 'w') as fw:
    for feature_list in feature_lists:
        if feature_list == '_random':
            X = pd.DataFrame({'random': df.apply(lambda row: random.random(), axis=1)})
        elif feature_list == '_all':
            X = df.drop(['is_curated', 'dataset', 'tf', 'experiment_type', 'artifact_type'], axis=1)
        else:
            X = df[ feature_list ]
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.33, random_state=42)

        imputer = SimpleImputer(strategy='median')
        imputer.fit(X_train)
        X_train = imputer.transform(X_train)
        X_test = imputer.transform(X_test)

        # classifier = RidgeClassifier(class_weight='balanced', random_state=42).fit(X_train, y_train)
        classifier = LogisticRegression(random_state=42, penalty='l2', solver='liblinear', class_weight='balanced').fit(X_train, y_train)
        y_test_predictions = classifier.predict_proba(X_test)[:, 1]
        y_test_predictions_binary = classifier.predict(X_test)

        plt.figure()
        clf_name = classifier_name(feature_list)
        PrecisionRecallDisplay.from_predictions(y_test, y_test_predictions, name=clf_name, pos_label=1)
        plt.savefig(f'{results_folder}/PR_{clf_name}.png')
        plt.close()

        print('\n'.join(str(arr) for arr in zip(list(X.columns), classifier.coef_[0])), file=fw)
        print(f'--------------------\n{feature_list}', file=fw)
        print('classifier score:', classifier.score(X_test, y_test), file=fw)
        print('balanced accuracy:', balanced_accuracy_score(y_test, y_test_predictions_binary), file=fw)

        for (recall_threshold, (pos_recalled, pos_total), (neg_recalled, neg_total)) in prediction_rates_by_recall(y_test, y_test_predictions, [0.75, 0.9, 0.95]):
            print(f'At recall {pos_recalled / pos_total} num positives is {pos_recalled} (of {pos_total}), num negatives is {neg_recalled} (of {neg_total})', file=fw)
        # for (recall, precision) in precision_by_recall(y_test, y_test_predictions, [0.75, 0.9, 0.95]):
        #     print(f'At recall {recall} precision is {precision}', file=fw)
        # print('mAP:', average_precision_score(y_test, y_test_predictions), file=fw)

        curve_score = []
        curve_pos = []
        curve_neg = []
        for (score, (pos_recalled, pos_total), (neg_recalled, neg_total)) in positive_negative_curve(y_test, y_test_predictions):
            curve_score.append(score)
            curve_pos.append(pos_recalled / pos_total)
            curve_neg.append(neg_recalled / neg_total)
            # print(f'At recall {pos_recalled / pos_total} num positives is {pos_recalled} (of {pos_total}), num negatives is {neg_recalled} (of {neg_total})', file=fw)

        plt.figure()
        plt.line(curve_score, curve_pos)
        plt.line(curve_score, curve_neg)
        plt.close()


    print('=================================', file=fw)
    print(df.groupby('artifact_type').is_curated.value_counts(), file=fw)
    print('Curated motifs with artifacts', file=fw)
    df[ (df.is_curated == "Curated") & (df.artifact_type != "None") ][ ['tf', 'dataset'] ]
    print('=================================', file=fw)

