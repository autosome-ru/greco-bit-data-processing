def read_matrix(fn, sep: "\t")
  lns = File.readlines(fn)
  lns.each(&:chomp!)
  lns.map!{|l| l.split(sep) }
  col_names = lns.first.drop(1)
  row_names = lns.drop(1).map(&:first)
  col_indices = col_names.each_with_index.sort.map(&:last)
  row_indices = row_names.each_with_index.sort.map(&:last)
  matrix = lns.drop(1).map{|row|
    row.drop(1).map{|x| Float(x) }.values_at(*col_indices)
  }.values_at(*row_indices)
  {matrix: matrix, row_names: row_names.values_at(*row_indices), col_names: col_names.values_at(*col_indices)}
end

def store_matrix(fn, matrix_info, sep: "\t")
  File.open(fn, 'w'){|fw|
    fw.puts([nil, *matrix_info[:col_names]].join(sep))
    matrix_info[:row_names].zip(matrix_info[:matrix]).each{|row_name, row|
      fw.puts [row_name, *row].join(sep)
    }
  }
end

def pearson(xs,ys)
  raise 'Non-matching vector lengths'  unless xs.length == ys.length
  n = xs.length

  sumx = xs.sum(0.0)
  sumy = ys.sum(0.0)

  sumxSq = xs.map{|v| v**2 }.sum(0.0)
  sumySq = ys.map{|v| v**2 }.sum(0.0)

  pSum = xs.zip(ys).map{|x,y| x * y }.sum(0.0)

  # Calculate Pearson score
  num = pSum - (sumx * sumy / n)
  den = ((sumxSq - (sumx**2) / n) * (sumySq - (sumy**2) / n)) ** 0.5
  (den == 0) ? 0 : num / den
end

def upper_triangle_flattened(matrix)
  matrix.each_with_index.flat_map{|row, row_idx|
    row.each_with_index.map{|val, col_idx|
      [row_idx, col_idx, val]
    }
  }.select{|row_idx, col_idx, val| row_idx < col_idx }.map(&:last)
end

# # normalize matrices
# store_matrix('data/ilya_matrix.tsv', read_matrix('data/ilya_matrix.csv', sep: ','), sep: "\t")
# store_matrix('data/jan_matrix.tsv', read_matrix('data/jan_matrix.csv', sep: ','), sep: "\t")

ilya_matrix = read_matrix('data/ilya_matrix.tsv')[:matrix] # similarities
jan_matrix = read_matrix('data/jan_matrix.tsv')[:matrix].map{|row| row.map{|dist| (2 - dist) / 2.0 } } # dist --> similarity
ilya_vals = upper_triangle_flattened(ilya_matrix)
jan_vals = upper_triangle_flattened(jan_matrix)

ilya_ranks = ilya_vals.each_with_index.sort.reverse.each_with_index.sort_by{|(val, orig_idx), rank| orig_idx }.map{|(val, orig_idx), rank| rank }
jan_ranks = jan_vals.each_with_index.sort.reverse.each_with_index.sort_by{|(val, orig_idx), rank| orig_idx }.map{|(val, orig_idx), rank| rank }

pearson(ilya_ranks, jan_ranks)
pearson(* ilya_vals.map{|x| Math.log10(x) }.zip(jan_vals).select{|v_ilya, v_jan| true  }.transpose)
