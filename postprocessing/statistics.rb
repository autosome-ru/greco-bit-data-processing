def pearson(xs, ys)
  raise 'Sequence lengths differ'  unless xs.length == ys.length
  n = xs.length
  raise 'Empty sequence'  if n == 0
  sum_x = xs.sum(0.0)
  sum_y = ys.sum(0.0)

  sum_xx = xs.map{|v| v**2 }.sum(0.0)
  sum_yy = ys.map{|v| v**2 }.sum(0.0)

  sum_xy = xs.zip(ys).map{|x, y| x*y }.sum(0.0)

  # Calculate Pearson score
  num = n * sum_xy - sum_x * sum_y
  den = ( (n * sum_xx - sum_x ** 2) * (n * sum_yy - sum_y ** 2) ) ** 0.5
  return 0  if den==0
  return num / den
end

class Array
  def mean
    return nil  if empty?
    sum(0.0) / length
  end
  def stddev
    return nil  if length < 2
    m = mean
    (map{|x| (x - m)**2 }.sum(0.0) / (length - 1)) ** 0.5
  end
end

module Enumerable
  def count_uniq(&block)
    each_with_object(Hash.new(0)) {|el, counter| counter[el] += 1 }
  end
end


def zscore(val, mean, std)
  (val - mean).to_f / std
end
