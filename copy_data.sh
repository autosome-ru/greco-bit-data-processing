mkdir -p source_data/HTS/reads
find -L /mnt/space/hughes/June1st2021/SELEX_RawData/ -xtype f -iname '*.fastq.gz' \
  | grep -vi AffSeq | grep -vi Control | grep -vi Unselected \
  | xargs -n1 -I{} ln -s {} source_data/HTS/reads/


mkdir -p source_data/SMS/reads/unpublished
find -L /mnt/space/depla/smileseq_raw/ -xtype f -iname '*.fastq' \
  | ruby -r fileutils -e '$stdin.readlines.map(&:chomp).each{|fn| new_bn = File.basename(fn).sub(/^UT(\d\d\d)_?(\d\d\d)_/, "UT\\1-\\2_"); FileUtils.ln_s(fn, "source_data/SMS/reads/unpublished/#{new_bn}") }'

find -L /mnt/space/depla/smileseq_raw062021/ -xtype f -iname '*.fastq' \
  | ruby -r fileutils -e '$stdin.readlines.map(&:chomp).each{|fn| new_bn = File.basename(fn); FileUtils.ln_s(fn, "source_data/SMS/reads/unpublished/#{new_bn}") }'

# drop wrong data (non-unique ids)
# find source_data/SMS/reads/unpublished/ -xtype f \
#   | ruby -r fileutils -e 'readlines.map(&:chomp).group_by{|fn| File.basename(fn).split("_").first }.select{|k,vs| vs.size != 1}.values.flatten.each{|fn| FileUtils.rm(fn) }'

mkdir -p source_data/SMS/reads/published
find -L /mnt/space/depla/old_smlseq_raw/raw/ -xtype f -iname '*.fastq' \
  | xargs -n1 -I{} ln -s {} source_data/SMS/reads/published/


# For AFS.peaks
ruby shared/lib/symlink_folder_content.rb \
    "/home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval/" \
    "source_data/AFS/peaks-intervals/" \
    symlink

# # We don't need raw reads for AFS. We use reads preprocessed by GTRD-pipeline instead (see below)
# mkdir -p source_data/AFS/reads
# find -L /home_local/mihaialbu/Codebook/SELEX/RawData/ -xtype f -iname '*.fastq.gz' \
#   | grep -i AffSeq | grep -vi Control \
#   | xargs -n1 -I{} ln -s {} source_data/AFS/reads/

# For AFS.reads
ruby shared/lib/symlink_folder_content.rb \
    "/home_local/ivanyev/egrid/dfs-affyseq-cutadapt/aligns-sorted/" \
    "source_data/AFS/aligns-sorted" \
    symlink

ruby shared/lib/symlink_folder_content.rb \
    "/home_local/ivanyev/egrid/dfs-affyseq-cutadapt/trimmed" \
    "source_data/AFS/trimmed" \
    symlink


ruby shared/lib/symlink_folder_content.rb \
    "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval/" \
    "source_data/CHS/peaks-intervals/" \
    symlink

ruby shared/lib/symlink_folder_content.rb \
    "/home_local/ivanyev/egrid/dfs/ctrl-subsampled0.1-se/peaks-interval/" \
    "source_data/CHS/peaks-intervals-se_control/" \
    symlink


mkdir -p source_data/PBM/chips
find -L /mnt/space/hughes/Codebook_extended/PBM_raw/ -iname '*.txt' | xargs -n1 -I{} ln -s {} source_data/PBM/chips
