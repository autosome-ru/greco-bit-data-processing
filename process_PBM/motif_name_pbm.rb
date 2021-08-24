# dataset_fn: ZGPAT.DBD@PBM.ME@PBM13915.5GTGAAATTGTTATCCGCTCT@QNZS.lumpy-chestnut-chipmunk.Train.tsv
# motif_id: 7to15_simple
# motif_ext: .pcm
# team: VIGG
# tool: ChIPMunk

# result (long format): ZGPAT.DBD@PBM.ME@lumpy-chestnut-chipmunk@VIGG.ChIPMunk@7to15_simple.pcm
# result (short format): ZGPAT@lumpy-chestnut-chipmunk@VIGG.ChIPMunk@7to15_simple.pcm
require 'optparse'

dataset_fn = nil
motif_id = nil

motif_ext = ''
team = 'autosome-ru'
tool = 'ChIPMunk'

format = 'long'
opt_parser = OptionParser.new do |opts|
  opts.on('--short', 'Use short motif format name') { format = 'short' }
  opts.on('--ext EXT', 'Motif extension (with dot)') {|value| motif_ext = value }
  opts.on('--team NAME', 'Team name (VIGG by default)') {|value| team = value }
  opts.on('--tool NAME', 'Tool name (ChIPMunk by default)') {|value| tool = value }
  opts.on('--dataset FILENAME', 'Dataset filename (obligatory)') {|value| dataset_fn = value }
  opts.on('--motif-id NAME', 'Motif ID (obligatory)') {|value| motif_id = value }
end
opt_parser.parse!(ARGV)

raise "Specify dataset filename"  unless dataset_fn
raise "Specify motif_id"  unless motif_id

dataset_ext = File.extname(dataset_fn)
dataset_bn = File.basename(dataset_fn, dataset_ext)
tf_part, exp_part, exp_info, proc_info = dataset_bn.split('@')
hgnc, construct_type = tf_part.split('.')
exp_type, exp_subtype = exp_part.split('.')
exp_id, *rest_exp_info = exp_info.split('.')
proc_type, dataset_id, slice_type = proc_info.split('.')

if format == 'long'
  puts "#{hgnc}.#{construct_type}@#{exp_type}.#{exp_subtype}@#{dataset_id}@#{team}.#{tool}@#{motif_id}#{motif_ext}"
elsif format == 'short'
  puts "#{hgnc}@#{dataset_id}@#{team}.#{tool}@#{motif_id}#{motif_ext}"
else
  raise "Unknown output format `#{format}`"
end
