PlasmidMetadata = Struct.new(*[
      :index, :plasmid_number, :plasmid_backbone, :plasmid_name, :insert_name, :gene_name,
      :pbm_me_experiment_ids, :pbm_hk_experiment_ids, 
      :ht_selex_ivt_experiment_ids, :ht_selex_lysate_experiment_ids,
      :affiseq_ivt_experiment_ids, :affiseq_lysate_experiment_ids,
      :smileseq_experiment_ids, :chipseq_rep_1, :chipseq_rep_2,
    ], keyword_init: true) do
  def self.parse_cell(str); (str == '#N/A' || str == '') ? nil : str.strip; end
  def self.parse_cell_ids(str); (str == '#N/A' || str == '') ? [] : str.split(',').map(&:strip); end

  # Index Plasmid Number  Plasmid backbone  Plasmid Name  Insert Name Gene Name PBM_ME experiment ID(s) PBM_HK experiment ID(s) Plasmid Number  HT-Selex (IVT) experiment ID(s) HT-Selex (Lysate) experiment ID(s)  AffiSeq (IVT) experiment ID(s)  AffiSeq (Lysate) experiment ID(s) SMiLE-seq experiment ID(s)  ChIP-seq replicate 1  ChIP-seq replicate 2
  # 753 pTH14329  pTH6838 GST.SNAPC5.FL SNAPC5.FL SNAPC5  13341 13357 pTH14329  #N/A          #N/A  
  # 630 pTH14206  pTH6838 GST.ZC3H8.DBD ZC3H8.DBD ZC3H8 13470, 13958  13486, 14453  pTH14206  YWC_113         #N/A  
  # 1 pTH13592  pTH13195  eGFP.DNTTIP1.FL DNTTIP1.FL  DNTTIP1 #N/A  #N/A  pTH13592  #N/A          chip  
  # 829 pTH15560  pTH13195  eGFP.NFKB1  NFKB1 NFKB1 #N/A  #N/A  pTH15560              
  def self.from_string(line)
    index, plasmid_number, plasmid_backbone, plasmid_name, insert_name, gene_name,
      pbm_me_experiment_ids, pbm_hk_experiment_ids, 
      plasmid_number_duplicate,
      ht_selex_ivt_experiment_ids, ht_selex_lysate_experiment_ids,
      affiseq_ivt_experiment_ids, affiseq_lysate_experiment_ids,
      smileseq_experiment_ids, chipseq_rep_1, chipseq_rep_2 = line.chomp.split("\t", 16)
    raise "Conflict in plasmid metadata `#{plasmid_number}`"  unless plasmid_number == plasmid_number_duplicate
    self.new(index: index,
      plasmid_number: plasmid_number, plasmid_backbone: plasmid_backbone, plasmid_name: plasmid_name,
      insert_name: insert_name, gene_name: gene_name,
      pbm_me_experiment_ids: parse_cell_ids(pbm_me_experiment_ids),
      pbm_hk_experiment_ids: parse_cell_ids(pbm_hk_experiment_ids),
      ht_selex_ivt_experiment_ids: parse_cell_ids(ht_selex_ivt_experiment_ids),
      ht_selex_lysate_experiment_ids: parse_cell_ids(ht_selex_lysate_experiment_ids),
      affiseq_ivt_experiment_ids: parse_cell_ids(affiseq_ivt_experiment_ids),
      affiseq_lysate_experiment_ids: parse_cell_ids(affiseq_lysate_experiment_ids),
      smileseq_experiment_ids: parse_cell_ids(smileseq_experiment_ids),
      chipseq_rep_1: parse_cell(chipseq_rep_1), chipseq_rep_2: parse_cell(chipseq_rep_2),
    )
  end

  def self.each_in_file(filename)
    return enum_for(:each_in_file, filename)  unless block_given?
    File.readlines(filename).drop(1).map{|line|
      yield self.from_string(line)
    }
  end
end
