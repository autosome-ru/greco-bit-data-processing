import os
import sys
import glob
import itertools
from collections import defaultdict
import re
import multiprocessing
import hashlib
import pymysql
import pysam
from gzip_utils import open_for_read, open_for_write

metrics_fn = sys.argv[1] # 'source_data_meta/AFS/metrics_by_exp.tsv'
db_name = sys.argv[2]    # 'greco_affyseq'  or  'greco_affiseq_jun2021'
NUM_THREADS = 20
TRAIN_CHR = {f"chr{chr}" for chr in range(1,22,2)} # chr1, chr3, ..., chr21
VALIDATION_CHR = {f"chr{chr}" for chr in range(2,23,2)}  # chr2, chr4, ..., chr22

MYSQL_CONFIG = {'host': 'localhost', 'user': 'vorontsovie', 'password': 'password', 'db': db_name}

SOURCE_DIRNAME = 'source_data/AFS/'
ALIGNMENT_DIRNAME = f'{SOURCE_DIRNAME}/aligns-sorted'
FASTQ_DIRNAME = f'{SOURCE_DIRNAME}/trimmed'

# ChipSeq/Patch/SRY_AffSeq_IVT_BatchYWFB_D11_Cycle1_R1.fastq.gz --> SRY_AffSeq_IVT_BatchYWFB_D11_Cycle1
def normalize_filename(raw_fn):
    bn = os.path.basename(raw_fn)
    bn = re.sub(r'_Cycle(\d)(_\w\d+)?_R(ead)?[12]\.fastq(\.gz)?$', r'_Cycle\1', bn, flags=re.IGNORECASE)
    bn = re.sub(r'_Cycle(\d)_S\d+_R[12]_001\.fastq(\.gz)?$', r'_Cycle\1', bn, flags=re.IGNORECASE)
    bn = re.sub(r'_cyc(\d)_read[12]\.fastq(\.gz)?$', r'_Cycle\1', bn, flags=re.IGNORECASE)
    return bn

def read_experiment_meta(filename):
    header_mapping = {
      "Peaks (/home_local/ivanyev/egrid/dfs-affyseq/peaks-interval)": "Peaks",
      "Raw files": "RawFiles",
      "macs2-single-end-peak-count": "macs2-nomodel-peak-count",
      "macs2-paired-end-peak-count": "macs2-pemode-peak-count",
      "QC.estFragLen (max cross-correlation)": "QC.estFragLen",
    }
    result = {}
    with open(filename) as f:
        header = [header_mapping.get(name, name) for name in f.readline().split("\t")]
        for line in f:
            row = line.split("\t")
            row_info = dict(zip(header, row))
            experiment_id = row_info['ID']
            tf = row_info['TF']
            raw_files = row_info['RawFiles']
            peaks = row_info['Peaks']
            if tf == 'CONTROL':
                result[experiment_id] = {'tf': 'CONTROL', 'basename': fastq_bn, 'peaks': peaks}
                continue
            raw_files = raw_files.split(';')
            fastq_bns = set(normalize_filename(raw_fn) for raw_fn in raw_files)
            if len(fastq_bns) != 1:
                raise Exception('mismatching FASTQ files')
            fastq_bn = fastq_bns.pop()
            if experiment_id in result:
                raise Exception(f'Experiment {experiment_id} should have the only meta-info line')
            result[experiment_id] = {'tf': tf, 'basename': fastq_bn, 'peaks': peaks}
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
    sorted_records = sorted(records, key=lambda rec: rec['experiment'])
    records_by_experiment = itertools.groupby(sorted_records, lambda rec: rec['experiment'])
    experiments = []
    alignment_by_experiment = {}
    reads_by_experiment = {}
    for experiment, iter_vals in records_by_experiment:
        experiments.append(experiment)
        experiment_records = list(iter_vals)
        alignments = set(rec['alignment'] for rec in experiment_records)
        reads      = set(rec['reads'] for rec in experiment_records)
        if len(alignments) != 1:
            raise Exception(f'Should be one alignment per experiment for {experiment}')
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
    if len(fastq_fns) == 1:
        mode = 'single-end'
    elif len(fastq_fns) == 2:
        mode = 'paired-end'
    else:
        raise Exception(f'Too many FASTQ files or no such files (`fastq_fns`). Should be either single or a pair of read files')
    alignment_infos = bam_splitted(alignment_fn)
    train_ids = alignment_infos['train']
    validation_ids = alignment_infos['validation']
    with open_for_write(train_fn) as train_fw, open_for_write(validation_fn) as validation_fw:
        for fastq_fn in fastq_fns:
            for single_read_info in read_fastq(fastq_fn):
                header = single_read_info[0].lstrip('@')
                read_name = header.split(' ')[0]
                if mode == 'single-end':
                    use_read = True
                elif mode == 'paired-end':
                    use_read = False
                    pair_number = int(header.split(' ')[1].split(':')[0]) - 1 # 0 or 1 -- number in single-end/paired-end reads
                    readname_hash = int(hashlib.md5(read_name.encode('ascii')).hexdigest(), base=16)
                    if readname_hash % 2 == pair_number:
                        use_read = True
                if use_read:
                    if read_name in train_ids:
                        print('\n'.join(single_read_info), file=train_fw)
                    elif read_name in validation_ids:
                        print('\n'.join(single_read_info), file=validation_fw)


db_connection = pymysql.connect(**MYSQL_CONFIG)
records = get_experiment_infos(db_connection)
experiments, alignment_by_experiment, reads_by_experiment = infos_by_alignment(records)

meta_by_experiment = read_experiment_meta(metrics_fn)

def task_generator():
    for experiment in experiments:
        if experiment not in meta_by_experiment:
            print(f'No metadata for {experiment}. Skip it.', file=sys.stderr)
            continue
        experiment_meta = meta_by_experiment[experiment]
        tf = experiment_meta['tf']
        if tf == 'CONTROL' or tf == 'NULL':
            continue
        alignment = alignment_by_experiment[experiment]
        read_basenames = reads_by_experiment[experiment]
        basename = experiment_meta['basename']
        basename_parts = basename.replace('Ecoli_GST', 'Lysate').split('_')
        if len(basename_parts) == 5:    # ZNF596_AffSeq_Lysate_BatchAATA_Cycle3
            _tf, _, ivt_or_lysate, batch, cycle = basename_parts
        elif len(basename_parts) == 6:  # NR1H4_AffSeq_IVT_BatchYWFB_D12_Cycle4  or  FIZ1-FL_AffSeq_IVT_BatchYWFB_E01_Cycle1
            _tf_extended, _, ivt_or_lysate, batch, _well, cycle = basename_parts
        else:
            raise Exception(f'Unknown sample basename format `{basename}`')
        peak = experiment_meta['peaks']
        
        alignment_fn = f"{ALIGNMENT_DIRNAME}/{alignment}.bam"
        RESULTS_FOLDER = f'results_databox_afs_reads_{ivt_or_lysate}'
        train_fn      = f'{RESULTS_FOLDER}/Train_sequences/{tf}.{ivt_or_lysate}.{cycle}.{peak}.{batch}.asReads.affiseq.train.fastq.gz' # ToDo: check suffix
        validation_fn = f'{RESULTS_FOLDER}/Val_sequences/{tf}.{ivt_or_lysate}.{cycle}.{peak}.{batch}.asReads.affiseq.val.fastq.gz'
        fastq_fns = [f"{FASTQ_DIRNAME}/{fastq_bn}.fastq.gz"  for fastq_bn in read_basenames]
        yield (fastq_fns, alignment_fn, train_fn, validation_fn)

for ivt_or_lysate in ['IVT', 'Lysate']:
    for train_or_validate in ['Train', 'Val']:
        folder = f'results_databox_afs_reads_{ivt_or_lysate}/{train_or_validate}_sequences/'
        if not os.path.exists(folder):
            os.makedirs(folder)

with multiprocessing.Pool(NUM_THREADS) as pool:
    pool.starmap(split_fastq_train_val, task_generator())
