def read_table(fn)
  lines = File.readlines(fn).drop(1).map{|l|
    tf,*quantiles, dataset, correlation = l.chomp.split("\t")
    {tf: tf, quantiles: quantiles, dataset: dataset, correlation: correlation}
  }
end

infos_flat = read_table('results/head_sizes_flat.tsv')
infos_single = read_table('results/head_sizes_single.tsv')

datasets = infos_flat.map{|x| x[:dataset] }
tf_by_dataset = infos_flat.map{|info| info.values_at(:dataset, :tf) }.to_h


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

  header = [{name:'tf', class: 'group-text'}, {name:'chip_type', class: 'group-text'}, {name:'dataset', class: 'group-text'}, {name:'logo_type'}, {name:'logo'}]
  fw.puts '<table class="tablesorter"><thead><tr>'
  fw.puts header.map{|info| "<th class='#{info[:class]}'>#{info[:name]}</th>" }.join
  fw.puts '</tr></thead><tbody>'
  datasets.each_with_index{|dataset, idx|
    tf = tf_by_dataset[dataset]
    logos = [
      {logo_type: 'flat', src: "logo_flat/#{dataset}.png"},
      {logo_type: 'single', src: "logo_single/#{dataset}.png"}
    ]
    logos += Dir.glob("results/logo_dimont_basic/#{dataset}*.png").map{|img_fn|
      {logo_type: 'dimont_basic', src: 'logo_dimont_basic/' + File.basename(img_fn) }
    }
    logos += Dir.glob("results/logo_dimont_detrended/#{dataset}*.png").map{|img_fn|
      {logo_type: 'dimont_detrended', src: 'logo_dimont_detrended/' + File.basename(img_fn)}
    }
    logos.each{|logo_info|
      logo_name = File.basename(logo_info[:src], '.png')
      fw.puts "<tr class='logo-#{logo_info[:logo_type]}'>"
      fw.puts [tf, dataset.split('_')[3], dataset, logo_info[:logo_type]].map{|hdr| "<td>#{hdr}</td>" }.join
      fw.puts "<td><img src='#{logo_info[:src]}' /></td>"
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
            // callback allowing modification of the group header labels
            // $cell = current table cell (containing group header cells ".group-name" & ".group-count"
            // $rows = all of the table rows for the current group; table = current table (DOM)
            // column = current column being sorted/grouped
            let dataset = $cell.find('.group-name').text();
            $cell.html('<i></i><span class="group-name">' + tf_by_dataset(dataset) + ':</b></span><em>' + dataset + '</em>');
            
          },
        },
        textSorter : {
          1 : function(a, b, direction, column, table) {
            return $.tablesorter.sortNatural(tf_by_dataset(a) + ' ' + chip_type(a), tf_by_dataset(b) + ' ' + chip_type(b), direction, column, table)
          },
        }
      });
    });
    </script>
    </body></html>
    EOS
end
