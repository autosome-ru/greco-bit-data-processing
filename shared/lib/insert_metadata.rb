InsertMetadata = Struct.new(*[
      :insert_id, :source_tf_gene, :dbd_type, :dbd_type_from_HumanTFs, 
      :amino_acid_sequence, :aa_length, :recoded_dna_sequence, :dna_length, 
      # :smileseq_eGFP_clone_id, :biobasic_UT380_clone, :_missing_name, :plasmid_backbone,
      # :cell_culture_eGFP_id, :biobasic_UT368_no_long, :biobasic_UT368_no_short, :plasmid_number, :plasmid_name, :plasmid_backbone,
      # :t7_GST_clone_id, :biobasic_UT368_no_long, :biobasic_UT368_no_short, :plasmid_number, :plasmid_name, :plasmid_backbone,
      :ally_comparasion_list, :insert_description,
      :plasmid_numbers,
    ], keyword_init: true) do
  def self.parse_int(str); (!str || str == '') ? nil : Integer(str.strip); end
  def self.parse_cell(str); (str == '#N/A' || str == '' || str == 'Unknown') ? nil : str.strip; end
  def self.parse_cell_list(str); (str == '#N/A' || str == '' || str == 'Unknown' ) ? [] : str.split(';').map(&:strip); end

  def self.from_string(line)
    insert_id, source_tf_gene, dbd_type, dbd_type_from_HumanTFs, 
      amino_acid_sequence, aa_length, recoded_dna_sequence, dna_length, 
      smileseq_eGFP_clone_id, smileseq_biobasic_UT380_clone, smileseq_missing_name, smileseq_plasmid_backbone,
      cell_culture_eGFP_id, eGFP_biobasic_UT368_no_long, eGFP_biobasic_UT368_no_short, eGFP_plasmid_number, eGFP_plasmid_name, eGFP_plasmid_backbone,
      t7_GST_clone_id, t7_GST_biobasic_UT368_no_long, t7_GST_biobasic_UT368_no_short, t7_GST_plasmid_number, t7_GST_plasmid_name, t7_GST_plasmid_backbone,
      ally_comparasion_list, insert_description, = line.chomp.split("\t", 26)
      plasmid_numbers = [parse_cell(eGFP_plasmid_number), parse_cell(t7_GST_plasmid_number)].compact
    self.new(
      insert_id: insert_id, source_tf_gene: source_tf_gene, dbd_type: parse_cell(dbd_type), dbd_type_from_HumanTFs: parse_cell_list(dbd_type_from_HumanTFs),
      amino_acid_sequence: amino_acid_sequence.strip, aa_length: parse_int(aa_length), recoded_dna_sequence: recoded_dna_sequence.strip, dna_length: parse_int(dna_length),
      ally_comparasion_list: parse_cell(ally_comparasion_list), insert_description: parse_cell(insert_description),
      plasmid_numbers: plasmid_numbers,
    )
  end

  def self.each_in_file(filename)
    return enum_for(:each_in_file, filename)  unless block_given?
    File.readlines(filename).drop(1).map{|line|
      yield self.from_string(line)
    }
  end
end
