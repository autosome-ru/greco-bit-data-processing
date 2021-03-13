See also notes on [data corrections](data_corrections.md).

### Versions 1-5
/home_local/vorontsovie/greco-data/release_2.2020-07-26/
/home_local/vorontsovie/greco-data/release_3.2020-08-08/
/home_local/vorontsovie/greco-data/release_4.2020-11-26/
/home_local/vorontsovie/greco-data/release_5.2020-12-13/

### Version 6
/home_local/vorontsovie/greco-data/release_6.2021-02-13/
Release v6 is the first release where dataset names use unified format.

Known problems:
* (FIXED at 12 March 2021) AFS.Reads don't have adapter encoded in filenames
* (FIXED at 12 March 2021) Missing construct type in resulting filenames of some PBMs. For instance, `ZSCAN4.@PBM.ME...` should be `ZSCAN4.NA@PBM.ME@...`
* No metadata (thus datasets not used) for
** AFS
***  `ZNF997`
** HTS
***  `ZNF280A_TC40NGTTTTG_IVT_BatchAATBA_Cycle{2,3}_R1.fastq.gz`
***  `ZNF997_TA40NGTTAGC_Lysate_BatchAATA_Cycle{1,2,3}_R1.fastq.gz`
** PBM
***  `13689_R_2018-10-24_13689_1M-ME_Standard_pTH12990.1_LIN28B.RBR.txt`
***  `13705_R_2018-10-24_13705_1M-HK_Standard_pTH12990.2_LIN28B.RBR.txt`
***  `13800_R_2018-11-06_13800_1M-ME_Standard_pTH12991.1_LIN28B.mCCHC.txt`
***  `13816_R_2018-11-06_13816_1M-HK_Standard_pTH12991.2_LIN28B.mCCHC.txt`
***  `13690_R_2018-10-24_13690_1M-ME_Standard_pTH13023.1_RBCK1.sRANBP2.txt`
***  `13706_R_2018-10-24_13706_1M-HK_Standard_pTH13023.2_RBCK1.sRANBP2.txt`
** CHS
***  `Sample_Hughes_4A_ZNF99_FS0205`
***  `Sample_Hughes_4_ZNF99_Chip`
***  `140515_LYNLEY_0427_AC3U4EACXX_L8_TGACCA` (ZNF382)
** SMS.published:
*** Drop experiments related to dimeric TF sites.
