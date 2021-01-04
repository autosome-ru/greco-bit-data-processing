# ln -s /home_local/mihaialbu/Codebook/SELEX/RawData/ source_data/reads

# wget https://github.com/shenwei356/seqkit/releases/download/v0.13.2/seqkit_linux_amd64.tar.gz
# tar -zxf seqkit_linux_amd64.tar.gz

# # Run once
# python3 gen_random_names.py > names_pool.txt

ruby train_val_split.rb
