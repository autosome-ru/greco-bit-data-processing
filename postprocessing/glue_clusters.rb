require 'zlib'

sims = nil
Zlib::GzipReader.open('motif_similarities.txt.gz'){|f|
# File.open('motif_similarities.txt'){|f|
  sims = f.map{|l|
    l.chomp!
    m1,m2,sim = l.split("\t")
    [m1.to_sym, m2.to_sym, Float(sim)]
  }
  nil
}

motifs = (sims.map(&:first) + sims.map{|x| x[1] }).uniq
clusters = motifs.map{|x| [x] }
cluster_by_motif = motifs.each_with_index.to_h

SIMILARITY_TO_GLUE = 0.2

sims.select{|m1,m2,sim|
  sim > SIMILARITY_TO_GLUE && (m1.to_s.split('.')[0] != m2.to_s.split('.')[0])
}.each{|m1,m2,sim|
  idx1 = cluster_by_motif[m1]
  idx2 = cluster_by_motif[m2]
  if idx1 != idx2
    clusters[idx1] += clusters[idx2]
    clusters[idx2].each{|motif|
      cluster_by_motif[motif] = idx1
    }
    clusters[idx2] = []
  end
}; nil

clusters = clusters.reject(&:empty?)
clusters = clusters.sort_by(&:size).reverse

$stderr.puts("Cluster sizes:" + clusters.map(&:size).inspect)
clusters.each_with_index{|cluster, idx|
  puts "Cluster #{idx}: " + cluster.join(' ')
}; nil

File.open('clusters.html', 'w') {|fw|

  fw.puts <<-EOS
    <html><head><style>img {max-width: 700px;}</style></head><body>
    <table><thead><tr><th width="100px">Cluster</th><th width="700px">Logo</th><th>Motif</th></tr></thead><tbody>
  EOS

  clusters.each_with_index{|cluster, idx|
    fw.puts "<tr><td style='background-color: gray; height:10px;'></td><td style='background-color: gray; height:10px;'></td><td style='background-color: gray; height:10px;'></td></tr>"
    cluster.each{|motif|
      motif_name = motif.to_s.split('.')[0...-1].join('.') # drop extension
      fw.puts "<tr><td>Cluster #{idx}</td><td><img src='logo/#{motif_name}.png'></td><td>#{motif_name}</td></tr>"
    }
  }
  fw.puts <<-EOS
    </tbody></table>
    </body></html>
  EOS
}
