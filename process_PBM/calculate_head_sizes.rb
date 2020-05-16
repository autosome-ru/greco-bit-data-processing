# standard normal distribution quantiles
quantiles = {0.05 => 1.64, 0.01 => 2.34, 0.005 => 2.57, 0.001 => 3.08}
quantiles_order = quantiles.keys.sort.reverse

quantiles_header = quantiles_order.map{|quantile, z_score_thr|
  z_score_thr = quantiles[quantile]
  "q=#{quantile}(z>#{z_score_thr})"
}
header = ['TF', *quantiles_header, 'dataset']

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
  {tf:tf, head_sizes: head_sizes, basename: basename, logo: "<img src='logo/#{basename}.png' />"}
}

File.open('results/head_sizes.html', 'w'){|fw|
  fw.puts <<-EOS
    <html><head>
    <link rel="stylesheet" href="../websrc/tablesorter-master/css/theme.default.css">
    <script type="text/javascript" src="../websrc/jquery-3.5.1.min.js"></script>
    <script type="text/javascript" src="../websrc/tablesorter-master/js/jquery.tablesorter.js"></script>
    <script type="text/javascript" src="../websrc/tablesorter-master/js/jquery.tablesorter.widgets.js"></script>
    </head><body>
  EOS

  fw.puts '<table class="tablesorter"><thead><tr>'
  fw.puts (header + ['logo']).map{|hdr| "<th>#{hdr}</th>" }.join
  fw.puts '</tr></thead><tbody>'
  chip_infos.each{|info|
    fw.puts '<tr>'
    fw.puts info.values_at(:tf, :head_sizes, :basename, :logo).flatten.map{|hdr| "<td>#{hdr}</td>" }.join
    fw.puts '</tr>'
  }
  fw.puts '</tbody></table>'
  fw.puts <<-EOS
    <script>
    $(function() {
      $(".tablesorter").tablesorter();
    });
    </script>
    </body></html>
    EOS
}

File.open('results/head_sizes.tsv', 'w'){|fw|
  fw.puts header.join("\t")
  chip_infos.each{|info|
    fw.puts info.values_at(:tf, :head_sizes, :basename).flatten.join("\t")
  }
}

