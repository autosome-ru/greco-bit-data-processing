mkdir -p source_data/HTS/reads
find /mnt/space/hughes/June1st2021/SELEX_RawData/ -xtype f -iname '*.fastq.gz' \
  | grep -vi AffSeq | grep -vi Control | grep -vi Unselected \
  | xargs -n1 -I{} ln -s {} source_data/HTS/reads/

find /mnt/space/hughes/SELEX_RawData/Phase4 -xtype f -iname '*.fastq.gz' \
  | grep -vPe 'AffiSeq|AffSeq|GHTSELEX' | grep -vi Control | grep -vi Unselected \
  | xargs -n1 -I{} ln -s {} source_data/HTS/reads/


mkdir -p source_data/SMS/reads/unpublished
find /mnt/space/depla/smileseq_raw/ -xtype f -iname '*.fastq' \
  | ruby -r fileutils -e '$stdin.readlines.map(&:chomp).each{|fn| new_bn = File.basename(fn).sub(/^UT(\d\d\d)_?(\d\d\d)_/, "UT\\1-\\2_"); FileUtils.ln_s(fn, "source_data/SMS/reads/unpublished/#{new_bn}") }'

find /mnt/space/depla/smileseq_raw062021/ -xtype f -iname '*.fastq' \
  | ruby -r fileutils -e '$stdin.readlines.map(&:chomp).each{|fn| new_bn = File.basename(fn); FileUtils.ln_s(fn, "source_data/SMS/reads/unpublished/#{new_bn}") }'

find /mnt/space/depla/smileseq_raw2022_02/ -xtype f -iname '*.fastq' \
  | ruby -r fileutils -e '$stdin.readlines.map(&:chomp).each{|fn| new_bn = File.basename(fn); FileUtils.ln_s(fn, "source_data/SMS/reads/unpublished/#{new_bn}") }'

# drop wrong data (non-unique ids)
# find source_data/SMS/reads/unpublished/ -xtype f \
#   | ruby -r fileutils -e 'readlines.map(&:chomp).group_by{|fn| File.basename(fn).split("_").first }.select{|k,vs| vs.size != 1}.values.flatten.each{|fn| FileUtils.rm(fn) }'

mkdir -p source_data/SMS/reads/published
find /mnt/space/depla/old_smlseq_raw/raw/ -xtype f -iname '*.fastq' \
  | xargs -n1 -I{} ln -s {} source_data/SMS/reads/published/


# For AFS.peaks
ruby shared/lib/symlink_folder_content.rb \
    "/home_local/ivanyev/egrid/dfs-affyseq-cutadapt/peaks-interval/" \
    "source_data/AFS/peaks-intervals/" \
    symlink

# # We don't need raw reads for AFS. We use reads preprocessed by GTRD-pipeline instead (see below)
# mkdir -p source_data/AFS/reads
# find /home_local/mihaialbu/Codebook/SELEX/RawData/ -xtype f -iname '*.fastq.gz' \
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


# For CHS
ruby shared/lib/symlink_folder_content.rb \
    "/mnt/space/ivanyev/egrid/dfs/ctrl-subsampled0.1/peaks-interval" \
    "source_data/CHS/peaks-intervals/" \
    symlink


ruby shared/lib/symlink_folder_content.rb \
    "/mnt/space/ivanyev/egrid/dfs/ctrl-subsampled0.02/peaks-interval" \
    "source_data/CHS/peaks-intervals/" \
    symlink


ruby shared/lib/symlink_folder_content.rb \
    "/mnt/space/ivanyev/egrid/dfs/fastq" \
    "source_data/CHS/fastq/" \
    symlink


mkdir -p source_data/PBM/chips
find /mnt/space/hughes/Codebook_extended/PBM_raw/ -iname '*.txt' | xargs -n1 -I{} ln -s {} source_data/PBM/chips

##########################

# check if names are HGNC compliant
ls /mnt/space/depla/smileseq_raw/ \
  | grep -oPe '^UT\d+-\d+_[^_]+' \
  | grep -oPe '[^_]+$' \
  | sort -u \
  | xargs -n1 -I{} echo \
    'echo -ne "{}\t"; curl -s -H "Accept:application/json" http://rest.genenames.org/search/symbol/{} | jq -r ".response.docs[0].symbol"' \
  | bash

cat source_data_meta/SMS/unpublished/SMS.tsv \
  | tail -n+2 \
  | cuttab -f 2 \
  | cut -d '.' -f1 \
  | sort -u \
  | xargs -n1 -I{} echo \
    'echo -ne "{}\t"; curl -s -H "Accept:application/json" http://rest.genenames.org/search/symbol/{} | jq -r ".response.docs[0].symbol"' \
  | bash

# Check after everything is done
find release_7/ -xtype f | xargs -n1 basename | cut -d '.' -f1 | sort -u > gene_names.txt
cat gene_names.txt | xargs -n1 -I{} echo 'echo -ne "{}\t"; curl -s -H "Accept:application/json" http://rest.genenames.org/search/symbol/{} | jq -r ".response.docs[0].symbol"'   | bash > gene_names_canonical.tsv
find release_7 -xtype f | fgrep -f <( cat gene_names_canonical.tsv | awktab -e '($1 != $2){ print $1 "." }' ) | xargs -n1 basename
