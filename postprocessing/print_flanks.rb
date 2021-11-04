require_relative '../process_reads_HTS_SMS_AFS/hts'
require_relative '../shared/bin/name_sample_afs'
require_relative '../process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative '../process_reads_HTS_SMS_AFS/sms_published'

hts_metadata = Selex::SampleMetadata.each_in_file('source_data_meta/HTS/HTS.tsv').to_a
afs_metadata = Affiseq::SampleMetadata.each_in_file('source_data_meta/AFS/AFS.tsv').to_a
sms_unpublished_metadata = SMSUnpublished::SampleMetadata.each_in_file('source_data_meta/SMS/unpublished/SMS.tsv').to_a
sms_published_metadata = SMSPublished::SampleMetadata.each_in_file('source_data_meta/SMS/published/SMS_published.tsv').to_a

def print_flanks(metadata, output_stream: $stdout, barcode_proc:)
  metadata.each{|sample_metadata|
    barcode = barcode_proc.call(sample_metadata)
    flank_5 = (sample_metadata.adapter_5 + barcode[:flank_5])
    flank_3 = (barcode[:flank_3] + sample_metadata.adapter_3)
    # info = [sample_metadata.experiment_id, flank_5, flank_3]
    output_stream.puts "> #{sample_metadata.tf}:#{sample_metadata.experiment_id}:5-prime\n#{flank_5}"
    output_stream.puts "> #{sample_metadata.tf}:#{sample_metadata.experiment_id}:3-prime\n#{flank_3}"
  }
end

File.open('HTS_flanks.fa', 'w') {|fw|
  print_flanks(hts_metadata, output_stream: fw, barcode_proc: ->(sample_metadata){ sample_metadata.barcode })
}

File.open('AFS_flanks.fa', 'w') {|fw|
  print_flanks(afs_metadata, output_stream: fw, barcode_proc: ->(sample_metadata){ sample_metadata.barcode })
}

File.open('SMS_unpublished_flanks.fa', 'w') {|fw|
  barcodes_fn = "source_data_meta/SMS/unpublished/smileseq_barcode_file.txt"
  barcodes = SMSUnpublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ sample_metadata.barcode_change || barcodes[sample_metadata.barcode_index] }
  print_flanks(sms_unpublished_metadata, output_stream: fw, barcode_proc: barcode_proc)
}

File.open('SMS_published_flanks.fa', 'w') {|fw|
  barcodes_fn = "source_data_meta/SMS/published/Barcode_sequences.txt"
  barcodes = SMSPublished.read_barcodes(barcodes_fn)
  barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }
  print_flanks(sms_published_metadata, output_stream: fw, barcode_proc: barcode_proc)
}
