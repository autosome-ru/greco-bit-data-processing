require 'zlib'

def open_fastq_read(filename, &block)
  if filename.end_with?('.gz')
    Zlib::GzipReader.open(filename, &block)
  else
    File.open(filename, &block)
  end
end

def open_fastq_write(filename, &block)
  if filename.end_with?('.gz')
    Zlib::GzipWriter.open(filename, &block)
  else
    File.open(filename, 'w', &block)
  end
end

# @NS500310:244:HCKN5BGXB:1:11101:12600:1100 2:N:0:TTGCTGAT+GGAGGCTG
# https://support.illumina.com/content/dam/illumina-support/documents/documentation/software_documentation/bcl2fastq/bcl2fastq2-v2-20-software-guide-15051736-03.pdf
# @Instrument:RunID:FlowCellID:Lane:Tile:X:Y[:UMI] Read:Filter:0:IndexSequence or SampleNumber
FastqRecord = Struct.new(:instrument, :run_id, :flow_cell_id, :lane, :tile, :x, :y, :umi, :read, :filter, :index_sequence, :sequence, :qualities, keyword_init: true) do
  def self.parse_header(str)
    raise unless str[0] == '@'
    str.chomp!
    parts = str[1..-1].split(' ')
    instrument, run_id, flow_cell_id, lane, tile, x, y, umi = parts[0].split(':')
    read, filter, _, index_sequence = parts[1].split(':')
    {
      instrument: instrument, run_id: run_id, flow_cell_id: flow_cell_id, lane: lane, tile: tile, x: Integer(x), y: Integer(y), umi: umi,
      read: read, filter: filter, index_sequence: index_sequence,
    }
  end

  def self.each_in_stream(stream)
    return enum_for(:each_in_stream, stream)  unless block_given?
    stream.each_line.each_slice(4).map{|lines|
      lines.each(&:chomp!)
      header_info = self.parse_header(lines[0])
      sequence = lines[1]
      qualities = lines[3]
      info = {**header_info, sequence: lines[1], qualities: qualities}
      yield self.new(**info)
    }
  end

  def self.each_in_file(filename, &block)
    return enum_for(:each_in_file, filename)  unless block_given?
    open_fastq_read(filename){|f| self.each_in_stream(f, &block) }
  end

  def self.store_to_file(filename, reads)
    open_fastq_write(filename){|fw| reads.each{|read| fw.puts(read) } }
  end

  def to_s
    part_1 = [instrument, run_id, flow_cell_id, lane, tile, x, y] + (umi ? [umi] : [])
    part_2 = [read, filter, 0, index_sequence]
    ['@' + part_1.join(':') + ' ' + part_2.join(':'), sequence, '+', qualities].join("\n")
  end
end

def num_reads_in_fastq(filename)
  open_fastq_read(filename){|f|
    f.each_line.count / 4
  }
end
