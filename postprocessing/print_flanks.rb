require_relative 'process_reads_HTS_SMS_AFS/hts'
# require_relative 'shared/lib/affiseq_metadata'

hts_metadata = Selex::SampleMetadata.each_in_file('source_data_meta/HTS/HTS.tsv').to_a
# afs_metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a

def print_flanks(metadata, output_stream: $stdout)
  metadata.each{|sample_metadata|
    barcode = sample_metadata.barcode
    flank_5 = (sample_metadata.adapter_5 + barcode[:flank_5])
    flank_3 = (barcode[:flank_3] + sample_metadata.adapter_3)
    # info = [sample_metadata.experiment_id, flank_5, flank_3]
    output_stream.puts "> #{sample_metadata.gene_name}:#{sample_metadata.experiment_id}:5-prime\n#{flank_5}"
    output_stream.puts "> #{sample_metadata.gene_name}:#{sample_metadata.experiment_id}:3-prime\n#{flank_3}"
  }
end

File.open('HTS_flanks.fa', 'w') {|fw|
  print_flanks(hts_metadata, output_stream: fw)
}
