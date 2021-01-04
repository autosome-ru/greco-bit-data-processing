### Readme
### In the following is a short description of the SMiLE-seq data and how they were processed.

## PART-I - NEW DATA

Files are provided in fastq format and contain only the randomized region accessible to the TF in each experiment:
1)  a lab-specific identifier (UT...)
2) the gene name
3) protein structure used in the experiment, i.e. DBD of FL for full-length
4) the seqeuncing Identifier (i.e. SS018)
5) the barcode which is a 10bp seqeunce upstream of the variable region and was present and available to bind for the TF during the experiment.

The library is designed as follows:

TCGTCGGCAGCGTCAGATGTGTATAAGAGACAG -[BC 1-12, 10bp i.e. CGTATGAATC] - NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN - CTGTCTCTTATACACATCTCCGAGCCCACGAGAC

The library present during the experiment has 4 parts, separated by " - ":
1) Read 1 primer binding site (constant across all libraries; Illumina adapter sequencing)
2) a 10bp barcode seqeunce, whose exact seqeunce is provided in the smileseq_barcode_file.txt 
3) 40bp random region, which is what the raw fastq files contain
4) read 2 primer binding site (constant across all libraries; Illumina adapter sequencing)


## PART-II - old, SRA-submitted DATA

Files were downloaded from the SRA seqeuncing archive and barcodes were assigned based on actual seqeunces in the resulting fastq files. Only samples where the first few sequences in the fastq files matched both left and right sequences of one of the 24 original barcodes were maintained (total of 68, without input). 

Next, the retained 68 fastq files were filtered, keeping only sequences that matched the assigned left half of the barcode (allowed mismatch: 1 of 7 bases). After filtering, seqeunces were trimmed, keeping 
only the randomized 30-bp region. 

Naming as follows:

1) SRR-identifier
2) TF name (if two TFs spearated by "_")
3) if applicable, replicate indicator (1,2,...)
4) barcode ID

The library was designed as follows:
 
ACACTCTTTCCCTACACGACGCTCTTCCGATCT - [BC-half1, 7bp e.g. BC1=CATGCTC] - NNNNNNNNNNNNNNNNNNNNNNNNNNNNNN - [BC-half2, 7bp e.g. BC1=GAGCATG] - GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTG

1) Adapter FW
2) Barcode half1 - 7bp - total of 24 BC
3) 30-mer random region
4) Barcode half2 - 7bp - total of 24 BC (matched with half1)
5) Adapter RW


All of the above indicated sequence was present during TF binding.

 
