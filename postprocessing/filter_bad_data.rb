require 'json'

module Enumerable
  def median
    empty? ? nil : sort[size / 2]
  end
  def q75
    empty? ? nil : sort[size * 3 / 4]
  end
end

def unpack_tf_info_metrics(tf_info)
  tf_info.flat_map{|motif, motif_info|
    motif_info.flat_map{|exp_type, experiments_info|
      experiments_info.flat_map{|exp_id, exp_info|
        exp_info.flat_map{|dataset, dataset_info|
          dataset_info.flat_map{|processing_type, processing_type_metrics|
            processing_type_metrics.flat_map{|metric_info|
              metric_name = metric_info['metric_name']
              value = metric_info['value']
              {
                motif: motif, exp_type: exp_type, exp_id: exp_id, dataset: dataset,
                processing_type: processing_type, metric_name: metric_name, value: value,
              }
            }
          }
        }
      }
    }
  }
end

all_metrics = JSON.load_file('metrics_7a+7c.json');nil

roc_checker = ->(v) { v >= 0.55 }
pr_checker = ->(v) { false }
skip_checker = ->(v) { false }

checkers = {
  'CHS' => {
    'Peaks' => {
      'chipseq_pwmeval_ROC' => roc_checker,
      'chipseq_vigg_ROC' => roc_checker,
      'chipseq_centrimo_neglog_evalue' => roc_checker,
      'chipseq_vigg_logROC' => skip_checker,
      'chipseq_centrimo_concentration_30nt' => skip_checker,
    }
  },
  'PBM' => {
    'QNZS' => {
      'pbm_qnzs_roc' => roc_checker,
      # 'pbm_qnzs_pr' => pr_checker,
    },
    'SDQN' => {
      'pbm_sdqn_roc' => roc_checker,
      # 'pbm_sdqn_pr' => pr_checker,
    },
  },
  'AFS.IVT' => {
    'Reads' => {
      # 'affiseq_10_IVT_ROC' => roc_checker,
      'affiseq_25_IVT_ROC' => roc_checker,
      # 'affiseq_50_IVT_ROC' => roc_checker,
    },
    'Peaks' => {
      'affiseq_IVT_pwmeval_ROC' => roc_checker,
      'affiseq_IVT_vigg_ROC' => roc_checker,
      'affiseq_IVT_centrimo_neglog_evalue' => roc_checker,
      'affiseq_IVT_vigg_logROC' => skip_checker,
    },
  },
  'AFS.Lys' => {
    'Reads' => {
      # 'affiseq_10_Lysate_ROC' => roc_checker,
      'affiseq_25_Lysate_ROC' => roc_checker,
      # 'affiseq_50_Lysate_ROC' => roc_checker,
    },
    'Peaks' => {
      'affiseq_Lysate_pwmeval_ROC' => roc_checker,
      'affiseq_Lysate_vigg_ROC' => roc_checker,
      'affiseq_Lysate_centrimo_neglog_evalue' => roc_checker,
      'affiseq_Lysate_vigg_logROC' => skip_checker,
    },
  },
  'HTS.IVT' => {
    'Reads' => {
      # 'selex_10_IVT_ROC' => roc_checker,
      'selex_25_IVT_ROC' => roc_checker,
      # 'selex_50_IVT_ROC' => roc_checker,
    },
  },
  'HTS.Lys' => {
    'Reads' => {
      # 'selex_10_Lysate_ROC' => roc_checker,
      'selex_25_Lysate_ROC' => roc_checker,
      # 'selex_50_Lysate_ROC' => roc_checker,
    },
  },
  'SMS' => {
    'Reads' => {
      # 'smileseq_10_ROC' => roc_checker,
      'smileseq_25_ROC' => roc_checker,
      # 'smileseq_50_ROC' => roc_checker,
    },
  },
}


unpacked_metrics_by_tf = all_metrics.map{|tf, tf_info|
  metrics_unpacked = unpack_tf_info_metrics(tf_info)
  assessed_metrics = metrics_unpacked.map{|info|
    checker = checkers.dig(info[:exp_type], info[:processing_type], info[:metric_name])
    [info, checker]
  }.select{|info, checker|
    checker
  }.map{|info, checker|
    info.merge(check_passed: checker.call(info[:value]))
  }
  [tf, assessed_metrics]
}.to_h;nil

motif_statuses = unpacked_metrics_by_tf.flat_map{|tf, metrics_unpacked| 
  metrics_unpacked.group_by{|info| info[:motif] }.map{|motif, metrics_subset|
    good_motif = metrics_subset.any?{|info| info[:check_passed] }
    {tf: tf, motif: motif, good_motif: good_motif}
  }
};nil  

dataset_statuses = unpacked_metrics_by_tf.flat_map{|tf, metrics_unpacked|
  metric_thresholds = metrics_unpacked.group_by{|info| info[:metric_name] }.map{|metric_name, grp|
    metric_values = grp.map {|info| info[:value] }
    [metric_name, metric_values.q75]
  }.to_h
  metrics_unpacked.group_by{|info| info[:dataset] }.map{|dataset, metrics_subset|
    good_dataset = metrics_subset.any?{|info| info[:check_passed] && (info[:value] > metric_thresholds[ info[:metric_name] ]) }
    {tf: tf, dataset: dataset, good_dataset: good_dataset}
  }
};nil

# another motif-filtering
motif_statuses = unpacked_metrics_by_tf.flat_map{|tf, metrics_unpacked|
  metric_thresholds = metrics_unpacked.group_by{|info| info[:metric_name] }.map{|metric_name, grp|
    metric_values = grp.map {|info| info[:value] }
    [metric_name, metric_values.q75]
  }.to_h
  metrics_unpacked.group_by{|info| info[:motif] }.map{|motif, metrics_subset|
    good_motif = metrics_subset.any?{|info| info[:value] >= metric_thresholds[ info[:metric_name] ] }
    {tf: tf, motif: motif, good_motif: good_motif}
  }
};nil

motif_statuses.size
motif_statuses.select{|motif_status| motif_status[:good_motif] }.size

dataset_statuses.size
dataset_statuses.select{|motif_status| motif_status[:good_dataset] }.size

tf = 'ADNP'
metric_thresholds = unpacked_metrics_by_tf[tf].group_by{|info| info[:metric_name] }.map{|metric_name, grp|
  metric_values = grp.map {|info| info[:value] }
  [metric_name, metric_values.q75]
}.to_h

unpacked_metrics_by_tf[tf].group_by{|info| info[:motif] }.map{|motif, metrics_subset|
  good_motif = metrics_subset.map{|info| info[:value] > metric_thresholds[ info[:metric_name] ] }
  {tf: tf, motif: motif, good_motif: good_motif}
}
