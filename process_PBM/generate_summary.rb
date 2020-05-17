# standard normal distribution quantiles
quantiles = {0.05 => 1.64, 0.01 => 2.34, 0.005 => 2.57, 0.001 => 3.08}
quantiles_order = quantiles.keys.sort.reverse

quantiles_header = quantiles_order.map{|quantile, z_score_thr|
  z_score_thr = quantiles[quantile]
  "q=#{quantile}(z>#{z_score_thr})"
}
header = ['TF', *quantiles_header, 'dataset', 'correlation', 'correlation_zscored']

motif_qualities = {}
if File.exist?('results/motif_qualities_zscored.tsv')
  motif_qualities_zscored = File.readlines('results/motif_qualities_zscored.tsv').drop(1).map{|l|
    chip, correlation = l.chomp.split("\t")
    [chip, Float(correlation)]
  }.to_h
end


motif_qualities = {}
if File.exist?('results/motif_qualities.tsv')
  motif_qualities = File.readlines('results/motif_qualities.tsv').drop(1).map{|l|
    chip, correlation = l.chomp.split("\t")
    [chip, Float(correlation)]
  }.to_h
end

chip_infos = Dir.glob('results/seq_zscore/*.tsv').map{|fn|
  basename = File.basename(fn, ".tsv")
  tf = basename.split("_").last
  zscores = File.readlines(fn).map(&:chomp).reject(&:empty?).map{|l|
    Float(l.chomp.split("\t").last)
  }
  head_sizes = quantiles_order.map{|quantile|
    z_score_thr = quantiles[quantile]
    zscores.count{|zscore| zscore >= z_score_thr }
  }
  {tf:tf, head_sizes: head_sizes, basename: basename, logo: "<img src='logo/#{basename}.png' />", correlation: motif_qualities[basename], correlation_zscored: motif_qualities_zscored[basename]}
}

File.open('results/head_sizes.html', 'w'){|fw|
  fw.puts <<-EOS
    <html><head>
    <link rel="stylesheet" href="websrc/theme.default.css">
    <script type="text/javascript" src="websrc/jquery-3.5.1.min.js"></script>
    <script type="text/javascript" src="websrc/jquery.tablesorter.js"></script>
    <script type="text/javascript" src="websrc/jquery.tablesorter.widgets.js"></script>
    </head><body>
  EOS

  fw.puts '<table class="tablesorter"><thead><tr>'
  fw.puts (header + ['logo']).map{|hdr| "<th>#{hdr}</th>" }.join
  fw.puts '</tr></thead><tbody>'
  chip_infos.each{|info|
    fw.puts '<tr>'
    fw.puts info.values_at(:tf, :head_sizes, :basename, :correlation, :correlation_zscored, :logo).flatten.map{|hdr| "<td>#{hdr}</td>" }.join
    fw.puts '</tr>'
  }
  fw.puts '</tbody></table>'
  fw.puts <<-EOS
    <script>
    $(function() {
      $(".tablesorter").tablesorter({ sortList: [[0,0]] })
    });
    </script>
    </body></html>
    EOS
}

File.open('results/head_sizes.tsv', 'w'){|fw|
  fw.puts header.join("\t")
  chip_infos.each{|info|
    fw.puts info.values_at(:tf, :head_sizes, :basename, :correlation, :correlation_zscored).flatten.join("\t")
  }
}
