require 'bioinform'
pcm_fn = ARGV[0]
raise 'Specify PCM filename'  unless pcm_fn

pcm = Bioinform::MotifModel::PCM.from_file(pcm_fn, validator: Bioinform::MotifModel::PM::VALIDATOR)
ppm = Bioinform::ConversionAlgorithms::PCM2PPMConverter.new.convert(pcm)
puts ppm
