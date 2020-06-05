require 'set'
require 'fileutils'

#CHROM  START END abs_summit  pileup  -log10(pvalue)  fold_enrichment -log10(qvalue)  name
PeakInfo = Struct.new(:chr, :start, :stop, :abs_summit, :pileup, :neg_log10_pval, :fold_enrichment, :neg_log10_qval, :name) do
  HEADER = ['CHROM', 'START', 'END', 'abs_summit', 'pileup', '-log10(pvalue)', 'fold_enrichment', '-log10(qvalue)', 'name',]
  def self.from_string(str)
    chr, start, stop, abs_summit, pileup, neg_log10_pval, fold_enrichment, neg_log10_qval, name = str.chomp.split("\t")
    self.new(chr, Integer(start), Integer(stop), Integer(abs_summit), Integer(pileup), Float(neg_log10_pval), Float(fold_enrichment), Float(neg_log10_qval), name)
  end

  def self.each_in_stream(stream, has_header: true, &block)
    return enum_for(:each_in_stream, stream, has_header: has_header)  unless block_given?
    stream.readline  if has_header # skip header
    stream.each_line{|l|
      yield self.from_string(l)
    }
  end

  def self.each_in_file(filename, has_header: true, &block)
    return enum_for(:each_in_file, filename, has_header: has_header)  unless block_given?
    File.open(filename){|f|
      self.each_in_stream(f, has_header: has_header, &block)
    }
  end

  def to_s
    [chr, start, stop, abs_summit, pileup, neg_log10_pval, fold_enrichment, neg_log10_qval, name].join("\t")
  end

  def self.output_to_stream(peaks, stream, has_header: true)
    stream.puts('#' + HEADER.join("\t")) if has_header
    peaks.each{|peak|
      stream.puts(peak)
    }
  end

  def self.store(peaks, filename, has_header: true)
    File.open(filename){|fw|
      self.output_to_stream(peaks, fw, has_header: has_header)
    }
  end
end

TRAIN_CHR = (1..21).step(2).to_set
VALIDATION_CHR = (2..22).step(2).to_set

peaks_fn, train_fn, validation_fn = ARGV.first(3)
FileUtils.mkdir_p(File.dirname(train_fn))
FileUtils.mkdir_p(File.dirname(validation_fn))

peaks = PeakInfo.each_in_file(peaks_fn)

train_peaks = peaks.select{|peak| TRAIN_CHR.include?(peak.chr) }
validation_peaks = peaks.select{|peak| VALIDATION_CHR.include?(peak.chr) }
PeakInfo.store(train_peaks, train_fn, has_header: true)
PeakInfo.store(validation_peaks, validation_fn, has_header: true)
