# Run once to generate a pool of unique random names
python3 shared/lib/random_names.py

./process_PBM/process_data.sh --source source_data/PBM/chips/ --name-mapping no
ruby ./process_data.rb