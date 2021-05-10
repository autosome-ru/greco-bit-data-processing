require 'mysql2'
require_relative 'utils'

def get_experiment_infos(client)
    # Table `hub` 
    # +--------------+--------------------+-----------+--------------------+--------------+
    # | input        | input_type         | output    | output_type        | specie       |
    # +--------------+--------------------+-----------+--------------------+--------------+
    # | ALIGNS991138 | AlignmentsGTRDType | EXP991138 | ExperimentGTRDType | Homo sapiens |
    # | READS991276  | ReadsGTRDType      | EXP991138 | ExperimentGTRDType | Homo sapiens |
    # +--------------+--------------------+-----------+--------------------+--------------+

    query = <<-EOS
    SELECT a.output AS experiment_file, a.input AS alignment_file, r.input AS reads_file
    FROM  hub AS a  INNER JOIN  hub AS r  ON  a.output = r.output
    WHERE
        (a.output_type="ExperimentGTRDType")  AND  (r.output_type="ExperimentGTRDType") AND
        (a.input_type="AlignmentsGTRDType") AND (r.input_type="ReadsGTRDType");
    EOS
    client.query(query).to_a
end


def infos_by_alignment(records)
    experiments = []
    alignment_by_experiment = {}
    reads_by_experiment = {}
    records.group_by{|rec| rec['experiment_file'] }.each{|experiment, experiment_records|
        experiments.append(experiment)
        alignments = experiment_records.map{|rec| rec['alignment_file'] }.uniq
        reads      = experiment_records.map{|rec| rec['reads_file'] }.uniq
        alignment_by_experiment[experiment] = alignments.take_the_only
        reads_by_experiment[experiment] = reads
    }
    
    [experiments, alignment_by_experiment, reads_by_experiment]
end
