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
  return cached_result  if cached_result = load_from_spo_cache(filename, 'num_peaks')
  result = File.readlines(filename).map(&:strip).reject{|l| l.start_with?('#') }.reject(&:empty?).count
  store_to_spo_cache(filename, 'num_peaks', result)
  result
rescue
  nil
end
