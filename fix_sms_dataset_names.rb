require_relative 'process_reads_HTS_SMS_AFS/reads_processing'
require_relative 'process_reads_HTS_SMS_AFS/sms_unpublished'
require_relative 'shared/lib/index_by'
require_relative 'shared/lib/match_metadata'

module ReadsProcessing
  class DatasetNaming
    def basename_fixed(sample_metadata, cycle:)
      barcode = barcode_proc.call(sample_metadata)
      flank_5 = (sample_metadata.adapter_5 + barcode[:flank_5])[-20,20]
      flank_3 = (barcode[:flank_3] + sample_metadata.adapter_3)[0,20]
      procedure = 'Reads'
      exp_id = sample_metadata.experiment_id.split('-')[0,2].join('-')
      if cycle # AFS/HTS
        "#{sample_metadata.tf}.#{sample_metadata.construct_type}@#{sample_metadata.experiment_type}@#{exp_id}.C#{cycle}.5#{flank_5}.3#{flank_3}@#{procedure}"
      else # SMS
        "#{sample_metadata.tf}.#{sample_metadata.construct_type}@#{sample_metadata.experiment_type}@#{exp_id}.5#{flank_5}.3#{flank_3}@#{procedure}"
      end
    end
    def find_train_filename(sample_metadata, cycle:)
      Dir.glob("#{results_folder}/Train_reads/#{basename(sample_metadata, cycle: cycle)}.*.Train.fastq.gz").first \
        || Dir.glob("#{results_folder}/Train_reads/#{basename_fixed(sample_metadata, cycle: cycle)}.*.Train.fastq.gz").first
    end
    def find_validation_filename(sample_metadata, cycle:)
      Dir.glob("#{results_folder}/Val_reads/#{basename(sample_metadata, cycle: cycle)}.*.Val.fastq.gz").first \
        || Dir.glob("#{results_folder}/Val_reads/#{basename_fixed(sample_metadata, cycle: cycle)}.*.Val.fastq.gz").first
    end
  end
end

metadata_fn = "source_data_meta/SMS/unpublished/SMS.tsv"
barcodes_fn = "source_data_meta/SMS/unpublished/smileseq_barcode_file.txt"
samples_glob = "source_data/SMS/reads/unpublished/*.fastq"
results_folder = "source_data_prepared/SMS/reads"

barcodes = SMSUnpublished.read_barcodes(barcodes_fn)
barcode_proc = ->(sample_metadata){ barcodes[sample_metadata.barcode_index] }

samples = Dir.glob(samples_glob).map{|fn| SMSUnpublished::Sample.from_filename(fn) }
metadata = SMSUnpublished::SampleMetadata.each_in_file(metadata_fn).to_a
sample_key = ->(sample){ [sample.experiment_id.split('-')[0,2].join('-'), sample.barcode_index, sample.sequencing_id] }
meta_key = ->(meta){ [meta.experiment_id.split('-')[0,2].join('-'), meta.barcode_index, meta.ssid] }
samples = unique_samples_by(samples, &sample_key)
metadata = unique_metadata_by(metadata, &meta_key)
sample_triples = left_join_by(samples, metadata,
                            key_proc_1: sample_key,
                            key_proc_2: meta_key)

ReadsProcessing.verify_sample_triples!(SMSUnpublished, sample_triples)

ds_naming = ReadsProcessing::DatasetNaming.new(results_folder, barcode_proc: barcode_proc)

mappings = sample_triples.flat_map{|(experiment_id, bc, ssid), sample, sample_metadata|
  train_fn = ds_naming.find_train_filename(sample_metadata, cycle: sample.cycle)
  val_fn = ds_naming.find_validation_filename(sample_metadata, cycle: sample.cycle)
  new_train_fn = train_fn.sub(/@SMS@#{sample.experiment_id}\./, "@SMS@#{sample_metadata.experiment_id}.")
  new_val_fn   =   val_fn.sub(/@SMS@#{sample.experiment_id}\./, "@SMS@#{sample_metadata.experiment_id}.")
  [
    [train_fn, new_train_fn],
    [val_fn, new_val_fn],
  ]  
}.select{|src, dst| src != dst }

mappings.each{|src, dst|
  raise  if File.exist?(src) && File.exist?(dst)
  FileUtils.mv(src, dst)  if File.exist?(src) && !File.exist?(dst)
}; nil

basename_mappings = mappings.map{|src, dst| [File.basename(src), File.basename(dst)] }.to_h

['release_6_metrics/reads_0.1.tsv', 'release_6_metrics/reads_0.5.tsv', 'release_6_metrics/formatted_reads_0.1.tsv', 'release_6_metrics/formatted_reads_0.5.tsv'].each{|fn|
  new_data = File.readlines(fn).map{|l|
    dataset, motif, value = l.chomp.split("\t", 3)
    info = [basename_mappings.fetch(dataset, dataset), motif, value]
    info.join("\t")
  }.join("\n")
  File.write(fn, new_data)
}

ReadsProcessing.generate_samples_stats(SMSUnpublished::SampleMetadata, ds_naming, sample_triples)
