PlasmidMetadata = Struct.new(*[
      :index, :plasmid_number, :plasmid_backbone, :plasmid_name, :insert_name, :gene_name, :notes,
    ], keyword_init: true) do

  # Index Plasmid Number  Plasmid backbone  Plasmid Name  Insert Name Gene Name Notes
  # 753 pTH14329  pTH6838 GST.SNAPC5.FL SNAPC5.FL SNAPC5  Codebook clone
  # 630 pTH14206  pTH6838 GST.ZC3H8.DBD ZC3H8.DBD ZC3H8 Codebook clone
  # 1 pTH13592  pTH13195  eGFP.DNTTIP1.FL DNTTIP1.FL  DNTTIP1 Codebook clone
  # 829 pTH15560  pTH13195  eGFP.NFKB1  NFKB1 NFKB1 Smile-seq control
  def self.from_string(line)
    index, plasmid_number, plasmid_backbone, plasmid_name, insert_name, gene_name, notes = line.chomp.split("\t", 7)
    self.new(index: index,
      plasmid_number: plasmid_number, plasmid_backbone: plasmid_backbone, plasmid_name: plasmid_name,
      insert_name: insert_name, gene_name: gene_name, notes: notes,
    )
  end

  def self.each_in_file(filename)
    return enum_for(:each_in_file, filename)  unless block_given?
    File.readlines(filename).drop(1).map{|line|
      yield self.from_string(line)
    }
  end

  def construct_type
    plasmid_name.sub(/^(eGFP|GST|)\./, '').sub(/\.\d$/, '').split('.')[1] || 'NA'
  end
end
