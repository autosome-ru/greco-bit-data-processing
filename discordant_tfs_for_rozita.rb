require 'json'
require_relative 'shared/lib/utils'
require_relative 'shared/lib/index_by'
require_relative 'process_peaks_CHS_AFS/chipseq_metadata'
require_relative 'process_peaks_CHS_AFS/experiment_info_chs'
require_relative 'shared/lib/affiseq_metadata'

def get_ds_sizes_by_tf_sliced(tf_ds_sizes)
  ds_sizes_by_tf_sliced = tf_ds_sizes.map{|tf, exp_ids, ds_sizes|
    resulting_sizes = ds_sizes.group_by{|info|
      info[:extended_exp_id]
    }.transform_values{|infos|
      infos.map{|info|
        info.values_at(:slice_type, :num_peaks)
      }.tap{|kv_pairs|
        raise  unless kv_pairs.map(&:first).size == kv_pairs.map(&:first).uniq.size
      }.to_h
    }
    
    missing_exps = exp_ids - resulting_sizes.keys
    missing_exps_hsh = missing_exps.map{|exp| [exp, {}] }.to_h
    [tf, missing_exps_hsh.merge(resulting_sizes)]
  }.to_h
end


def calc_total_sizes(ds_sizes_by_tf_sliced)
  ds_sizes_by_tf_sliced.transform_values{|ds_sizes|
    ds_sizes.transform_values{|size_by_slice_type|
      ["Train", "Val"].map{|slice_type|
        size_by_slice_type.fetch(slice_type, 0)
      }.sum
    }.sort_by{|ds, sz| -sz }.to_h
  }
end

def get_tf_order(ds_total_sizes_by_tf)
  ds_total_sizes_by_tf.transform_values{|ds_total_sizes|
    mn, mx = ds_total_sizes.values.minmax
    rate = mx == 0 ? 1.0 : mx.to_f / mn.to_f
    [rate, mx]
  }.sort_by{|k,(rate,mx)|
    [rate, mx]
  }.reverse
end

def get_final_meta(filename, exp_type)
  File.open(filename){|f|
    f.each_line.lazy.map{|l|
      data = JSON.parse(l)
      data["experiment_meta"].delete("plasmid")
      data
    }.select{|d|
       d["experiment_type"] == exp_type
    }.select{|d|
      File.extname(d["dataset_name"]) == ".peaks"
    }.to_a
  }
end

def write_dataset_sizes(filename, ds_total_sizes_by_tf, tf_order)
  max_num_datasets = ds_total_sizes_by_tf.values.map(&:size).max
  File.open(filename, 'w'){|fw|
    fw.puts(["TF", "Max/Min num_peaks ratio", "Max num_peaks", *max_num_datasets.times.map{|i| ["Dataset #{i+1}", "Num peaks #{i+1}"] }].join("\t"))
    tf_order.each{|tf, (rate, mx)|
      info = [tf, rate.round(1), mx, ds_total_sizes_by_tf[tf].to_a.flatten]
      fw.puts info.join("\t")
    }
  }
end

def write_dataset_sliced_sizes(filename, ds_sizes_by_tf_sliced, tf_order)
  File.write(filename, tf_order.map{|tf| [tf, ds_sizes_by_tf_sliced[tf]] }.map{|info| info.join("\t") }.join("\n"))
end

FINAL_METADATA_FN = 'run_benchmarks_release_7/metadata_release_7a.json'

#############  CHS  #################

resulting_datasets = get_final_meta(FINAL_METADATA_FN, "CHS")
resulting_datasets_by_tf = resulting_datasets.group_by{|d| d["tf"] }; nil

metadata = Chipseq::SampleMetadata.each_in_file('source_data_meta/CHS/CHS.tsv').select{|m|
  m.chip_or_input == 'CHIP'
  # true
}.to_a
metadata_by_tf = metadata.group_by(&:gene_id)

experiment_metrics = [
  "source_data_meta/CHS/metrics_by_exp.tsv",
  "source_data_meta/CHS/metrics_by_exp_chipseq_feb2021.tsv",
  "source_data_meta/CHS/metrics_by_exp_chipseq_jun2021.tsv"
].flat_map{|metrics_fn|
  ExperimentInfoCHS.each_from_file(metrics_fn).reject{|info|
    info.type == 'control'
  }.to_a
}
  
experiment_metrics_by_plate_id = experiment_metrics.group_by{|info| info.normalized_id.split('-').first }

exp_ids_by_tf = metadata_by_tf.transform_values{|meta_ds|
  meta_ds.map{|m|
    exp_id = m.experiment_id
    norm_id = m.normalized_id
    if experiment_metrics_by_plate_id.has_key?(norm_id)
      replicas = experiment_metrics_by_plate_id[norm_id].map(&:replica)
    else
      # p norm_id
      replicas = [nil]
    end
    replicas.map{|replica| [exp_id, replica].compact.join(".") }
  }.flatten
}; nil

tf_ds_sizes = exp_ids_by_tf.map{|tf, extended_exp_ids|
  ds = resulting_datasets_by_tf[tf] || []
  ds_sizes = ds.map{|d|
    extended_exp_id = [ d["experiment_id"], d["experiment_info"]["replica"] ].compact.join(".")
    num_peaks = d["stats"]["num_peaks"]
    {extended_exp_id: extended_exp_id, slice_type: d["slice_type"], num_peaks: num_peaks}
  }
  [tf, extended_exp_ids, ds_sizes]
}

ds_sizes_by_tf_sliced = get_ds_sizes_by_tf_sliced(tf_ds_sizes)
ds_total_sizes_by_tf = calc_total_sizes(ds_sizes_by_tf_sliced)
tf_order = get_tf_order(ds_total_sizes_by_tf)

write_dataset_sizes("chipseq_dataset_sizes.tsv", ds_total_sizes_by_tf, tf_order)
write_dataset_sliced_sizes("chipseq_dataset_sizes_detailed.txt", ds_sizes_by_tf_sliced, tf_order)

#############  AFS  #################

resulting_datasets = get_final_meta(FINAL_METADATA_FN, "AFS")
resulting_datasets_by_tf = resulting_datasets.group_by{|d| d["tf"] }; nil

metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a;
metadata_by_tf = metadata.group_by(&:gene_name)

exp_ids_by_tf = metadata_by_tf.transform_values{|meta_ds|
  meta_ds.map(&:experiment_id)
}; nil


tf_ds_sizes = exp_ids_by_tf.map{|tf, exp_ids|
  ds = resulting_datasets_by_tf[tf] || []
  ds_sizes = ds.map{|d|
    extended_exp_id = d["experiment_id"]
    num_peaks = d["stats"]["num_peaks"]
    {extended_exp_id: extended_exp_id, slice_type: d["slice_type"], num_peaks: num_peaks}
  }
  [tf, exp_ids, ds_sizes]
}

ds_sizes_by_tf_sliced = get_ds_sizes_by_tf_sliced(tf_ds_sizes)
ds_total_sizes_by_tf = calc_total_sizes(ds_sizes_by_tf_sliced)
tf_order = get_tf_order(ds_total_sizes_by_tf)

write_dataset_sizes("affiseq_dataset_sizes.tsv", ds_total_sizes_by_tf, tf_order)
write_dataset_sliced_sizes("affiseq_dataset_sizes_detailed.txt", ds_sizes_by_tf_sliced, tf_order)
