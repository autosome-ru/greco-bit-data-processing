#!/usr/bin/env Rscript

library(tidyr)
library(optparse)

option_list = list(
	make_option(c("--window-size"), dest = 'window_size', type = 'integer', default = 5, help = paste(
		"The width (in either direction) of the local window.",
		"If this is 5, the window will be +-5 from the current location, i.e., 11x11 probes",
		"[default=%default]")
	)
)

opt_parser <- OptionParser(option_list=option_list, usage = "Rscript chip_data.txt --window-size 5", description='Spatial detrending of chip data');
opts_and_args <- parse_args(opt_parser, positional_arguments=TRUE);
opts <- opts_and_args[[1]]
args <- opts_and_args[[2]]

filename = args[[1]]

# The width (in either direction) of the local window. If this is 5, the window will be +-5 from the current location, i.e., 11x11 probes
off <- opts$window_size

x<-read.table(filename, sep="\t",header=TRUE,check.names = FALSE,comment.char = "")
values <- x[,c("mean_signal_intensity","row","col")] %>%  spread(key = "col",value = "mean_signal_intensity")
values.matrix<-as.matrix( values[,-1] )

flags <- x[,c("flag","row","col")] %>%  spread(key = "col",value = "flag")
flags.matrix<-as.matrix( flags[,-1] )

# only use good spots for medians
values.matrix.na<-values.matrix
values.matrix.na[flags.matrix==1]<-NA

glob.med <- median(values.matrix.na,na.rm=TRUE)

detrended <- matrix(glob.med,nrow=nrow(values.matrix),ncol=ncol(values.matrix))

for(i in 1:nrow(detrended)){
	for(j in 1:ncol(detrended)){
		si <- max(1,i-off)
		ei <- min(nrow(detrended),i+off)
		sj <- max(1,j-off)
		ej <- min(ncol(detrended),j+off)

		if(sum(!is.na( values.matrix.na[ si:ei, sj:ej ] ))>0){
			loc.med <- median( values.matrix.na[ si:ei, sj:ej ], na.rm=TRUE )
			detrended[i,j] <- values.matrix[i,j]*( glob.med/loc.med )
		}else{
			# if there are no good spots, we just take the original value
			# (which will be filtered out anyway, but might influence quantile normalization)
			# alternative would be to use glob.med instead
			detrended[i,j] <- values.matrix[i,j]
		}
	}
}

y<-x

y[,"mean_signal_intensity"] <- detrended[ as.matrix( y[,c("row","col")] ) ]

write.table(x = y, quote = F, sep = "\t", row.names = FALSE, col.names = TRUE)
