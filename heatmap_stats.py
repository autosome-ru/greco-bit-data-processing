import json
import itertools

def mean(vals):
    if len(vals) == 0:
        return None
    return sum(vals) / len(vals)

def stats(vals):
    return {'count': len(vals), 'mean': mean(vals), 'values': vals}

with open('heatmaps/CTCF.json') as f:
    data = json.load(f)['data']

triples = []
for ds_info in data:
    ds_1 = ds_info['name']
    for corr_info in ds_info['data']:
        ds_2 = corr_info['x']
        val = corr_info['y']
        if ds_1 < ds_2:
            triples.append(((ds_1.split(':')[0], ds_1), (ds_2.split(':')[0], ds_2), val))

data_types = set()
for ((dt_1, ds_1), (dt_2, ds_2), val) in triples:
    data_types.add(dt_1)
    data_types.add(dt_2)

dt_stats = {}
for data_types_pair in itertools.combinations_with_replacement(data_types, 2):
    # matching_triples = [((dt_1, ds_1), (dt_2, ds_2), val)  for ((dt_1, ds_1), (dt_2, ds_2), val) in triples  if sorted((dt_1, dt_2)) == sorted(data_types_pair)]
    vals = [val  for ((dt_1, ds_1), (dt_2, ds_2), val) in triples  if sorted((dt_1, dt_2)) == sorted(data_types_pair)]
    info = [*sorted(data_types_pair), stats(vals)]
    dt_stats[tuple(sorted(data_types_pair))] = stats(vals)
    print(info)
