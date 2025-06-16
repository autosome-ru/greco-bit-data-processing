This repository contains various scripts used when preprocessing data at different stages of the MEX project.

## IMPORTANT

Note that these scripts do not contain production-ready, polished code, and they were not intended to be used outside of the context of the MEX/Codebook project. They depend on multiple interim files and require a specific arrangement of the source files; thus, we do not guarantee that the code will be functional on its own.

During the course we had to act iteratively: include new experiments and motifs, add new benchmarking startegies, fix mistakes detected in metadata, make manual curation that excluded some data. Thus scripts in the repository bear scars of multiple corrections and hotfixes.

Yet, we consider this repo a useful reference to showcase the pipelines and preprocessing strategies used when assembling MEX and curating the underlying data.

In case of particular questions, please contact Ilya Vorontsov (@VorontsovIE, vorontsov.i.e@gmail.com).

Please refer to the MEX manuscript [https://www.biorxiv.org/content/10.1101/2024.11.11.622097v1] and MEX Zenodo repo [https://zenodo.org/records/15667805] for polished production-ready data and a detailed description of the underlying procedures.

## General structure

On the first stage we prepared datasets. Then run benchmarks. And finally performed multiple stages of postprocessing.

Dataset preparation starts from `process.sh` file. In this file we create a pool of random dataset names which will be assigned to other datasets later. Then we run `process_data.sh` / `process.rb` files from `process_peaks_CHS_AFS`, `process_reads_HTS_SMS_AFS`, `process_PBM` as well as `process_data_AFS_peaks.sh`, `process_data_AFS_reads.sh`, `process_data_CHS.sh` files. Script `collect_metadata.rb` aggregates information about datasets from metadata files and other sources.

For PBM files we also make our own motifs (`process_PBM/process_motifs.sh`). Other motifs were obtained by other groups with their custom code and tools, code not provided here.

Then we collect these and all the rest motifs, named in a proper way. Motifs which were incorrectly named are to be renamed, see `postprocessing/rename_motifs.rb`.

In file `postprocessing/motif_metrics.sh` there is a bunch of commands to create benchmark runners — lists of shell commands invoking benchmarking, which are to be run in parallel. Scripts `./postprocessing/filter_motif_in_flanks.sh` and `./calculate_artifact_similarities.sh` filter out some bad motifs. And then `postprocessing/reformat_metrics.rb` and `make_ranks` are used to collect metrics and rankings of motifs. Script `postprocessing/final_pack.sh` collects all the artifacts in a single file.

## Software requirements

Most scripts are written in ruby, shell (bash dialect), and python. `Gemfile` and `requirements.txt` contain libraries necessary to run these scripts.

Benchmarks are containerized, so one should have docker installed. Corresponding docker images will be automatically pulled from dockerhub. Source files are stored in [motif_benchmarks repository](https://github.com/autosome-ru/motif_benchmarks).

Many calculations are parallelizable via GNU parallel. We adjust number of threads based on available computational resources.
