Public SMiLE-seq data:
The published SMiLE-seq data were downloaded from the SRA sequencing archive and barcodes were assigned based on actual sequences in the resulting fastq files. Only samples where the first few sequences in the fastq files matched both left and right sequences of one of the 24 original barcodes were maintained (total of 68, without input). 

Next, the retained 68 fastq files were filtered, keeping only sequences that matched the assigned left half of the barcode (allowed mismatch: 1 of 7 bases). After filtering, sequences were trimmed, keeping only the randomized 30-bp region. 

FASTQ files naming as follows:

1) SRR-identifier
2) TF name (if two TFs separated by "_")
3) if applicable, replicate indicator (1,2,...)
4) barcode ID

FASTQ files can be found in:

/mnt/space/depla/old_smlseq_raw/raw/

Barcode sequences in:
/mnt/space/depla/old_smlseq_raw/Barcode_seqeunces.txt

SRR-ID to barcode matching in: 
/mnt/space/depla/old_smlseq_raw/sample_barcode.txt

For further info see also Part-II in 
/mnt/space/depla/readme.txt

Library composition:
ACACTCTTTCCCTACACGACGCTCTTCCGATCT - [BC-half1, 7bp e.g. BC1=CATGCTC] - NNNNNNNNNNNNNNNNNNNNNNNNNNNNNN - [BC-half2, 7bp e.g. BC1=GAGCATG] - GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTG

Sample barcode FW -  barcode RV: 
(also in /mnt/space/depla/old_smlseq_raw/Barcode_seqeunces.txt )
R30_B1 CATGCTC GAGCATG
R30_B2 ACGCAAC GTTGCGT
R30_B3 TCGCAGG CCTGCGA
R30_B4 CTCTGCA TGCAGAG
R30_B5 CCTAGGT ACCTAGG
R30_B6 GGATCAA TTGATCC
R30_B7 GCAAGAT ATCTTGC
R30_B8 ATGGAGA TCTCCAT
R30_B9 CTCGATG CATCGAG
R30_B10 GCTCGAA TTCGAGC
R30_B11 ACCAACT AGTTGGT
R30_B12 CCGGTAC GTACCGG
R30_B13 AACTCCG CGGAGTT
R30_B14 TTGAAGT ACTTCAA
R30_B15 ACTATCA TGATAGT
R30_B16 TTGGATC GATCCAA
R30_B17 CGACCTG CAGGTCG
R30_B18 TAATGCG CGCATTA
R30_B19 AGGTACC GGTACCT
R30_B20 TGCGTCC GGACGCA
R30_B21 GAATCTC GAGATTC
R30_B22 GCATTGG CCAATGC
R30_B23 TGACGTC GACGTCA
R30_B24 GATGCCA TGGCATC

Adaptor FW (1.b) ACACTCTTTCCCTACACGACGCTCTTCCGATCT
Adaptor RV (1.a) GATCGGAAGAGCTCGTATGCCGTCTTCTGCTTG

Actual info in https://docs.google.com/document/d/1DVJgsN2LvXqBOsNHnnBKf-r6zOuitJrKz8fbAAcmvnw/edit#heading=h.u93o07ipbv8c
