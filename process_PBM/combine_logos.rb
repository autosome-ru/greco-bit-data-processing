def read_table(fn)
  lines = File.readlines(fn).drop(1).map{|l|
    tf, *quantiles, dataset = l.chomp.split("\t")
    {tf: tf, quantiles: quantiles, dataset: dataset}
  }
end

def subfolder_names(folder)
  Dir.glob(File.join(folder,'*')).select{|fn| File.directory?(fn) }.map{|fn| File.basename(fn) }
end

def file_names(folder)
  Dir.glob(File.join(folder,'*')).select{|fn| File.file?(fn) }.map{|fn| File.basename(fn) }
end


quantile_infos = read_table('results_q0.05_8-15_flat_log_simple_discard-flagged/zscore_quantiles.tsv')
quantiles_header = File.readlines('results_q0.05_8-15_flat_log_simple_discard-flagged/zscore_quantiles.tsv').first.chomp.split("\t")[1...-1]

datasets = quantile_infos.map{|x| x[:dataset] }
tf_by_dataset = quantile_infos.map{|info| info.values_at(:dataset, :tf) }.to_h
quantiles_by_dataset = quantile_infos.map{|info| info.values_at(:dataset, :quantiles) }.to_h

chip_stages = ['raw_chips', 'quantile_normalized_chips', 'spatial_detrended_chips', 'sd_qn_chips', 'zscored_chips',]
metrics_names = ['ROC', 'PR', 'ROCLOG', 'PRLOG', 'ASIS', 'EXP', 'LOG',]
metrics = [
  'results_q0.05_8-15_flat_log_simple_discard-flagged',
  'results_top1000_15-8_single_log_simple_discard-flagged',
  'Dimont_results/basic',
  'Dimont_results/detrended',
].flat_map{|results_folder|
  chip_stages.flat_map{|chip_stage|
    metrics_names.flat_map{|metrics_name|
      File.readlines("#{results_folder}/motif_metrics/#{chip_stage}/motif_metrics_#{metrics_name}.tsv").drop(1).map{|l|
        dataset, val = l.chomp.split("\t")
        {chip_stage: chip_stage, metrics: metrics_name, dataset: dataset, value: Float(val)}
      }
    }
  }
}.group_by{|info| info[:chip_stage] }.transform_values{|stage_group|
  stage_group.group_by{|info|
    info[:metrics]
  }.transform_values{|metrics_group|
      metrics_group.map{|info| info.values_at(:dataset, :value) }.to_h
  }
}

web_sources_url = 'websrc'
File.open('results/compilation.html', 'w') do |fw|
  fw.puts <<-EOS
    <html><head>
    <link rel="stylesheet" href="#{web_sources_url}/theme.default.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/css/widget.grouping.min.css">
    <script type="text/javascript" src="#{web_sources_url}/jquery-3.5.1.min.js"></script>
    <script type="text/javascript" src="#{web_sources_url}/jquery.tablesorter.js"></script>
    <script type="text/javascript" src="#{web_sources_url}/jquery.tablesorter.widgets.js"></script>
    <script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/js/widgets/widget-grouping.min.js"></script>
    <style>

.metrics-group {
  border-left: 2px solid black;
  border-right: 2px solid black;
  padding: 2px 10px;
}
tr.group-header td {
  background: lightgray;
  padding: 20px;
}
tr.group-header td .group-name {
  margin-left: 100px;
}
td.group-name {
  text-transform: uppercase;
  font-weight: bold;
}
tr.group-header td {
  text-transform: uppercase;
}
.group-count {
  color: #999;
}
.group-hidden {
  display: none;
}
.group-header, .group-header td {
  user-select: none;
  -moz-user-select: none;
}
/* collapsed arrow */
tr.group-header td {
  height:35px;
}
tr.group-header td i {
  display: inline-block;
  width: 0;
  height: 0;
  border-top: 4px solid transparent;
  border-bottom: 4px solid #888;
  border-right: 4px solid #888;
  border-left: 4px solid transparent;
  margin-right: 7px;
  user-select: none;
  -moz-user-select: none;
}
tr.group-header.collapsed td i {
  border-top: 5px solid transparent;
  border-bottom: 5px solid transparent;
  border-left: 5px solid #888;
  border-right: 0;
  margin-right: 10px;
}
/*
tr.logo-flat td { background-color: lightblue; }
tr.logo-single td { background-color: lightgreen; }
tr.logo-dimont_basic td { background-color: pink; }
tr.logo-dimont_detrended td { background-color: lightcoral; }
*/
    </style>
    </head><body>
  EOS

  header = [
    {name:'tf', class: 'group-text', rowspan: 2},
    {name:'chip_type', class: 'group-text', rowspan: 2},
    {name:'dataset', class: 'group-text', rowspan: 2},
    {name:'logo_type', class: 'group-text', rowspan: 2},
    {name:'logo', class: 'group-false sorter-false', rowspan:2},
    *chip_stages.flat_map{|stage| {name: stage, class: 'group-false metrics-group', colspan: metrics_names.size} },
    *quantiles_header.map{|col_name| {name: col_name, class: 'group-false', rowspan: 2} },
  ]
  header_2 = chip_stages.flat_map{|stage| metrics_names.map{|metrics_name| {name: metrics_name, class: 'group-false'} } }

  fw.puts '<table class="tablesorter"><thead>'
  fw.puts '<tr>' + header.map{|info| "<th class='#{info[:class]}' rowspan='#{info[:rowspan] || 1}' colspan='#{info[:colspan] || 1}' >#{info[:name]}</th>" }.join + '</tr>'
  fw.puts '<tr>' + header_2.map{|info| "<th class='#{info[:class]}' rowspan='#{info[:rowspan] || 1}' colspan='#{info[:colspan] || 1}' >#{info[:name]}</th>" }.join + '</tr>'
  fw.puts '</thead><tbody>'
  datasets.each_with_index{|dataset, idx|
    tf = tf_by_dataset[dataset]
    quantiles = quantiles_by_dataset[dataset]
    logos = [
      {logo_type: 'flat', src: "../results_q0.05_8-15_flat_log_simple_discard-flagged/logo/#{dataset}.png"},
      {logo_type: 'single', src: "../results_top1000_15-8_single_log_simple_discard-flagged/logo/#{dataset}.png"}
    ]
    logos += Dir.glob("Dimont_results/basic/logo/#{dataset}*.png").map{|img_fn|
      {logo_type: 'dimont_basic', src: '../Dimont_results/basic/logo/' + File.basename(img_fn) }
    }
    logos += Dir.glob("Dimont_results/detrended/logo/#{dataset}*.png").map{|img_fn|
      {logo_type: 'dimont_detrended', src: '../Dimont_results/detrended/logo/' + File.basename(img_fn)}
    }
    logos.each{|logo_info|
      logo_name = File.basename(logo_info[:src], '.png')
      fw.puts "<tr class='logo-#{logo_info[:logo_type]}'>"
      row = [
        tf,
        dataset.split('_')[3],
        dataset,
        logo_info[:logo_type],
        "<img src='#{logo_info[:src]}' />",
        *chip_stages.flat_map{|stage|
          metrics_names.map{|metrics_name|
            metrics[stage][metrics_name][dataset].round(3)
          }
        },
        *quantiles,
      ]
      fw.puts row.map{|hdr| "<td>#{hdr}</td>" }.join
      fw.puts '</tr>'
    }
  }
  fw.puts '</tbody></table>'
  fw.puts <<-EOS
    <script>
    tf_by_dataset = function(dataset) {
      let chunks = dataset.split('_');
      return chunks[6].split('.')[0]
    }
    chip_type = function(dataset) {
      let chunks = dataset.split('_');
      return chunks[3]
    }
    
    $(function() {
      $(".tablesorter").tablesorter({
        sortList: [[2,0],],
        widgets:['group'],
        widgetOptions: {
          group_collapsible : true, 
          group_enforceSort : true, // only apply group_forceColumn when a sort is applied to the table
          group_formatter   : function(txt, col, table, c, wo, data) { return txt; },
          group_callback    : function($cell, $rows, column, table) {
            $cell.find('.group-count').remove();
            if (column == 2) {
              // callback allowing modification of the group header labels
              // $cell = current table cell (containing group header cells ".group-name" & ".group-count"
              // $rows = all of the table rows for the current group; table = current table (DOM)
              // column = current column being sorted/grouped
              let dataset = $cell.find('.group-name').text();
              $cell.html('<i></i><span class="group-name">' + tf_by_dataset(dataset) + ':</b></span><em>' + dataset + '</em>');
            } else {
              let group_name = $cell.find('.group-name').text();
              $cell.html('<i></i><span class="group-name">' + group_name + '</span>')
            }
          },
        },
        textSorter : {
          2 : function(a, b, direction, column, table) {
            return $.tablesorter.sortNatural(tf_by_dataset(a) + ' ' + chip_type(a), tf_by_dataset(b) + ' ' + chip_type(b), direction, column, table)
          },
        }
      });
    });
    </script>
    </body></html>
    EOS
end
