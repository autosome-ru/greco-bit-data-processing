### Corrections for the version 1 (Codebook_Metadata_Masterfile_V9_16DEC2020.xlsx)

* (1) There is no metadata for any of Lysate (HT-SELEX) experiments. We do not need complete data, but Experiments IDs and key information on samples (raw data filenames) are strictly necessary to move on. Also, we need PlasmidIDs to distinguish between FL and DBD constructs.
* (2) Metadata for Affi-Seq experiments do not match the datasets which Mihai previously uploaded to the shared server. None of previously uploaded TFs have metadata and vice versa. In the currently existing metadata, the IVT/Lysate tag is missing.
* (3) We agreed to use HGNC names, and there are some entries which do not follow this policy:
  The Plasmids spreadsheet, “Gene name” column: 
** cJUN →  JUN (pTH15540 and pTH15571)
** OCT4/POU5F1 → POU5F1 (pTH15524 and pTH15565)
** ZNF788 → ZNF788P (pTH13765 and pTH14166)
** ZUFSP → ZUP1 (pTH14199, pTH14200 and pTH13788)

Also, we still don’t know gene names or updated UniProt IDs of AC008770 and AC092835 (those are zinc fingers but mapping by ID is ambiguous). These guys also remain 'unnamed' in SMiLE-Seq data from Judith/Bart.

The TFGenes spreadsheet contains similar problem (ambiguous UniProt ID mapping) for the following genes:
* ZNF788, ZUFSP, AC008770.3, AC092835.1

On the PBM spreadsheet:
* OCT4/POU5F1 → POU5F1 (PBM14330 and PBM14346).
* cJUN --> JUN (PBM14341 and PBM14357)
* AC008770, AC092835

On the ChIP-seq spreadsheet:
* AC008770, AC092835

### Corrections for the version 2

Plasmids:
- Plasmid #889 has plasmid number pTH15990 and simultaneously pTH15883. Probably the first one was accidentally copy-pasted from plasmid #888. Is it correct, that plasmid number should be pTH15883?
- Is it necessary to have two distinct plasmid number columns (B and J) with identical data?
- Some plasmids have "Marjanset TFs with published ChIP-seq data" in unnamed column R. Can you please either give some name to the column or fix these data.


SMiLE-Seq data:
- renamed UT{123_456}_*.fastq -> UT{123-456}_*.fastq
- renamed UT380408_ZNF66_C2H2_ZF_SS114_BC01.fastq -> UT380-408_ZNF66_C2H2_ZF_SS114_BC01.fastq
- there are duplicate BBI_IDs (UT380-038, UT380-056, UT380-066, UT380-068, UT380-105, UT380-127, UT380-144, UT380-185, UT380-212, UT380-233, UT380-245, UT380-502, UT380-503). Thus we can't treat them as experiment ids. Hughes_ID is also not unique.


HT-Selex:
- There is no metadata for ZNF280A_TC40NGTTTTG_IVT_BatchAATBA_Cycle{2,3}_R1.fastq.gz
- There is no metadata for ZNF997_TA40NGTTAGC_Lysate_BatchAATA_Cycle{1,2,3}_R1.fastq.gz


PBM:
- There is no metadata for several samples:
13689_R_2018-10-24_13689_1M-ME_Standard_pTH12990.1_LIN28B.RBR.txt
13705_R_2018-10-24_13705_1M-HK_Standard_pTH12990.2_LIN28B.RBR.txt
13800_R_2018-11-06_13800_1M-ME_Standard_pTH12991.1_LIN28B.mCCHC.txt
13816_R_2018-11-06_13816_1M-HK_Standard_pTH12991.2_LIN28B.mCCHC.txt
13690_R_2018-10-24_13690_1M-ME_Standard_pTH13023.1_RBCK1.sRANBP2.txt
13706_R_2018-10-24_13706_1M-HK_Standard_pTH13023.2_RBCK1.sRANBP2.txt
