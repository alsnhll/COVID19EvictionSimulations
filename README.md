# COVID19EvictionSimulations
Simulates the impact of evictions on the spread of SARS-CoV-2

## Background

The COVID-19 epidemic has caused an unprecedented public health and economic crisis in the United States. One of the impacts of record levels of unemployement is the looming __eviction crisis__, in which hundreds of thousands of Americans are at risk of losing their homes due to the inability to pay rent [Layser et al](https://papers.ssrn.com/abstract=3613789). Many cities and states enacted temporarily legislation banning evictions during the intial months of the pandemic, but the majority of these are set to expire soon, despite the fact that the epidemic is far from under control. Evictions have many detrimental effects on households, but we are particularly worried about how evictions could accelerate the spread of SARS-CoV-2. Studies show that when people are evicted, they tend to "double-up" with other households, effectively increasing household size and household crowding. Many previous studies as well as our previous modeling work show how household spread is a major driver of SARS-CoV-2 spread and a major challenge to social-distancing-based control policies. Larger households lead to both more possiblities for the introduction of the virus into the household as well as more opportunities for spread within households. 

Here we use a mathematical model of COVID-19 spread to predict the potential impact of evictions on the epidemic course, both for individuals experiencing evictions and for the population as a whole. This is all very much a work-in-progress, and we will update results as they come. We are currently preparing pre-print with these findings, but given the time-sensitive nature of expiring eviction moratoriums, we opted to get our results out there sooner rather than later. 

This work was conceived of by [Mike Levy](https://www.dbei.med.upenn.edu/bio/michael-z-levy-phd) (UPenn) and the majority of the modeling work was done by [Justin Sheen ](https://github.com/jsheen)(UPenn). Justin has an earlier version of the code on his Github. [Anjalika Nande](https://github.com/anjalika-nande) and I (Harvard) contributed to the modeling, and the simulation code we use was created with the help of Ben Adlam. Additional input into the conception of the project was provided by urban policy experts [Andrew Greenlee](https://urban.illinois.edu/people/profiles/andrew-greenlee/) and [Daniel Schneider](https://urban.illinois.edu/people/profiles/daniel-schneider/) (UIUC), [Community Legal Services of Philadelphia](https://clsphila.org/), and research assistance was provided by Maria Tejeda and Julianna Schinnick (UPenn). 

## Methods

Roughly, the model we use consists of two parts: a network describing the contacts between individuals over which disease can potentially spread, and an infection model describing the stages of COVID-19 an individual passes through if infected. The model is stochastic and coded in Python, and is informed by many studies of COVID-19.Details of this model are described extensively in our pre-print [Dynamics of COVID-19 under social distancing measures are driven by transmission network structure](https://www.medrxiv.org/content/10.1101/2020.06.04.20121673v1), which has many references motivating the choices we made. We summarize the main features here

### Contact network

* We divide contacts into 2 types: household or external. The distribution of household sizes is taken from the US census and we assume an individual has equal rate of contact with everyone in their household
* Individuals are connected to a random subset of other individuals in the population. The number of external contacts of each individual at baseline is chosen from a distribution informed by contact surveys and scaled to give the desired parameters described below. Each individual has an equal rate of contact with each of their external contacts. 
* External contacts can be removed/downweighted based on social distancing measures implemented during the epidemic (such as lockdowns, workplace or school closures, mask wearing, etc)
* The probability of disease transmission per contact may be different for household vs external contacts, and is informed by numbers from epidemiological investigations
* We use a population size of 1 million individuals 

### Infection model

We use an SEIRD model:
* S: susceptible individuals
* E: "exposed" individuals who are infected but not yet infections ('latent period')
* I: infected individuals. Subclassified into those with mild/asympomatic infection (I1), and those hospitalized with severe or critical infection (I2, I3). We only consider transmission from individuals who are not hospitalized (I1)
* R: recovered individuals, assumed to be immune
* D: deceased individuals. 

We assume the following parameters. 
* Average duration of latent period - 4 days (we assume this begins on average 1 day before symptom onset)
* Average duration of infectious period - 7 days (1 day presymptomatic transmission + 6 days symptomatic/asymptomatic transmission)
* Average duration of time to death (I1 + I2 + I3) - 20 days
* Fraction of individuals requring any hospitalization: 5%
* Fraction of individuals requring critical care: 2%
* Fraction of all individuals who will die (infection fatality risk, IFR): 1%
* The durations of all infection stages are gamma distributed

Furthermore, we estimate the per contact per day infection rate ($Beta$) for both household and external contacts, as well as the effective number of external contacts, by calibrating the model to give
* An overall basic reproduction number before interventions of R<sub>0</sub> = 3 (corresponding to early epidemic doubling time ~5 days)
* A household secondary attack rate of 0.3
* A relative rate of transmission within households vs outside households of $Beta$<sub>HH</sub>/$Beta$<sub>EX</sub>=2.3

### Control measures

The timelines for COVID-19 spread and control were inspired by the different scenarios that played out across major US metro areas (see pdf in directory for these trajectories for the 50 largest metro areas). We found that these could roughly be classified into a few different patterns, and we tried to roughly emulate those. 

We simulate control measures by downweighting all external contacts by a fixed percentage described by the intervention efficacy (basically equivalent to randomly deleting a certain percentage of external contacts). We consider the following intervention scenarios
* A __strong lockdown__ implemented on April 1, when the cumulative prevalence of infection was ~ 1%, the cumulative deaths ~ 3/million, and around 100 cumulative hospitalizations, which reduced external connections by __90%__
* Alternatively, we allowed a __weak lockdown__ implemented on April 1, when the cumulative prevalence of infection was ~ 0.2%, the cumulative deaths < 1/million, and around 10 cumulative hospitalizations, which reduced external connections by __80%__
* 2 months after the lockdown (June 1), we allowed for a __relxation__, which reduced the efficacy of the intervention to either __80%__ ('plateau'), __75%__ ('comeback'), or __75%__ ('second wave')
* In some scenarios we allowed for a __second lockdown__, occuring in Nov 1, which always had __90%__ efficacy ('strong')

### Evictions

Evictions were modeled by choosing another random household from the population for the evicted household to _merge_ with (see Figure), creating one larger household. No changes to external connections were made. All evictions for the month took place on the first of the month. The __eviction rate__ parameter we use is the percent of all households experiencing eviction each month. 

To estimate the range of possible eviction rates across US cities, we used data from [Eviction Lab](https://evictionlab.org/). Note that eviction rates are often expressed as rates _per rental household_; we additionally use the % of renter households to adjust this rate to total population. Evictions filings have already increased dramatically due to COVID-19, and to estimate how much larger than baseline eviction rates could be, we looked at the fold-increase in unemployement in the same cities (compared to 2019) and assumed that the increase in eviction rates (without any policies preventing evictions) could be increased by the same amount. Unemployement data was from the [Bureau of Labor Statistics](https://www.bls.gov/) via [Department of Numbers](https://www.deptofnumbers.com/unemployment/).

If evictions took place, they occurred starting Sept 1 and continued monthly for the duration of the simulation. 

We consider the following eviction rates: 0% (comparison case) 0.1%, 0.25%, 0.5%, 1%, 2%/month. Because evictions have been blocked in many regions for the past few months and have created a backlog that would have priority if current moratoriums were removed, we assumed that in the first month of evictions (Sept 1), 4 months worth of evictions occured all at once. 

![Network diagram with evictions](hhnetworks.pdf)
__Figure 1__: 

Figure: eviction rates

### Other parameters

* Each simulation was initially seeded with 10 infected individuals

## Results


Figure:
Table: 

* mention and cite Mike affidavit

## Discussion


shelters
