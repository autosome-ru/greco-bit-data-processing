import os
import glob
import itertools
from collections import defaultdict
import re
import multiprocessing
import pymysql
import pysam
from gzip_utils import open_for_read, open_for_write

NUM_THREADS = 20
TRAIN_CHR = {f"chr{chr}" for chr in range(1,22,2)} # chr1, chr3, ..., chr21
VALIDATION_CHR = {f"chr{chr}" for chr in range(2,23,2)}  # chr2, chr4, ..., chr22

MYSQL_CONFIG = {'host': 'localhost', 'user': 'vorontsovie', 'password': 'password', 'db': 'greco_affyseq'}

SOURCE_DIRNAME = '/home_local/ivanyev/egrid/dfs-affyseq-cutadapt'
ALIGNMENT_DIRNAME = f'{SOURCE_DIRNAME}/aligns-sorted'
FASTQ_DIRNAME = f'{SOURCE_DIRNAME}/fastq'

def read_experiment_meta(filename):
    result = {}
    with open(filename) as f:
        header = f.readline()
        for line in f:
            experiment_id, tf, raw_files, peaks, *metrics, status = line.split("\t")
            if tf == 'CONTROL':
                result[experiment_id] = {'tf': 'CONTROL', 'basename': fastq_bn}
                continue
            raw_files = raw_files.split(';')
            fastq_bns = set(re.sub(r'_R[12].fastq.gz', '', raw_fn) for raw_fn in raw_files)
            if len(fastq_bns) != 1:
                raise 'mismatching FASTQ files'
            fastq_bn = fastq_bns.pop()
            if experiment_id in result:
                raise f'Experiment {experiment_id} should have the only meta-info line'
            result[experiment_id] = {'tf': tf, 'basename': fastq_bn}
    return result

def get_experiment_infos(db_connection):
    # Table `hub` 
    # +--------------+--------------------+-----------+--------------------+--------------+
    # | input        | input_type         | output    | output_type        | specie       |
    # +--------------+--------------------+-----------+--------------------+--------------+
    # | ALIGNS991138 | AlignmentsGTRDType | EXP991138 | ExperimentGTRDType | Homo sapiens |
    # | READS991276  | ReadsGTRDType      | EXP991138 | ExperimentGTRDType | Homo sapiens |
    # +--------------+--------------------+-----------+--------------------+--------------+

    query = """
    SELECT a.output AS experiment_file, a.input AS alignment_file, r.input AS reads_file
    FROM  hub AS a  INNER JOIN  hub AS r  ON  a.output = r.output
    WHERE
        (a.output_type="ExperimentGTRDType")  AND  (r.output_type="ExperimentGTRDType") AND
        (a.input_type="AlignmentsGTRDType") AND (r.input_type="ReadsGTRDType");
    """

    with db_connection.cursor() as cursor:
        cursor.execute(query)
        records = cursor.fetchall()
    return [{'experiment': rec[0], 'alignment': rec[1], 'reads': rec[2]} for rec in records]

def infos_by_alignment(records):
    records_by_experiment = itertools.groupby(records, lambda rec: rec['experiment'])
    experiments = []
    alignment_by_experiment = {}
    reads_by_experiment = {}
    for experiment, iter_vals in records_by_experiment:
        experiments.append(experiment)
        experiment_records = list(iter_vals)
        alignments = set(rec['alignment'] for rec in experiment_records)
        reads      = set(rec['reads'] for rec in experiment_records)
        if len(alignments) != 1:
            raise f'Should be one alignment per experiment for {experiment}'
        alignment = alignments.pop()
        alignment_by_experiment[experiment] = alignment
        reads_by_experiment[experiment] = reads
    return experiments, alignment_by_experiment, reads_by_experiment

def bam_splitted(bam_filename):
    samfile = pysam.AlignmentFile(bam_filename, "rb")
    train_qnames = set()
    validation_qnames = set()
    other_qnames = set()
    unmapped_qnames = set()
    for read in samfile:
        if read.is_unmapped:
            unmapped_qnames.add(read.qname)
            continue
        if read.reference_name in TRAIN_CHR:
            train_qnames.add(read.qname)
        elif read.reference_name in VALIDATION_CHR:
            validation_qnames.add(read.qname)
        else:
            other_qnames.add(read.qname)
    return {'train': train_qnames, 'validation': validation_qnames, 'other': other_qnames, 'unmapped': unmapped_qnames}

def read_fastq(filename):
    with open_for_read(filename) as f:
        while True:
            try:
                header = next(f).rstrip()
                seq = next(f).rstrip()
                plus = next(f).rstrip()
                qual = next(f).rstrip()
                yield (header,seq,plus,qual)
            except StopIteration:
                break

def split_fastq_train_val(fastq_fns, alignment_fn, train_fn, validation_fn):
    alignment_infos = bam_splitted(alignment_fn)
    train_ids = alignment_infos['train']
    validation_ids = alignment_infos['validation']
    with open_for_write(train_fn) as train_fw, open_for_write(validation_fn) as validation_fw:
        for fastq_fn in fastq_fns:
            for single_read_info in read_fastq(fastq_fn):
                read_name = single_read_info[0].lstrip('@').split(' ')[0]
                if read_name in train_ids:
                    print('\n'.join(single_read_info), file=train_fw)
                elif read_name in validation_ids:
                    print('\n'.join(single_read_info), file=validation_fw)


db_connection = pymysql.connect(**MYSQL_CONFIG)
records = get_experiment_infos(db_connection)
experiments, alignment_by_experiment, reads_by_experiment = infos_by_alignment(records)

meta_by_experiment = read_experiment_meta('source_data_affiseq/metrics_by_exp.tsv')

def task_generator():
    for experiment in experiments:
        experiment_meta = meta_by_experiment[experiment]
        tf = experiment_meta['tf']
        if tf == 'CONTROL':
            continue
        alignment = alignment_by_experiment[experiment]
        read_basenames = reads_by_experiment[experiment]
        basename = experiment_meta['basename'] # ZNF596_AffSeq_Lysate_BatchAATA_Cycle3
        _, _, ivt_or_lysate, batch, cycle = basename.split('_')
        
        alignment_fn = f"{ALIGNMENT_DIRNAME}/{alignment}.bam"
        RESULTS_FOLDER = f'results_affiseq_{ivt_or_lysate}'
        train_fn      = f'{RESULTS_FOLDER}/{tf}.{ivt_or_lysate}.{cycle}.{batch}.asReads.affiseq.train.fastq.gz' # ToDo: check suffix
        validation_fn = f'{RESULTS_FOLDER}/{tf}.{ivt_or_lysate}.{cycle}.{batch}.asReads.affiseq.val.fastq.gz'
        fastq_fns = [f"{FASTQ_DIRNAME}/{fastq_bn}.fastq.gz"  for fastq_bn in read_basenames]
        yield (fastq_fns, alignment_fn, train_fn, validation_fn)

if not os.path.exists('results_affiseq_IVT'):
    os.makedirs('results_affiseq_IVT')
if not os.path.exists('results_affiseq_Lysate'):
    os.makedirs('results_affiseq_Lysate')

with multiprocessing.Pool(NUM_THREADS) as pool:
    pool.starmap(split_fastq_train_val, task_generator())
