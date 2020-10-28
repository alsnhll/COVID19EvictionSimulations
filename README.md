# COVID19EvictionSimulations
Repository for model to simulate the impact of evictions on the spread of SARS-CoV-2

Joint work with:
* University of Pennsylvania: [Justin Sheen](https://github.com/jsheen), [Mike Levy](https://www.dbei.med.upenn.edu/bio/michael-z-levy-phd), [Julianna Shinnick](https://www.linkedin.com/in/julianna-shinnick-60a8a3134/), [Maria Florencia Tejeda](https://www.linkedin.com/in/maria-florencia-tejeda-808796192/)
* Johns Hopkins University: [Alison Hill](https://alsnhll.github.io/)
* Harvard University: [Anjalika Nande](https://github.com/anjalika-nande), [Ben Adlam](https://research.google/people/BenAdlam/), [Andrei Gheorghe](https://www.linkedin.com/in/andrei-gheorghe-b7499066/)
* University of Illinois Urbana-Champagne: [Andrew Greenlee](https://urban.illinois.edu/people/profiles/andrew-greenlee/), [Daniel Schneider](https://urban.illinois.edu/people/profiles/daniel-schneider/), [Emma Walters](https://www.linkedin.com/in/emmawalters/) 

Contact : Alison Hill <alhill@fas.harvard.edu> and Mike Levy <mzlevy@upenn.edu>

Paper: [The effect of eviction moratoriums on the transmission of SARS-CoV-2](The effect of eviction moratoriums on the transmission of SARS-CoV-2.pdf)

## Project Summary
Massive unemployment during the COVID-19 pandemic could result in an eviction crisis in US cities. Here we model the effect of evictions on SARS-CoV-2 epidemics, simulating viral transmission within and among households in a theoretical metropolitan area. We recreate a range of urban epidemic trajectories and project the course of the epidemic under two counterfactual scenarios, one in which a strict moratorium on evictions is in place and enforced, and another in which evictions are allowed to resume at baseline or increased rates. We find, across scenarios, that evictions lead to significant increase in infections. Applying our model to Philadelphia using locally-specific parameters shows that the increase is especially profound in models that consider realistically heterogenous cities in which both evictions and contacts occur more frequently in poorer neighborhoods. Our results provide a basis to assess municipal eviction moratoriums and show that policies to stem evictions are a warranted and important component of COVID-19 control. 

## Repository Contents

This repository contains the Python code to run the stochastic network simulations used to generate all the results in the paper. All the code is written in the form of Jupyter notebooks to be run on Google Colab. 

The code is divided into a few different notebooks, with similar pre-ambles but then slightly different scenarios simulated. The file paths (used to save output) should work if you create a directory in your Google Drive called "COVID19 Eviction Modeling". The code imports a module (.py file with multiple functions defined) that we keep on Github in a public repository (['alsnhll/COVID19NetworkSimulations'](https://github.com/alsnhll/COVID19NetworkSimulations)) - you can access it by entering your own Github account when Colab prompts you to. The code is optimized to run on a GPU, which you can select from the main menu using Runtime > Change Runtime type. It works best on a Colab Pro account. 

### Files

* code/eviction_doubling_homogeneous.ipynb : This iPython notebook was used to simulate the effects of evictions in a homogeneous population, corresponding to figure 2 and 3 in the main text.
* code/eviction_doubling_2clusters.ipynb : This iPython notebook contains the simulations that involved a heterogeneous population, divided into 2 clusters (high and low socio-economic status). This corresponds to figure 4 in the main text.
*  code/eviction_doubling_3clusters.ipynb : Simulations involving our case study of Philadelphia are in this iPython notebook. This corresponds to figure 5 in the main text.
*  code/eviction_doubling_shelters_homogeneous.ipynb : This iPython notebook was used to simulate the effect of homelessness in addition to doubling of households due to evictions and was used to generate figure S12 in the supplement. 
*  code/plotting_examples.ipynb : We provide example code that was used to generate all the figures in the main text.


## Related

Based on some of our preliminary findings, Mike Levy [filed an affidavit](https://github.com/mzlevy/Philly_Covid/blob/master/28-6_Levy_Declaration.pdf) on Aug 7 with the US District Court in Philadelphia, in regards to a case that an association of property owners, managers, and investers had filed against the City of Philadelphia to prevent them from continuing to enforce anti-eviction polices under their [Emergency Housing Protection Act](https://phila.legistar.com/LegislationDetail.aspx?ID=4432723&GUID=52A61514-7062-4734-8006-C58AC90B5E25&Options=ID%7CText%7C&Search=200295). On Aug 28, the court ruled in favor of the city, and this mathematical modeling work was cited as evidence that policies enacted by the city and state to prevent evictions were indeed related to reducing the spread of COVID-19. The judge's opinion statement, which cites the evidence from models, is [here](https://github.com/mzlevy/Philly_Covid/blob/master/HAPCO%20vs%20Philly%20decision.pdf).

On Sept 4 2020, the CDC imposed a [national moratorium](https://www.federalregister.gov/documents/2020/09/04/2020-19654/temporary-halt-in-residential-evictions-to-prevent-the-further-spread-of-covid-19#:~:text=The%20Centers%20for%20Disease%20Control%20and%20Prevention%20(CDC)%2C%20located,further%20spread%20of%20COVID%2D19) on evictions until December 31st, 2020. It is currently being challenged in federal court ([Brown vs Azar](https://dockets.justia.com/docket/georgia/gandce/1:2020cv03702/280996)). Some of our preliminary results were included as part of an amici curiae brief submitted by a consortium of public health and legal groups in relation to the case, which is available [here](https://papers.ssrn.com/abstract=3708504).

We have another paper examining the effect of transmission network structure on COVID-19 spread: [Dynamics of COVID-19 under social distancing measures are driven by transmission network structure](https://www.medrxiv.org/content/10.1101/2020.06.04.20121673v1)
