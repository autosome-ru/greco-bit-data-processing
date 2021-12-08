require_relative 'spo_cache'

def num_reads(filename)
  return nil  if !File.exist?(filename)
  cached_result = load_from_spo_cache(filename, 'num_reads')
  return cached_result  if cached_result
  ext = File.extname(File.basename(filename, '.gz'))
  if ['.fastq', '.fq'].include?(ext)
    result = `./seqkit fq2fa #{filename} -w 0 | fgrep --count '>'`
    result = Integer(result)
    store_to_spo_cache(filename, 'num_reads', result)
    result
  else
    result = `./seqkit seq #{filename} -w 0 | fgrep --count '>'`
    result = Integer(result)
    store_to_spo_cache(filename, 'num_reads', result)
    result
  end
rescue
  nil
end

def num_peaks(filename)
  return nil  if !File.exist?(filename)
  cached_result = load_from_spo_cache(filename, 'num_peaks')
  return cached_result  if cached_result
  result = num_lines_wo_comments(filename)
  store_to_spo_cache(filename, 'num_peaks', result)
  result
rescue
  nil
end

def num_probes(filename)
  return nil  if !File.exist?(filename)
  cached_result = load_from_spo_cache(filename, 'num_probes')
  return cached_result  if cached_result
  result = num_lines_wo_comments(filename)
  store_to_spo_cache(filename, 'num_probes', result)
  result
rescue
  nil
end

def num_good_probes(filename)
  return nil  if !File.exist?(filename)
  cached_result = load_from_spo_cache(filename, 'num_good_probes_v2')
  return cached_result  if cached_result
  result = num_lines_wo_comments(filename){|l| l.split("\t").last == "0" } # `flag` in the last column can be 0 or 1
  store_to_spo_cache(filename, 'num_good_probes_v2', result)
  result
rescue
  nil
end


def num_lines_wo_comments(filename, &block)
  lines = File.readlines(filename).map(&:strip).reject{|l| l.start_with?('#') }.reject(&:empty?)
  lines = lines.select(&block)  if block_given?
  lines.count
end
