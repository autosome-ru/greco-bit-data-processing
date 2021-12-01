require_relative 'utils'

module DatasetNameParser
  class BaseParser
    # {tf}.{construct_type}@{experiment_type}.{experiment_subtype}@{experiment_id}.{param1}.{param2}@{processing_type}.{uuid}.{slice_type}.{extension}
    def parse(fn)
      bn = File.basename(fn)
      tf_info, exp_type_info, exp_info, processing_type_uuid_etc = bn.split('@')
      tf, construct_type = tf_info.split('.')
      exp_type, exp_subtype = exp_type_info.split('.')
      exp_id, *exp_params = exp_info.split('.')
      processing_type, uuid, slice_type, extension = processing_type_uuid_etc.split('.')
      {
        dataset_name: bn,
        dataset_id: uuid,
        tf: tf, construct_type: construct_type,
        experiment_type: exp_type, experiment_subtype: exp_subtype,
        experiment_id: exp_id, experiment_params: exp_params,
        processing_type: processing_type,
        slice_type: slice_type, extension: extension,
      }
    end

    def parse_with_metadata(dataset_fn, metadata_by_experiment_id)
      dataset_info = self.parse(dataset_fn)
      experiment_id = dataset_info[:experiment_id]
      experiment_meta = metadata_by_experiment_id[ experiment_id ]
      experiment_meta = experiment_meta.to_h.merge(_original_meta: experiment_meta)
      if experiment_meta.has_key?(:plasmid_id)
        plasmid_id = experiment_meta[:plasmid_id]
        plasmid = $plasmid_by_number[ plasmid_id ].to_h
        insert = $insert_by_plasmid_id[ plasmid_id ]
        plasmid[:insert] = insert.to_h
        experiment_meta[:plasmid] = plasmid
      elsif experiment_meta.has_key?(:insert_id)
        insert_id = experiment_meta[:insert_id]
        inserts = $inserts_by_insert_id[ insert_id ] || []
        keys = inserts.map(&:to_h).flat_map(&:keys).uniq
        joint_insert = keys.map{|k|
          v = inserts.map{|insert| insert[k] }.uniq.join('; ')
          [k,v]
        }.to_h
        experiment_meta[:plasmid] = {insert: joint_insert}
      end
      dataset_info[:experiment_meta] = experiment_meta
      dataset_info
    end
  end

  class PBMParser < BaseParser
    # {tf}.{construct_type}@PBM.{experiment_subtype}@{experiment_id}.5{flank_5}@{processing_type}.{uuid}.{slice_type}.{extension}
    # MTERF3.DBD@PBM.ME@PBM13862.5GTGAAATTGTTATCCGCTCT@QNZS.pasty-rust-tang.Train.tsv
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
      }
      result
    end
  end

  class HTSParser < BaseParser
    # {tf}.{construct_type}@HTS.{experiment_subtype}@{experiment_id}.C{cycle}.5{flank_5}.3{flank_3}@Reads.{uuid}.{slice_type}.{extension}
    # ZNF770.FL@HTS.Lys@AAT_A_GG40NGTGAGA.C3.5ACGACGCTCTTCCGATCTGG.3GTGAGAAGATCGGAAGAGCA@Reads.freaky-cyan-buffalo.Train.fastq.gz
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        cycle:   exp_params.grep(/^C\d$/).take_the_only[1..-1].yield_self{|x| Integer(x) },
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
        flank_3: exp_params.grep(/^3/).take_the_only[1..-1],
      }
      result
    end
  end

  class CHSParser < BaseParser
    # {tf}.{construct_type}@CHS@{experiment_id}@Peaks.{uuid}.{slice_type}.{extension}
    # C11orf95.FL@CHS@THC_0197@Peaks.sunny-celadon-boar.Train.peaks
    # ZNF20.FL@CHS@THC_0341.Rep-DIANA_0293@Peaks.flimsy-tan-shark.Train.peaks
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      raise  if exp_params.size > 1
      result[:experiment_params] = {
        replica: exp_params.empty? ? nil : exp_params.first[/^Rep-(.+)$/, 1],
      }
      result
    end
  end

  class SMSParser < BaseParser
    # {tf}.{construct_type}@SMS@{experiment_id}@Reads.{uuid}.{slice_type}.{extension}
    # AHCTF1.DBD@SMS@UT380-009.5TAAGAGACAGCGTATGAATC.3CTGTCTCTTATACACATCTC@Reads.wiggy-alizarin-albatross.Train.fastq.gz
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
        flank_3: exp_params.grep(/^3/).take_the_only[1..-1],
      }
      result
    end
  end

  class AFSReadsParser < BaseParser
    # {tf}.{construct_type}@AFS.{experiment_subtype}@{experiment_id}@Reads.{uuid}.{slice_type}.{extension}
    # GLI4.DBD@AFS.IVT@AATBA_AffSeq_A9_GLI4.C1.5ACACGACGCTCTTCCGATCT.3AGATCGGAAGAGCACACGTC@Reads.greasy-lilac-clam.Train.fastq.gz
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        cycle:   exp_params.grep(/^C\d$/).take_the_only[1..-1].yield_self{|x| Integer(x) },
        flank_5: exp_params.grep(/^5/).take_the_only[1..-1],
        flank_3: exp_params.grep(/^3/).take_the_only[1..-1],
      }
      result
    end
  end

  class AFSPeaksParser < BaseParser
    # {tf}.{construct_type}@AFS.{experiment_subtype}@{experiment_id}@Peaks.{uuid}.{slice_type}.{extension}
    # ZFP3.FL@AFS.Lys@AATA_AffSeq_E5_ZFP3.C3@Peaks.nerdy-razzmatazz-cichlid.Train.peaks
    def parse(fn)
      result = super(fn)
      exp_params = result[:experiment_params]
      result[:experiment_params] = {
        cycle:   exp_params.grep(/^C\d$/).take_the_only[1..-1].yield_self{|x| Integer(x) },
      }
      result
    end
  end
end
