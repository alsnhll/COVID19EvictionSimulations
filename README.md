# COVID19EvictionSimulations
Repository for stochastic network simulations, simulating the impact of evictions on the spread of SARS-CoV-2

## Description
Python code used to generate simulations in 'The effect of eviction moratoriums on the transmission of SARS-CoV-2' - Justin Sheen, Anjalika Nande, Emma L Walters, Ben Adlam, Andrei Gheorghe, 
Julianna Schinnick, Maria Flor Tejeda, Andrew Greenlee, Daniel Schneider, Alison L. Hill, Michael Z. Levy (preprint.pdf).

## Abstract
Massive unemployment during the COVID-19 pandemic could result in an eviction crisis in US cities. Here we model the effect of evictions on SARS-CoV-2 epidemics, simulating viral transmission within and among households in a theoretical metropolitan area. We recreate a range of urban epidemic trajectories and project the course of the epidemic under two counterfactual scenarios, one in which a strict moratorium on evictions is in place and enforced, and another in which evictions are allowed to resume at baseline or increased rates. We find, across scenarios, that evictions lead to significant increase in infections. Applying our model to Philadelphia using locally-specific parameters shows that the increase is especially profound in models that consider realistically heterogenous cities in which both evictions and contacts occur more frequently in poorer neighborhoods. Our results provide a basis to assess municipal eviction moratoriums and show that policies to stem evictions are a warranted and important component of COVID-19 control. 

## Contents
* eviction_doubling_homogeneous.ipynb : This iPython notebook was used to simulate the effects of evictions in a homogeneous population, corresponding to figure 2 and 3 in the main text.
* eviction_doubling_2clusters.ipynb : This iPython notebook contains the simulations that involved a heterogeneous population, divided into 2 clusters (high and low socio-economic status). This corresponds to figure 4 in the main text.
* eviction_doubling_3clusters.ipynb : Simulations involving our case study of Philadelphia are in this iPython notebook. This corresponds to figure 5 in the main text.
* eviction_doubling_shelters_homogeneous.ipynb : This iPython notebook was used to simulate the effect of homelessness in addition to doubling of households due to evictions and was used to generate figure S12 in the supplement. 
* plotting_examples.ipynb : We provide example code that was used to generate all the figures in the main text.

## Code
All the code used to run these analyses are in the form of Jupyter Notebooks running Python code, and are designed to be run on Google Colab. 
The code is divided into a few different notebooks, with similar pre-ambles but then slightly different scenarios simulated. 
The file paths (used to save output) should work if you create a directory in your Google Drive called "COVID19 Eviction Modeling". 
The code imports a module (.py file with multiple functions defined) that we keep on Github in a public repository ('alsnhll/COVID19NetworkSimulations') - you can access it by entering your own Github account when Colab prompts you to. 
The code is optimized to run on a GPU, which you can select from the main menu using Runtime > Change Runtime type. It works best on a Colab Pro account. 
If you run many simulations in a row without restarting the runtime, you can sometimes get GPU memory overflow errors from Colab.
If this occurs, just restart the runtime, re-run all the pre-amble code, then just run the parameter value you're interested in.
