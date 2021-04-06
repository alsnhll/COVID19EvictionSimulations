# This file imports county-level data on COVID-19 cases and deaths for the US, from the New York Times. Then it aggregates cases into metropolitan statistical areas (MSA; only those with >1 million residents). The key for aggregating counties to MSAs was provided by City Observatory (https://cityobservatory.org/). To correct cases and deaths for certain days where large "data dumps" of backlogged reports were made, we access a spreadsheet maintained in Google Drive that keeps track of these days from news reports, and redistributes these cases. The first time you run the code in a given R session you'll be asked to give R/tidyverse permission to access your Google Drive. After doing this you may need to re-run the code. Note that this code will download and plot data until the current date, whereas in the paper we only analyzed data through Sept 1 2020 (for clustering) or Dec 31 2020 (for inclusion of fall wave). Before running, make sure to update the filePath with your current working folder, and create the subfolders /data and /plots in it

library(plotly)
library(dplyr)
library(reshape)
library(scales)
library(readxl)
library(httr)
library(RCurl)
library(tools)
library(stringr)
library(zoo)
library(googlesheets4)

filePath="~/Documents/Research/COVID19/Eviction/code" # Update this file path
startDate="2020-01-01" # date to start counting cases and deaths, ignore before

# Load New York Times database----------------------------------------------------------

# US county-level data on cases/deaths, collapsed for each state, filling in missing dates

#Load data
usaCountyNYT = read.csv(text = getURL("https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv"))

db=usaCountyNYT
db=subset(db,state != "American Samoa" & state !="Guam" & state !="Northern Mariana Islands" & state!="Virgin Islands") #get rid of overseas territories

varNames=c("state", "county","fips","date","cases", "deaths") #sort columns
db = db[varNames]

# Group counties into metro areas ----------------------------------------------------

msaKey=as.data.frame(read_excel(paste0(filePath,"/data/MSAByCountyCityObservatory.xlsx"))) 
msaKey=subset(msaKey,select=c("FIPS","Popln2018","CBSACode","CBSATitle",'Top53'))
msaKey=rename(msaKey, c(FIPS="fips",Popln2018='populationCounty'))

# Deal with city data that is reported separately from their counties
#   -NYC data - instead of being listed as 5 separate counties (Manhattan, Brooklyn, The Bronx, Staten  Island, Queens), it is listed as a single "New York City" county with no FIPS code. In the MSA key, these are all grouped into the Manhatten County under FIPS 36061
db$fips[db$county == 'New York City'] = 36061

#   -Kansas City - cases that occur within the city boundaries are reported as a made up "Kansas City"  county instead of being listed in one of the four counties that partially overlap with the city. Add all these cases to Jackson County, 29095
db$fips[db$county == 'Kansas City'] = 29095

db=merge(db,msaKey,by="fips") 

db=subset(db,Top53==1)
db=db[order(db$CBSACode,db$date),]

db=aggregate(cbind(cases,deaths) ~ date + CBSATitle + Top53, db,sum)
db=subset(db,select=-c(Top53))
db$date=as.Date(db$date) # put in date data type
db$time=rep(0,nrow(db))
db$newCases=rep(0,nrow(db))
db$newDeaths=rep(0,nrow(db))

varNames=c("CBSATitle", "date", "time", "cases", "newCases", "deaths","newDeaths") #sort columns
db = db[varNames]
db=rename(db, c(CBSATitle='metro'))
db$metro=as.factor(db$metro)

# Calculate daily new cases and deaths --------------------------------------------------

uniqMetro=as.character(unique(db$metro)) #unique metro
nMetro=length(uniqMetro)
db$population=rep(0,nrow(db))

for (metro in uniqMetro){
  
  print(metro)
  thisMetro = which(db$metro == metro) #indices of that metro area
  
  # get total popualation of that metro
  db[thisMetro,"population"]=sum(msaKey$populationCounty[msaKey$CBSATitle==metro], na.rm=TRUE)
  
  # first reporting day
  db[thisMetro[1],"newCases"]=db[thisMetro[1],"cases"] 
  db[thisMetro[1],"deaths"]=db[thisMetro[1],"deaths"] 
  
  #all other days
  db[thisMetro[2:length(thisMetro)],"newCases"]=db[thisMetro[2:length(thisMetro)],"cases"]-db[thisMetro[1:(length(thisMetro)-1)],"cases"]
  db[thisMetro[2:length(thisMetro)],"newDeaths"]=db[thisMetro[2:length(thisMetro)],"deaths"]-db[thisMetro[1:(length(thisMetro)-1)],"deaths"]
  
  db[thisMetro,"time"]=seq(1,length(thisMetro))
  
}

# Find and correct negative incidence values. 
# Method: Estimate what true incidence should have been (= to next day), then distribute net negative cases across all previous days of epidemic, proporational to their case loads. Note that due to rounding cases to integars when distributing, the cumulative case counts will be slightly off the sum of the incidence values

negNewCases=which(db$newCases < 0)

if (length(negNewCases!=0)){
  
  for (index in negNewCases){
    
    print("Negative new cases occured:")
    print(db[(index-1):(index+1),])
    
    trueNewCases = db$newCases[index-7] # assume equal to value reported 1 week ago
    numNegCases = trueNewCases-db$newCases[index]# total cases removed that day
    fracNegCases = numNegCases/db$cases[index] # fraction of total cumulative cases that were removed
    ind1 = which(db$time==1 & db$metro==db$metro[index]) #get index of day 1
    db$newCases[(ind1+1):(index-1)] = round((1-fracNegCases)*db$newCases[(ind1+1):(index-1)]) # distributed removed cases over all previous days (except first day)
    db$cases[(ind1+1):(index-1)] = cumsum(db$newCases[(ind1+1):(index-1)]) #update the cumulative case counts accordingly
    db$newCases[index] = trueNewCases # assume equal to value reported the next day
 
    print("corrected to:")
    print(db[(index-1):(index+1),])
  }
}

negNewDeaths=which(db$newDeaths < 0)

if (length(negNewDeaths!=0)){
  
  for (index in negNewDeaths){
    
    print("Negative new deaths occured:")
    print(db[(index-1):(index+1),])
    
    trueNewDeaths = db$newDeaths[index-7] # assume equal to value reported 1 week ago
    numNegDeaths = trueNewDeaths-db$newDeaths[index]# total deaths removed that day
    fracNegDeaths = numNegDeaths/db$deaths[index] # fraction of total cumulative deaths that were removed
    ind1 = which(db$time==1 & db$metro==db$metro[index]) #get index of day 1
    db$newDeaths[(ind1+1):(index-1)] = round((1-fracNegDeaths)*db$newDeaths[(ind1+1):(index-1)]) # distributed removed deaths over all previous days (except first day)
    db$deaths[(ind1+1):(index-1)] = cumsum(db$newDeaths[(ind1+1):(index-1)]) #update the cumulative death counts accordingly
    db$newDeaths[index] = trueNewDeaths # assume equal to value reported the next day
    
    print("corrected to:")
    print(db[(index-1):(index+1),])
  }
}

# Correct data dumps -----------------------------------------------------------

# Find and correct days in which large numbers of previously unreported cases were dumped on a single day. Then, distribute these cases over all previous days, proportional to the incidence of cases or deaths that occurred on that day, out of all days before the dump
# We maintain this spreadsheet as a public Google Drive link. Dates of dumps were obtained from the New York Times (links provided in sheet). It was updated through Dec 17 2020, and may not be current beyond that

dumpDates=read_sheet("https://docs.google.com/spreadsheets/d/1iC1ZmryWd5gqlvEHe4BX3ZlcIrC3yMCr_PSom-dRpa4/edit",sheet="Dumps")
dumpDates=as.data.frame(dumpDates)
dumpDates$Date=as.Date(dumpDates$Date)

# for metro level dumps

metroDumps = which(!is.na(dumpDates$Metro))

for (i in metroDumps){
  
  index = which(db$metro == dumpDates$Metro[i] & db$date == dumpDates$Date[i])
  
  #case dumps
  if (dumpDates$Variable[i]=='Cases'){
   
    print("Dump of new cases occured:")
    print(db[(index-1):(index+1),])
    
    trueNewCases = db$newCases[index+1] # assume equal to value reported the next day
    numDumpCases = db$newCases[index]-trueNewCases # total cases dumped that day
    fracDumpCases = numDumpCases/db$cases[index] # fraction of total cumulative cases that were dumped
    ind1 = which(db$time==1 & db$metro==db$metro[index]) #get index of day 1
    db$newCases[(ind1+1):(index-1)] = round((1+fracDumpCases)*db$newCases[(ind1+1):(index-1)]) # distributed dumped cases over all previous days (except first day)
    db$cases[(ind1+1):(index-1)] = cumsum(db$newCases[(ind1+1):(index-1)]) #update the cumulative case counts accordingly
    db$newCases[index] = trueNewCases # assume equal to value reported the next day
    
    print("corrected to:")
    print(db[(index-1):(index+1),]) 
    
  }
  # death dumps
  if (dumpDates$Variable[i]=='Deaths'){
    
    print("Dump of new deaths occured:")
    print(db[(index-1):(index+1),])
    
    trueNewDeaths = db$newDeaths[index+1] # assume equal to value reported the next day
    numDumpDeaths = db$newDeaths[index]-trueNewDeaths # total deaths dumped that day
    fracDumpDeaths = numDumpDeaths/db$deaths[index] # fraction of total cumulative deaths that were dumped
    ind1 = which(db$time==1 & db$metro==db$metro[index]) #get index of day 1
    db$newDeaths[(ind1+1):(index-1)] = round((1+fracDumpDeaths)*db$newDeaths[(ind1+1):(index-1)]) # distributed dumped cases over all previous days (except first day)
    db$deaths[(ind1+1):(index-1)] = cumsum(db$newDeaths[(ind1+1):(index-1)]) #update the cumulative case counts accordingly
    db$newDeaths[index] = trueNewDeaths # assume equal to value reported the next day
    
    print("corrected to:")
    print(db[(index-1):(index+1),]) 
    
  }
}

# for state level dumps

stateDumps = which(!is.na(dumpDates$State))

for (i in stateDumps){
  
  metrosInThisState = which(grepl(dumpDates$State[i],db$metro) & db$date == dumpDates$Date[i]) # find metros with this state in their name
  
  for (index in metrosInThisState){
    
    #case dumps
    if (dumpDates$Variable[i]=='Cases'){
      
      print("Dump of new cases occured:")
      print(db[(index-1):(index+1),])
      
      trueNewCases = db$newCases[index+1] # assume equal to value reported the next day
      numDumpCases = db$newCases[index]-trueNewCases # total cases dumped that day
      fracDumpCases = numDumpCases/db$cases[index] # fraction of total cumulative cases that were dumped
      ind1 = which(db$time==1 & db$metro==db$metro[index]) #get index of day 1
      db$newCases[(ind1+1):(index-1)] = round((1+fracDumpCases)*db$newCases[(ind1+1):(index-1)]) # distributed dumped cases over all previous days (except first day)
      db$cases[(ind1+1):(index-1)] = cumsum(db$newCases[(ind1+1):(index-1)]) #update the cumulative case counts accordingly
      db$newCases[index] = trueNewCases # assume equal to value reported the next day
      
      print("corrected to:")
      print(db[(index-1):(index+1),]) 
      
    }
    # death dumps
    if (dumpDates$Variable[i]=='Deaths'){
      
      print("Dump of new deaths occured:")
      print(db[(index-1):(index+1),])
      
      trueNewDeaths = db$newDeaths[index+1] # assume equal to value reported the next day
      numDumpDeaths = db$newDeaths[index]-trueNewDeaths # total deaths dumped that day
      fracDumpDeaths = numDumpDeaths/db$deaths[index] # fraction of total cumulative deaths that were dumped
      ind1 = which(db$time==1 & db$metro==db$metro[index]) #get index of day 1
      db$newDeaths[(ind1+1):(index-1)] = round((1+fracDumpDeaths)*db$newDeaths[(ind1+1):(index-1)]) # distributed dumped cases over all previous days (except first day)
      db$deaths[(ind1+1):(index-1)] = cumsum(db$newDeaths[(ind1+1):(index-1)]) #update the cumulative case counts accordingly
      db$newDeaths[index] = trueNewDeaths # assume equal to value reported the next day
      
      print("corrected to:")
      print(db[(index-1):(index+1),]) 
      
    }
    
  }
  
}



#Standardize times ------------------------------------------------------------------------

# standardize all times relative to defined start date, remove times before that
db$time=as.numeric(db$date-as.Date(startDate))
db=db[db$time>=0,]

# add in zeros for before startDate if day of 1st case was afterStartDate

for (thisMetro in uniqMetro){
  metroData=subset(db,db$metro==thisMetro)
  firstTime=metroData$time[1]
  if (firstTime>0){
    temp=as.data.frame(matrix(0,firstTime,ncol(db))) #create empty matrix to concatenate as new columns
    colnames(temp)=colnames(db)
    temp$metro=thisMetro
    temp$time=0:(firstTime-1)
    temp$date=as.Date(temp$time,origin=startDate)
    temp$population=metroData$population[1]
    db=rbind(db,temp)
  }
}

# now fix the order
db=db[order(db$metro,db$date),]

# Make long form vectors that combine cases and deaths as factors Cumulative and Daily variables

db.long.cumul=melt(subset(db,select=-c(newCases,newDeaths)),id=c("date","time","metro","population"))
db.long.daily=melt(subset(db,select=-c(cases,deaths)),id=c("date","time","metro","population"))
levels(db.long.daily$variable)=c("cases","deaths")

# Smooth data --------- -------------------------------------------------------

db$newCasesSmooth = 0
db$newDeathsSmooth = 0

for (metro in uniqMetro){
  
  thisMetro = which(db$metro == metro) #indices of that metro area
  
  #db[thisMetro,"newCasesSmooth"]=round(rollmean(db[thisMetro,"newCases"],7,fill=c("extend",NA,"extend")))
  #db[thisMetro,"newDeathsSmooth"]=round(rollmean(db[thisMetro,"newDeaths"],7,fill=c("extend",NA,"extend")))
  
  db[thisMetro,"newCasesSmooth"]=rollmean(db[thisMetro,"newCases"],7,fill=c("extend",NA,"extend"))
  db[thisMetro,"newDeathsSmooth"]=rollmean(db[thisMetro,"newDeaths"],7,fill=c("extend",NA,"extend"))

}

db.long.dailySmooth=melt(subset(db,select=-c(cases,deaths,newCases,newDeaths)),id=c("date","time","metro","population"))
levels(db.long.dailySmooth$variable)=c("cases","deaths")

# Plots (Plotly, interactive/HTML) -------------------------------------------------------

## For one metro only --------- 

#plotMetro=uniqMetro[33]
plotMetro="Philadelphia-Camden-Wilmington, PA-NJ-DE-MD"

 ### Cumulative --------- 
pCum=plot_ly(data=subset(db.long.cumul,metro==plotMetro), x =~date, y=~value, color=~variable, legendgroup=~variable, type='scatter', mode='lines+markers', colors=hue_pal()(2))
pCum=layout(pCum,xaxis=list(title="Date"),yaxis=list(title="Cumulative number",type="log"), title = plotMetro
)

 ### Daily --------- 
# pDaily=plot_ly(data=subset(db.long.daily,metro==plotMetro), x =~time, y=~value, color=~variable, legendgroup=~variable, type='scatter', mode='lines+markers', colors=hue_pal()(2), showlegend = FALSE)
# pDaily=layout(pDaily,xaxis=list(title="Time since first reported case (days)"),yaxis=list(title="Daily new",type="log"), title = plotMetro
# )

### Daily smoothed --------------------------------------------------
pDaily=plot_ly(data=subset(db.long.dailySmooth,metro==plotMetro), x =~date, y=~value, color=~variable, legendgroup=~variable, type='scatter', mode='lines+markers', colors=hue_pal()(2), showlegend = FALSE)
pDaily=layout(pDaily,xaxis=list(title="Date"),yaxis=list(title="Daily new (smoothed)",type="log"), title = plotMetro
)

fig=subplot(pCum,pDaily, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
fig

# ------------------Now normalized per million

pop=subset(db,metro==plotMetro)$population[1]/1e6

### Normalized + Cumulative---------------
pCum=plot_ly(data=subset(db.long.cumul,metro==plotMetro), x =~date, y=~value/pop, color=~variable, legendgroup=~variable, type='scatter', mode='lines+markers', colors=hue_pal()(2))
pCum=layout(pCum,xaxis=list(title="Date"),yaxis=list(title="Cumulative number per 1e6",type="log"), title = plotMetro
)

### Normalized + Daily ---------
# pDaily=plot_ly(data=subset(db.long.daily,metro==plotMetro), x =~date, y=~value/pop, color=~variable, legendgroup=~variable, type='scatter', mode='lines+markers', colors=hue_pal()(2), showlegend = FALSE)
# pDaily=layout(pDaily,xaxis=list(title="Date"),yaxis=list(title="Daily new per 1e6",type="log"), title = plotMetro
# )

### Normalized + Daily smoothed -----------------------
pDaily=plot_ly(data=subset(db.long.dailySmooth,metro==plotMetro), x =~date, y=~value/pop, color=~variable, legendgroup=~variable, type='scatter', mode='lines+markers', colors=hue_pal()(2), showlegend = FALSE)
pDaily=layout(pDaily,xaxis=list(title="Date"),yaxis=list(title="Daily new per 1e6 (smoothed)",type="log"), title = plotMetro
)

fig=subplot(pCum,pDaily, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
fig

##For all metros --------------------------------------------------

color.vec=gradient_n_pal(brewer_pal(type="div",palette="Spectral")(11))(seq(0, 1, length.out = nMetro))

###Cumulative --------------------------------------------------

#### vs time since first case --------

# pCumCases=plot_ly(data=subset(db.long.cumul,variable=='cases'), x =~time, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
# pCumCases=layout(pCumCases,xaxis=list(title="Time since first reported case (days)"),yaxis=list(title="Cumulative cases",type="log"))
# 
# pCumDeaths=plot_ly(data=subset(db.long.cumul,variable=='deaths'), x =~time, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
# pCumDeaths=layout(pCumDeaths,xaxis=list(title="Time since first reported case (days)"),yaxis=list(title="Cumulative deaths",type="log"))
# 
# figCum=subplot(pCumCases,pCumDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
# figCum

#### vs date ----------------
pCumCases=plot_ly(data=subset(db.long.cumul,variable=='cases'), x =~date, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
pCumCases=layout(pCumCases,xaxis=list(title="Date"),yaxis=list(title="Cumulative cases",type="log"))

pCumDeaths=plot_ly(data=subset(db.long.cumul,variable=='deaths'), x =~date, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
pCumDeaths=layout(pCumDeaths,xaxis=list(title="Date"),yaxis=list(title="Cumulative deaths",type="log"))

figCum=subplot(pCumCases,pCumDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
figCum

#htmlwidgets::saveWidget(figCum, file.path(paste0(getwd(),"/plots"), 'metros_cumulative.html'))


###Daily---------

#### vs time since first case----------

# pDailyCases=plot_ly(data=subset(db.long.daily,variable=='cases'), x =~time, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
# pDailyCases=layout(pDailyCases,xaxis=list(title="Time since first reported case (days)"),yaxis=list(title="Daily cases",type="log"))
# 
# pDailyDeaths=plot_ly(data=subset(db.long.daily,variable=='deaths'), x =~time, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
# pDailyDeaths=layout(pDailyDeaths,xaxis=list(title="Time since first reported case (days)"),yaxis=list(title="Daily deaths",type="log"))
# 
# figDaily=subplot(pDailyCases,pDailyDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
# figDaily


#### vs date -----------------

# pDailyCases=plot_ly(data=subset(db.long.daily,variable=='cases'), x =~date, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
# pDailyCases=layout(pDailyCases,xaxis=list(title="Date"),yaxis=list(title="Daily cases",type="log"))
# 
# pDailyDeaths=plot_ly(data=subset(db.long.daily,variable=='deaths'), x =~date, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
# pDailyDeaths=layout(pDailyDeaths,xaxis=list(title="Date"),yaxis=list(title="Daily deaths",type="log"))
# 
# figDaily=subplot(pDailyCases,pDailyDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
# figDaily
#     
#htmlwidgets::saveWidget(figDaily, file.path(paste0(getwd(),"/plots"), 'metros_daily.html'))

###Daily Smoothed --------------------------------------------------
# pDailyCases=plot_ly(data=subset(db.long.dailySmooth,variable=='cases'), x =~date, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
# pDailyCases=layout(pDailyCases,xaxis=list(title="Date"),yaxis=list(title="Daily cases (smoothed)",type="log"))
# 
# pDailyDeaths=plot_ly(data=subset(db.long.dailySmooth,variable=='deaths'), x =~date, y=~value, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
# pDailyDeaths=layout(pDailyDeaths,xaxis=list(title="Date"),yaxis=list(title="Daily deaths (smoothed)",type="log"))
# 
# figDaily=subplot(pDailyCases,pDailyDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
# figDaily


### Normalized + Daily -------------

####vs date----------------
# 
# db.long.daily$valueNorm = (1e6)*db.long.daily$value/db.long.daily$population
# 
# pDailyCases=plot_ly(data=subset(db.long.daily,variable=='cases'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
# pDailyCases=layout(pDailyCases,xaxis=list(title="Date"),yaxis=list(title="Daily cases per million",type="log"))
# 
# pDailyDeaths=plot_ly(data=subset(db.long.daily,variable=='deaths'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
# pDailyDeaths=layout(pDailyDeaths,xaxis=list(title="Date"),yaxis=list(title="Daily deaths per million",type="log"))
# 
# figDaily=subplot(pDailyCases,pDailyDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
# figDaily

### Normalized + Daily Smoothed-------------
####vs date---------

db.long.dailySmooth$valueNorm = (1e6)*db.long.dailySmooth$value/db.long.dailySmooth$population

pDailyCases=plot_ly(data=subset(db.long.dailySmooth,variable=='cases'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
pDailyCases=layout(pDailyCases,xaxis=list(title="Date"),yaxis=list(title="Daily cases per million (smoothed)",type="log"))

pDailyDeaths=plot_ly(data=subset(db.long.dailySmooth,variable=='deaths'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
pDailyDeaths=layout(pDailyDeaths,xaxis=list(title="Date"),yaxis=list(title="Daily deaths per million (smoothed)",type="log"))

figDaily=subplot(pDailyCases,pDailyDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
figDaily

####vs date(linear scale) ----

# db.long.dailySmooth$valueNorm = (1e6)*db.long.dailySmooth$value/db.long.dailySmooth$population
# 
# pDailyCases=plot_ly(data=subset(db.long.dailySmooth,variable=='cases'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
# pDailyCases=layout(pDailyCases,xaxis=list(title="Date"),yaxis=list(range = c(0,1200),title="Daily cases per million (smoothed)",type="linear"))
# 
# pDailyDeaths=plot_ly(data=subset(db.long.dailySmooth,variable=='deaths'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
# pDailyDeaths=layout(pDailyDeaths,xaxis=list(title="Date"),yaxis=list(range = c(0,50),title="Daily deaths per million (smoothed)",type="linear"))
# 
# figDaily=subplot(pDailyCases,pDailyDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
# figDaily
# 
# #htmlwidgets::saveWidget(figDaily, file.path(paste0(getwd(),"/plots"), 'metros_daily_smooth_norm.html'))

### Normalized + Cumulative -----

#### vs date -------

db.long.cumul$valueNorm = (1e6)*db.long.cumul$value/db.long.cumul$population

pCumCases=plot_ly(data=subset(db.long.cumul,variable=='cases'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec)
pCumCases=layout(pCumCases,xaxis=list(title="Date"),yaxis=list(title="Cumulative cases per million",type="log"))

pCumDeaths=plot_ly(data=subset(db.long.cumul,variable=='deaths'), x =~date, y=~valueNorm, color=~metro, legendgroup=~metro, type='scatter', mode='lines',colors=color.vec, showlegend = FALSE)
pCumDeaths=layout(pCumDeaths,xaxis=list(title="Date"),yaxis=list(title="Cumulative deaths per million",type="log"))

figCum=subplot(pCumCases,pCumDeaths, shareX = TRUE, titleX=TRUE, shareY=FALSE, titleY=TRUE, margin = 0.05)
figCum

#htmlwidgets::saveWidget(figCum, file.path(paste0(getwd(),"/plots"), 'metros_cumulative_norm.html'))


## Plots (static/PDF) ---------------------- 

### Cumulative --------
pdf(file=paste0(filePath,"/plots/metros_cumulative.pdf"),width=7.5, height=10, paper="letter")
par(mfrow=c(5,4))

for (plotMetro in uniqMetro){
  data=subset(db.long.cumul,metro==plotMetro)
  tvec=data$time[data$variable=='cases']/30.42
  case_vec=data$value[data$variable=='cases']
  death_vec=data$value[data$variable=='deaths']
  pop=data$population[1]/1e6
  ymax=max(ceiling(log10(max(case_vec/pop))),1) # upper limit of y axis, max included to deal with states with no cases
  plot(tvec, log10(case_vec/pop), main=paste(str_wrap(plotMetro,width=22),collapse = "\n"), ylab="Log10 cumulative # per 1e6",
       xlab="Time (months)", ylim=c(0, 6), #xlim=c(0, 12), 
       pch=10, cex=0.5, col=hue_pal()(2)[1], cex.main=1)
  points(tvec, log10(death_vec),col=hue_pal()(2)[2], pch=7,  cex=0.5)
}

dev.off() #close pdf

### Daily -----

pdf(file=paste0(filePath,"/plots/metros_daily.pdf"),width=7.5, height=10, paper="letter")
par(mfrow=c(5,4))

for (plotMetro in uniqMetro){
  data=subset(db.long.daily,metro==plotMetro)
  tvec=data$time[data$variable=='cases']/30.42
  case_vec=data$value[data$variable=='cases']
  death_vec=data$value[data$variable=='deaths']
  pop=data$population[1]/1e6
  ymax=max(ceiling(log10(max(case_vec/pop))),1) # upper limit of y axis, max included to deal with states with no cases
  plot(tvec, log10(case_vec/pop), main=paste(str_wrap(plotMetro,width=22),collapse = "\n"), ylab="Log10 daily new # per 1e6",
       xlab="Time (months )", ylim=c(0, 6), #xlim=c(0, 12), 
       pch=10, cex=0.5, col=hue_pal()(2)[1], cex.main=1)
  points(tvec, log10(death_vec),col=hue_pal()(2)[2], pch=7,  cex=0.5)
}

dev.off() #close pdf

### Normalized + Daily Smoothed -----

pdf(file=paste0(filePath,"/plots/metros_daily_smooth.pdf"),width=7.5, height=10, paper="letter")
par(mfrow=c(5,4), mgp=c(2,1,0), mar=c(4,4,3,1)+0.1)

for (plotMetro in uniqMetro){
  data=subset(db.long.dailySmooth,metro==plotMetro)
  tvec=data$time[data$variable=='cases']/30.42
  case_vec=data$value[data$variable=='cases']
  death_vec=data$value[data$variable=='deaths']
  pop=data$population[1]/1e6
  plot(tvec, log10(case_vec/pop), main=paste(str_wrap(plotMetro,width=22),collapse = "\n"), ylab=paste(str_wrap("Log10 daily new per 1e6 (smooth)",width=18),collapse = "\n"),
       xlab="Time (months)", ylim=c(0, 4), #xlim=c(0, 12), 
       pch=10, cex=0.5, col=hue_pal()(2)[1], cex.main=1, panel.first = grid())
  points(tvec, log10(death_vec/pop),col=hue_pal()(2)[2], pch=7,  cex=0.5)
}

dev.off() #close pdf

