nice R
require(ShortRead)
library(GenomicRanges)
library(GenomicAlignments)
#
## function to plot coverage across set of defined ranges
#
plotCoverage <- function(cov,regions,precision=1000,normalize.widths=TRUE,col="black",lty=1,lwd=1,plotfile=NULL){

	trackVal <- array(0,dim=c(length(regions),precision))
	cat(paste(nrow(trackVal),"sets of regions provided\n"))
	if(length(col)<nrow(trackVal)) col <- rep(col,nrow(trackVal))
	if(length(lty)<nrow(trackVal)) lty <- rep(lty,nrow(trackVal))
	if(length(lwd)<nrow(trackVal)) lwd <- rep(lwd,nrow(trackVal))
	if(!normalize.widths) refMid <- ceiling(precision/2)
	for(i in 1:length(regions)){
		theseSpaces <- intersect(as.character(unique(regions[[i]]@seqnames)),names(cov))
		cat(paste("region set",i,"has",length(theseSpaces),"spaces \n"))
		nrangesByChr <- rep(NA,length(theseSpaces))
		for(k in 1:length(theseSpaces)){
			cat(paste("\t calculating average coverage for",sum(regions[[i]]@seqnames==theseSpaces[k]),"regions on space",theseSpaces[k],"\n"))
			chrCov <- Views(cov[[theseSpaces[k]]],ranges(regions[[i]][regions[[i]]@seqnames==theseSpaces[k]]))
			nrangesByChr[k] <- length(chrCov)
			for(j in 1:length(chrCov)){
				thisCov <- chrCov[[j]]
				if(normalize.widths){
					if(length(thisCov)<precision) thisCov <- Rle(rep(as.numeric(thisCov),each=floor(precision/length(thisCov))))
					indices <- round((0:precision)*(length(thisCov)/precision))
					starts <- indices[1:(length(indices)-1)]+1
					ends <- indices[2:length(indices)]
					newvals <- mean(Views(thisCov,start=starts,end=ends))
					newvals[is.na(newvals)] <- 0
					trackVal[i,] <- trackVal[i,] + newvals
				}
				if(!normalize.widths){
					thisMid <- ceiling(length(thisCov)/2)
					refStart <- max(c(0,refMid-thisMid))+1
					refEnd <- min(c(precision,refMid+length(thisCov)-thisMid))
					thisStart <- max(c(0,thisMid-refMid))+1
					thisEnd <- min(c(length(thisCov),thisMid+precision-refMid))
					cat(paste("filling ref from",refStart,"to",refEnd,"with Cov from",thisStart,"to",thisEnd,"midpoints:",refMid,thisMid,"precision:",precision,"\n"))
					newvals <- as.numeric(thisCov)[thisStart:thisEnd]
					newvals[is.na(newvals)] <- 0
					trackVal[i,refStart:refEnd] <- trackVal[i,refStart:refEnd] + newvals
				}
			}
		}
		trackVal[i,] <- trackVal[i,]/sum(nrangesByChr)
	}

	cat("making plot and returning output \n")
	if(!is.null(plotfile)) png(plotfile)
	cat(paste("range of values:",range(trackVal),"\n"))
	plot(trackVal[1,],lty=lty[1],col=col[1],lwd=lwd[1],xlab="relative position",ylab="averaged coverage",type="l",ylim=range(trackVal,na.rm=TRUE))
	if(length(regions)>1){
		for(i in 2:length(regions)){
			points(trackVal[i,],lty=lty[i],col=col[i],lwd=lwd[i],type="l")
		}
	}
	if(!is.null(plotfile)) dev.off()
	trackVal
}
#
## \n
#
bamFiles <- list.files(recursive=T)[grep(".subset.bam",list.files(recursive=T))]
toExclude <- c(".txt",".png","RNA",".pdf","Otx2ko","MEF")
bamFiles[grep(paste(toExclude,collapse="|"),bamFiles)] <- NA
bamFiles <- na.omit(bamFiles)
covObjects <- c()
for(i in 1:length(bamFiles)){
last <- length(strsplit(bamFiles[i],"/")[[1]])
covObjects[i] <- strsplit(bamFiles[i],"/")[[1]][last]
}
covObjects <- gsub("sorted.subset.bam",".cov",covObjects)
covObjects <- gsub(".subset.bam",".cov",covObjects)
for(i in 1:length(bamFiles)){
cat(i,"Reading and removing duplicates from",bamFiles[i],"at",as.character(Sys.time()),"\n",sep=" ")
tmp <- readGAlignments(bamFiles[i], param=ScanBamParam(what="qname"))
tmp <- tmp[!duplicated(tmp@start)]
cat(i,"Coverting",bamFiles[i],"to GRanges and Coverage object at",as.character(Sys.time()),"\n",sep=" ")
tmp.ranges <- as(tmp, "GRanges")
tmp.cov <- coverage(tmp.ranges)
cat(i,"Normalising",bamFiles[i],"to sequencing depth at",as.character(Sys.time()),"\n",sep=" ")
nReads <- length(tmp.ranges)
normFactor <- 10^6/nReads
normCoverage <- tmp.cov*normFactor
assign(covObjects[i],normCoverage)
}