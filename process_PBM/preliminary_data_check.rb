#!/usr/bin/env ruby
require_relative 'chip_probe'

# Check that supposed chip-type field in filename determines number of chip probes
Dir.glob('data/RawData/*.txt').each{|fn|
  file_info = Chip.parse_filename(fn)
  probes = ChipProbe.each_in_file(fn).to_a
  info = [probes.count, File.basename(fn, '.txt'), file_info[:sample_id], file_info[:chip_type]]
  puts info.join("\t")
}


# Check that supposed chip-type field in filename determines content of probes (answer is NO!!! See next point and notes)
Dir.glob('data/RawData/*.txt').group_by{|fn|
  file_info = Chip.parse_filename(fn)
  file_info[:chip_type]
}.each{|chip_type, fns|
  counts = fns.map{|fn|
    probes = ChipProbe.each_in_file(fn).to_a
    probes.count
  }
  chip_contents = fns.map{|fn|
    probes = ChipProbe.each_in_file(fn).to_a
    probes.map{|probe| probe.to_h.values_at(:id_spot, :row, :col, :id_probe, :pbm_sequence, :linker_sequence) }.sort
  }
  puts [chip_type, counts.uniq, chip_contents.size, chip_contents.uniq.size].join("\t")
};nil

# Check whether all chips of the same type have the same id_spot+row+col+id_probe+pbm_sequence+linker_sequence.
# Answer is NO!!! Actually one chip has the same set of id_probes but rows are shifted by +1/-1, id_spot is shifted by +85/-85
Dir.glob('data/RawData/*.txt').group_by{|fn|
  probes = ChipProbe.each_in_file(fn).to_a
  chip_content = probes.map{|probe| probe.to_h.values_at(:id_spot, :row, :col, :id_probe, :pbm_sequence, :linker_sequence) }.sort
#   chip_content = probes.map{|probe| probe.to_h.values_at(:id_probe, :pbm_sequence, :linker_sequence) }.sort
  chip_content
}.each{|content, fns|
  puts content.size
  fns.each{|fn|
    file_info = Chip.parse_filename(fn)
    puts [file_info[:chip_type], file_info[:tf], file_info[:basename]].join("\t")
  }
};nil
