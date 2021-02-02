PlasmidMetadata = Struct.new(*[
      :index, :plasmid_number, :plasmid_backbone, :plasmid_name, :insert_name, :gene_name, :notes,
      :pbm_me_experiment_ids, :pbm_hk_experiment_ids, 
      :ht_selex_ivt_experiment_ids, :ht_selex_lysate_experiment_ids,
      :affiseq_ivt_experiment_ids, :affiseq_lysate_experiment_ids,
      :smileseq_experiment_ids, :chipseq_rep_1, :chipseq_rep_2, :rest_data,
    ], keyword_init: true) do
  def self.parse_cell(str); (str == '#N/A' || str == '') ? nil : str.strip; end
  def self.parse_cell_ids(str); (str == '#N/A' || str == '') ? [] : str.split(',').map(&:strip); end

  # Index Plasmid Number  Plasmid backbone  Plasmid Name  Insert Name Gene Name Notes PBM_ME experiment ID(s) PBM_HK experiment ID(s) HT-Selex (IVT) experiment ID(s) HT-Selex (Lysate) experiment ID(s)  AffiSeq (IVT) experiment ID(s)  AffiSeq (Lysate) experiment ID(s) SMiLE-seq experiment ID(s)  ChIP-seq replicate 1  ChIP-seq replicate 2
  # 753 pTH14329  pTH6838 GST.SNAPC5.FL SNAPC5.FL SNAPC5  Codebook clone  13341 13357 #N/A          #N/A  
  # 630 pTH14206  pTH6838 GST.ZC3H8.DBD ZC3H8.DBD ZC3H8 Codebook clone  13470, 13958  13486, 14453  YWC_113         #N/A
  # 1 pTH13592  pTH13195  eGFP.DNTTIP1.FL DNTTIP1.FL  DNTTIP1 Codebook clone  #N/A  #N/A  #N/A          chip
  # 829 pTH15560  pTH13195  eGFP.NFKB1  NFKB1 NFKB1 Smile-seq control #N/A  #N/A
  def self.from_string(line)
    index, plasmid_number, plasmid_backbone, plasmid_name, insert_name, gene_name, notes,
      pbm_me_experiment_ids, pbm_hk_experiment_ids, 
      ht_selex_ivt_experiment_ids, ht_selex_lysate_experiment_ids,
      affiseq_ivt_experiment_ids, affiseq_lysate_experiment_ids,
      smileseq_experiment_ids, chipseq_rep_1, chipseq_rep_2, rest_data = line.chomp.split("\t", 17)
    self.new(index: index,
      plasmid_number: plasmid_number, plasmid_backbone: plasmid_backbone, plasmid_name: plasmid_name,
      insert_name: insert_name, gene_name: gene_name, notes: notes,
      pbm_me_experiment_ids: parse_cell_ids(pbm_me_experiment_ids),
      pbm_hk_experiment_ids: parse_cell_ids(pbm_hk_experiment_ids),
      ht_selex_ivt_experiment_ids: parse_cell_ids(ht_selex_ivt_experiment_ids),
      ht_selex_lysate_experiment_ids: parse_cell_ids(ht_selex_lysate_experiment_ids),
      affiseq_ivt_experiment_ids: parse_cell_ids(affiseq_ivt_experiment_ids),
      affiseq_lysate_experiment_ids: parse_cell_ids(affiseq_lysate_experiment_ids),
      smileseq_experiment_ids: parse_cell_ids(smileseq_experiment_ids),
      chipseq_rep_1: parse_cell(chipseq_rep_1), chipseq_rep_2: parse_cell(chipseq_rep_2),
      rest_data: rest_data,
    )
  end

  def self.each_in_file(filename)
    return enum_for(:each_in_file, filename)  unless block_given?
    File.readlines(filename).drop(1).map{|line|
      yield self.from_string(line)
    }
  end

  def construct_type
    plasmid_name.split('.')[2]
  end
end
