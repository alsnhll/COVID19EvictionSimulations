# This script uses dynamical time warping and heirarchical clustering to classify metropolitan statistical areas (MSA) of >1 million individuals across the US based on the timecourse of cases and deaths. We only applied clustering on data through Sept 1 2020. 
# Before running this, run the getUSAmetroData.R script to download the cases and deaths data from the New York Times and get it in the right form


library(dtw)
library(dendextend)
library(ggbeeswarm)


#Perform clustering ----------- 
#Cluster based on daily new cases and deaths per capita, smoothed

dateEnd="2020-09-01" # Cluster data before this date only; must be a date before the last datapoint in timeseries
dateEndNum=as.numeric(as.Date(dateEnd)-as.Date("2020-01-01")) 

## for deaths ------

#extract only the rows and columns we want, then convert to wide format (columns as timepoints)
metric = "deaths" # Variable to use for clustering, either "deaths" or "cases"
db.toCluster=subset(db.long.dailySmooth,variable==metric,select=c(metro,valueNorm,time)) #select relevant variables
db.toCluster=db.toCluster[db.toCluster$time<dateEndNum,] # remove those beyond date of interest
db.toCluster=cast(db.toCluster,metro ~ time, value = "valueNorm") # wide format

# add row names
temp = db.toCluster 
db.toCluster = temp[,-1]
metroNames = as.character(temp[,1])
rownames(db.toCluster) = metroNames

distMatrixD = dist(db.toCluster, method="dtw") # get distance using dynamic time warping

## for cases-----

#extract only the rows and columns we want, then convert to wide format (columns as timepoints)
metric = "cases" # Variable to use for clustering, either "deaths" or "cases"
db.toCluster=subset(db.long.dailySmooth,variable==metric,select=c(metro,valueNorm,time)) #select relevant variables
db.toCluster=db.toCluster[db.toCluster$time<dateEndNum,] # remove those beyond date of interest
db.toCluster=cast(db.toCluster,metro ~ time, value = "valueNorm") # wide format

# add row names
temp = db.toCluster 
db.toCluster = temp[,-1]
metroNames = as.character(temp[,1])
rownames(db.toCluster) = metroNames

distMatrixC = dist(db.toCluster, method="dtw") # get distance using dynamic time warping

## concatenate cases and deaths distances, after standardization ----

distMatrix = (distMatrixC-min(distMatrixC))/(max(distMatrixC)-min(distMatrixC)) + (distMatrixD-min(distMatrixD))/(max(distMatrixD)-min(distMatrixD))

hc = hclust(distMatrix, method="ward.D") #run heirarchical clustering using Ward's minimum variance
hc$labels = metroNames

# Plot -----
##Plot dendogrram ------

#plot(hc)
#rect.hclust(hc , k = 4) #draw rectangles around cluster

dendObj = as.dendrogram(hc)
#dendObj = color_branches(dendObj, k=numClusters)

numClusters = 4

par(mar = c(5.1, 4.1, 4.1, 20.1)) # Set the margin on all sides to 2
dendObj %>%
  set("labels_col", k=numClusters) %>%
  #set("branches_k_color", k = numClusters) %>% # not working now for some reason
  set("labels_cex", 0.7)  %>%#make font smaller
  plot(horiz=TRUE, axes=FALSE)
#abline(v = 350, lty = 2)

clusterLabels = cutree(hc , k = numClusters, order_clusters_as_data = FALSE) # get labels of each metro

# re-label clusters based on when they diverge from main branch: 1->1, 2->4, 3->3, 4->2
clusterLabels = sapply(clusterLabels,function(x) ifelse(x==2,4,ifelse(x==4,2,x)))

clusterLabels.df = as.data.frame(clusterLabels)
clusterLabels.df$metro = rownames(clusterLabels.df)
rownames(clusterLabels.df) = c()
clusterLabels.df=rename(clusterLabels.df,c(clusterLabels="cluster"))

#bind with population data
clusterLabels.df=distinct(merge(clusterLabels.df,subset(db,select=c("metro","population")),by="metro"))

sumPopByCluster = aggregate(population ~ cluster,data=clusterLabels.df,FUN=sum, na.rm=TRUE)

# Plot timecourses by cluster -----
#one file for each cluster

# smoothed daily cases and deaths, normalized by population

for (i in 1:numClusters) {
  
  pdf(file=paste0(filePath,"/plots/metros_daily_smooth_cluster",i,".pdf"),width=7.5, height=10, paper="letter")
  par(mfrow=c(5,4), mgp=c(2,1,0), mar=c(4,4,3,1)+0.1)
  
  clusterMetro = clusterLabels.df$metro[clusterLabels.df$cluster==i]
  
  for (plotMetro in clusterMetro){
    data=subset(db.long.dailySmooth,metro==plotMetro)
    tvec=data$time[data$variable=='cases']/30.42
    case_vec=data$value[data$variable=='cases'] # FIX, use  VALUE NORM
    death_vec=data$value[data$variable=='deaths']
    pop=data$population[1]/1e6
    plot(tvec, log10(case_vec/pop), main=paste(str_wrap(plotMetro,width=22),collapse = "\n"), ylab=paste(str_wrap("Log10 daily new per 1e6 (smooth)",width=18),collapse = "\n"),
         xlab="Time (months)", ylim=c(-1, 4), xlim=c(0, 12), pch=10, cex=0.5, col=hue_pal()(2)[1], cex.main=1)
    points(tvec, log10(death_vec/pop),col=hue_pal()(2)[2], pch=7,  cex=0.5)
  }
  
  dev.off() #close pdf
  
}

# Compare summary statistics by cluster---------------------------

## Calculate summary statistics for each metro --------------------------------


#create new dataframe
metroStats=clusterLabels.df
metroStats$cluster = as.factor(metroStats$cluster)
metroStatsDeath = metroStats
metroStats$r1 = 0
metroStats$r2 = 0
metroStats$r3 = 0
metroStats$r4 = 0
metroStats$r5 = 0
metroStatsDeath$dmax1 = 0
metroStatsDeath$dmax2 = 0
metroStatsDeath$dmax3 = 0

for (i in 1:nMetro){
  
  thisMetro=metroStats$metro[i]

  # slope of cases
  slopeInt = 14 # of days between measurements for slope
  
  #slope of cases on March 15
  dateStart="2020-03-15" 
  dateStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  valStart=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum & variable=="cases")$valueNorm
  valEnd=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum+slopeInt & variable=="cases")$valueNorm
  r = log(valEnd/valStart)/slopeInt
  
  metroStats$r1[i] = r
  
  #slope of cases on May 1
  dateStart="2020-05-01" 
  dateStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  valStart=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum & variable=="cases")$valueNorm
  valEnd=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum+slopeInt & variable=="cases")$valueNorm
  r = log(valEnd/valStart)/slopeInt
  
  metroStats$r2[i] = r
  
  #slope of cases on June 15
  dateStart="2020-06-15" 
  dateStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  valStart=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum & variable=="cases")$valueNorm
  valEnd=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum+slopeInt & variable=="cases")$valueNorm
  r = log(valEnd/valStart)/slopeInt
  
  metroStats$r3[i] = r
  
  #slope of cases on Aug 15
  dateStart="2020-08-15" 
  dateStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  valStart=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum & variable=="cases")$valueNorm
  valEnd=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum+slopeInt & variable=="cases")$valueNorm
  r = log(valEnd/valStart)/slopeInt
  
  metroStats$r4[i] = r
  
  #slope of cases on Nov 1
  dateStart="2020-11-01" 
  dateStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  valStart=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum & variable=="cases")$valueNorm
  valEnd=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum+slopeInt & variable=="cases")$valueNorm
  r = log(valEnd/valStart)/slopeInt
  
  metroStats$r5[i] = r
  
  #peak deaths pre June 15
  dateStart="2020-06-15" 
  dateStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  dmax = max(subset(db.long.dailySmooth,metro==thisMetro & variable=="deaths" & time<dateStartNum)$valueNorm)
  
  metroStatsDeath$dmax1[i] = dmax
  
  #peak deaths between June 15 - Sept 1
  dateEnd ="2020-09-01" 
  dateEndNum=as.numeric(as.Date(dateEnd)-as.Date("2020-01-01")) 
  dmax = max(subset(db.long.dailySmooth,metro==thisMetro & variable=="deaths" & time>dateStartNum & time<dateEndNum)$valueNorm)
  
  metroStatsDeath$dmax2[i] = dmax
  
  #peak deaths between Sept 1 - present
  dateStart ="2020-09-01" 
  datStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  dmax = max(subset(db.long.dailySmooth,metro==thisMetro & variable=="deaths" & time>dateStartNum)$valueNorm)
  
  metroStatsDeath$dmax3[i] = dmax
  
  
}

# melt all r values and all d values

metroStats = melt(data = metroStats, measure.vars = c("r1", "r2","r3","r4","r5"), variable_name = "growthRate")
metroStats = rename(metroStats,c(value="growthRateValue"))
metroStatsDeath = melt(data = metroStatsDeath, measure.vars = c("dmax1", "dmax2","dmax3"), variable_name = "peakDeaths")
metroStatsDeath = rename(metroStatsDeath,c(value="peakDeathsValue"))

ggplot(metroStats,aes(growthRate, growthRateValue,color=cluster)) + geom_boxplot(outlier.size=0) + geom_quasirandom(dodge.width=0.7) + theme_minimal() + labs(y = "Growth rate (per day)", x = "Time frame")

ggplot(metroStatsDeath,aes(peakDeaths,peakDeathsValue,color=cluster)) + geom_boxplot(outlier.size=0)  + geom_quasirandom(dodge.width=0.7) + theme_minimal() + labs(y = "Peak daily deaths \n per million (smoothed)", x = "Time frame")
#+ stat_summary(fun = "median", geom="crossbar", width=0.5)

sumRates = aggregate(growthRateValue ~ cluster+growthRate,data=metroStats,FUN=median, na.rm=TRUE)
sumRatesAll = aggregate(growthRateValue ~ growthRate,data=metroStats,FUN=median, na.rm=TRUE)
sumRatesAll$cluster = 0
sumRatesAll$cluster = as.factor(sumRatesAll$cluster)
sumRates = rbind(sumRates,sumRatesAll)

sumRates$doublingTimeValue = log(2)/sumRates$growthRateValue

tab.doublingTime=cast(sumRates,cluster~growthRate, value = "doublingTimeValue")
tab.growthRate=cast(sumRates,cluster~growthRate, value = "growthRateValue")

sumDeaths= aggregate(peakDeathsValue ~ cluster+peakDeaths,data=metroStatsDeath,FUN=median, na.rm=TRUE)

tab.deaths=cast(sumDeaths,cluster~peakDeaths, value = "peakDeathsValue")

# ---- get net growth since Oct 1

#create new dataframe
metroStatsFall=clusterLabels.df
metroStatsFall$cluster = as.factor(metroStatsFall$cluster)
metroStatsFall$rfall = 0

for (i in 1:nMetro){
  
  thisMetro=metroStats$metro[i]
  
  #slope of cases between Oct 1 and Dec 1
  dateStart="2020-10-01" 
  dateEnd="2020-12-01" 
  dateStartNum=as.numeric(as.Date(dateStart)-as.Date("2020-01-01")) 
  dateEndNum=as.numeric(as.Date(dateEnd)-as.Date("2020-01-01")) 
  slopeInt = dateEndNum - dateStartNum # of days between measurements for slope
  valStart=subset(db.long.dailySmooth,metro==thisMetro & time==dateStartNum & variable=="cases")$valueNorm
  valEnd=subset(db.long.dailySmooth,metro==thisMetro & time==dateEndNum & variable=="cases")$valueNorm
  r = log(valEnd/valStart)/slopeInt
  
  metroStatsFall$rfall[i] = r
  
}

sumRatesFall = aggregate(rfall ~ cluster,data=metroStatsFall,FUN=median, na.rm=TRUE)

sumRatesFall = rbind(sumRatesFall,data.frame(cluster=as.factor(0),rfall=median(sumRatesFall$rfall)))
sumRatesFall$doublingTime = log(2)/sumRatesFall$rfall


##Plot summary statistics -----

db.long.dailySmooth2=merge(subset(clusterLabels.df,select=-c(population)),db.long.dailySmooth,by="metro")
db.long.dailySmooth2$valueNormLog10 = pmax(log10(db.long.dailySmooth2$valueNorm),-10)

ggplot(db.long.dailySmooth2, aes(x = time, y = valueNormLog10)) + 
  geom_line(aes(color = variable, group = interaction(metro,variable)),alpha=0.3) +
  theme_minimal() + labs(y = "Log10 daily new \n per million (smoothed)", x = "Time (days)") + 
  guides(linetype=FALSE) + facet_wrap(~ cluster) + coord_cartesian(ylim =c(-1, 4)) + stat_summary(fun = "median", aes(color=variable),geom="line")

# something wrong with stat_summary here - claims non-finite and missing values but not true
#+ stat_summary(fun = "median", aes(color=variable),geom="line")
# issue - stat_summary doesn't include in the summary statistic any values outside the yaxis range! dumb but correct using coord_cartesian

# unlogged
ggplot(db.long.dailySmooth2, aes(x = time, y = valueNorm)) +
  geom_line(aes(color = variable, group = interaction(metro,variable)),alpha=0.3) +
  theme_minimal() + labs(y = "Daily new \n per million (smoothed)", x = "Time (days)") +
  guides(linetype=FALSE) + facet_wrap(~ cluster) + ylim(0, 1000) +
  stat_summary(fun = "median", aes(color=variable),geom="line")
# 
# ggplot(db.long.dailySmooth2, aes(x = time, y = valueNorm)) + 
#   geom_line(aes(color = variable, group = interaction(metro,variable)),alpha=0.3) +
#   theme_minimal() + labs(y = "Daily new \n per million (smoothed)", x = "Time (days)") + 
#   guides(linetype=FALSE) + facet_wrap(~ cluster) + ylim(0, 30) + 
#   stat_summary(fun = "median", aes(color=variable),geom="line")


##Save to file ------

write.csv(subset(db.long.dailySmooth2,select=c(metro,time,cluster,variable,valueNorm)),"data/metro_data_by_cluster.csv", row.names = FALSE)

