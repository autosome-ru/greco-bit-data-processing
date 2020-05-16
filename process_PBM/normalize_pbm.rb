#!/usr/bin/env ruby

require 'fileutils'
require_relative 'chip_probe'
require_relative 'statistics'
require_relative 'quantile_normalization'

# # Check that supposed chip-type field in filename determines number of chip probes
# Dir.glob('data/RawData/*.txt').each{|fn|
#   file_info = Chip.parse_filename(fn)
#   probes = ChipProbe.each_in_file(fn).to_a
#   info = [probes.count, File.basename(fn, '.txt'), file_info[:sample_id], file_info[:chip_type]]
#   puts info.join("\t")
# }


# # Check that supposed chip-type field in filename determines content of probes (answer is NO!!! See next point and notes)
# Dir.glob('data/RawData/*.txt').group_by{|fn|
#   file_info = Chip.parse_filename(fn)
#   file_info[:chip_type]
# }.each{|chip_type, fns|
#   counts = fns.map{|fn|
#     probes = ChipProbe.each_in_file(fn).to_a
#     probes.count
#   }
#   chip_contents = fns.map{|fn|
#     probes = ChipProbe.each_in_file(fn).to_a
#     probes.map{|probe| probe.to_h.values_at(:id_spot, :row, :col, :id_probe, :pbm_sequence, :linker_sequence) }.sort
#   }
#   puts [chip_type, counts.uniq, chip_contents.size, chip_contents.uniq.size].join("\t")
# };nil

# # Check whether all chips of the same type have the same id_spot+row+col+id_probe+pbm_sequence+linker_sequence.
# # Answer is NO!!! Actually one chip has the same set of id_probes but rows are shifted by +1/-1, id_spot is shifted by +85/-85
# Dir.glob('data/RawData/*.txt').group_by{|fn|
#   probes = ChipProbe.each_in_file(fn).to_a
#   chip_content = probes.map{|probe| probe.to_h.values_at(:id_spot, :row, :col, :id_probe, :pbm_sequence, :linker_sequence) }.sort
# #   chip_content = probes.map{|probe| probe.to_h.values_at(:id_probe, :pbm_sequence, :linker_sequence) }.sort
#   chip_content
# }.each{|content, fns|
#   puts content.size
#   fns.each{|fn|
#     file_info = Chip.parse_filename(fn)
#     puts [file_info[:chip_type], file_info[:tf], file_info[:basename]].join("\t")
#   }
# };nil

FileUtils.mkdir_p('results/seq_zscore')

chips_by_type = Dir.glob('data/RawData/*.txt').group_by{|fn|
  Chip.parse_filename(fn)[:chip_type]
}

chips_by_type.each{|chip_type, fns|
  chips = fns.map{|fn| Chip.from_file(fn) }
  
  normed_chips = quantile_normalized_chips(chips.map(&:log10_scaled))
  
  # normed_chips = chips.map{|chip|
  #   # chip.scaled(1.0 / chip.mean_background).background_subtracted
  #   chip.scaled(1.0 / chip.mean_background).background_normalized
  # }
  
  probe_values = Hash.new{|h,k| h[k] = [] }
  normed_chips.each{|chip|
    chip.probes
        .reject(&:flag)
        .each{|probe|
          probe_values[probe.id_probe] << probe.signal
        }
  }
  probe_means = probe_values.map{|id, vs| [id, vs.mean] }.to_h
  probe_stdevs = probe_values.map{|id, vs| [id, vs.stddev] }.to_h

  normed_chips.each{|chip|
    probe_scores = chip.probes.map{|probe|
      zscore_val = zscore(probe.signal, probe_means[probe.id_probe], probe_stdevs[probe.id_probe])
      [probe, zscore_val]
    }.sort_by{|probe, zscore_val| zscore_val }

    File.open("results/seq_zscore/#{chip.basename}.tsv", 'w') {|fw|
      chip.probes.map{|probe|
        zscore_val = zscore(probe.signal, probe_means[probe.id_probe], probe_stdevs[probe.id_probe])
        # [probe.id_probe, probe.linker_sequence[-3..-1] + probe.pbm_sequence, zscore_val]
        [probe.id_probe, probe.pbm_sequence, zscore_val]
      }.sort_by{|probe, seq, zscore|
        zscore
      }.reverse.each{|info|
        fw.puts(info.join("\t"))
      }
    }
  }
}; nil
