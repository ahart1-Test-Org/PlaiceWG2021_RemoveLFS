# ---
# title: "WHAM_Run50_addEnvCov-R-anomBT-noEffect-ar1"
# output: html_document
# date: '2022-05-16'
# ---

## Model description
#Model specified as in run 29B but is fit with an environmental covariate that has no effect so it can be directly compared to run 44A that incorporates this environmental effect on catchability. Annual bottom temperature anomaly was the environmental covariate considered here.


### Environmental covariate description
#Annual bottom temperature anomalies were calculated by Jamie Behan using the GLORYS reanalysis product. A base period of 1981-2010 was used to calculate the temperature anomalies


### Load R packages
library(tidyverse)
library(wham)
library(readxl)
library(DataExplorer)

### Load data
# ASAP data input
asap3 <- read_asap3_dat(paste(here::here(), "data", "PlaiceWHAM-2019_revised_NEFSC-LW-WAA_splitNEFSC-BigUnit.DAT", sep="/"))

# Load environmental data 
BT <- read.csv(paste(here::here(), "data", "GLORYS_se.csv", sep="/"))
BT <- BT %>% filter(Year>1979)

### Prepare model input
NAA_re = list(sigma = "rec+1") # Full state-space model
NAA_re$cor = "iid" # iid random effects
NAA_re$recruit_model = 2 # recruitment is random about the mean
NAA_re$recruit_pars = exp(10) #initial guess for mean recruitment

# Setup environmental covariate and options
  ecov <- list(
    label = "BT_GLORYS",
    mean = as.matrix(BT$anomaly_bt),
    logsigma = as.matrix(log(BT$se_anomaly)),
    year = as.numeric(BT$Year),
    use_obs = matrix(c(rep(TRUE, nrow(BT))), ncol = 1, nrow=nrow(BT)), # use all obs except the first 2 (no data 1979 and 1980, not full year of data in 1981) 
    lag = 1, # SST anomaly in year t impact R in year t+1
    process_model = "ar1",
    where = "none", 
    how = 0 
  )

# Setup initial selectivity model and parameters
use_n_indices = 4
modelsetup <- c(rep("logistic", asap3$dat$n_fleet_sel_blocks), rep("age-specific", use_n_indices))

init_fleet_sel <- list(c(2,0.4)) # logistic parameters, based on model type
#init_index_sel <- lapply(1:use_n_indices, function(x) c(0.5, 0.5, 0.5, 1, 1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5))
init_index_sel <- lapply(1:use_n_indices, function(x) c(0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5))

# Setup fixed parameters
fix_fleet_sel <- lapply(1:asap3$dat$n_fleets, function(x) NA) 
fix_index_sel <- lapply(1:use_n_indices, function(x) NA) # Set up index object

fix_index_sel[[1]] <- c(4,5) # Fix age 4 & 5 for for index 1 (NEFSC spring Albatross)
init_index_sel[[1]][4:5] = 1
fix_index_sel[[2]][1] <- 5 # Fix age  5 for for index 2 (NEFSC spring Bigelow)
init_index_sel[[2]][5] = 1
fix_index_sel[[3]][1] <- 4 # Fix age 4 for for index 3 (NEFSC fall Albatross)
init_index_sel[[3]][4] = 1
fix_index_sel[[4]] <- c(4,5) # Fix age 4 for for index 4 (NEFSC fall Bigelow)
init_index_sel[[4]][4:5] = 1

# Setup random effect by selectivity block (here: fleet, index1, index2)
#randeffect <- c(rep("iid", asap3$dat$n_fleet_sel_blocks), rep("iid", use_n_indices))

# Setup random effect by selectivity block (here: fleet, index1, index2, index3, index4)
randeffect <- c(rep("iid", asap3$dat$n_fleet_sel_blocks), rep("none", 4)) # Don't include selectivity random effects for any surveys 

# Setup selectivity list
sel_list <- list(model = modelsetup, # list selectivity model for each fleet and index
                 re = randeffect,
                 initial_pars = c(init_fleet_sel, init_index_sel),
                 fix_pars = c(fix_fleet_sel, fix_index_sel))

input <- prepare_wham_input(asap3, NAA_re = NAA_re, selectivity = sel_list, ecov=ecov, model_name = "WHAM_Run50") 

### Save input
# Save model data input
#saveRDS(input, file=paste(here::here(), "WG_Revised_Runs", "WHAM_Run50_addEnvCov-R-anomBT-noEffect-ar1", "WHAM_Run50_input.rds", sep="/"))

### Fit model, check convergence, and run diagnostics
temp <- fit_wham(input, do.osa = FALSE, do.retro = FALSE) 

x = TMB::oneStepPredict(temp, method = "cdf", subset=1:40, 
  observation.name = "obsvec", data.term.indicator = "keep", discrete = FALSE)
y = TMB::oneStepPredict(temp, subset=1:40, method = "oneStepGeneric",
  observation.name = "obsvec", data.term.indicator = "keep", discrete = FALSE)
z = TMB::oneStepPredict(temp, subset=1:40, method = "oneStepGaussianOffMode",
  observation.name = "obsvec", data.term.indicator = "keep", discrete = FALSE)
cbind(x$res, y$res, z$res)
x = TMB::oneStepPredict(temp, method = "cdf", conditional=41:1480, 
  observation.name = "obsvec", data.term.indicator = "keep", discrete = FALSE)

WHAM_Run50 <- fit_wham(input, do.osa = TRUE, do.retro = TRUE) 
check_convergence(WHAM_Run50)
print(paste("Number of parameters", length(WHAM_Run50$par), sep=" "))

plot_wham_output(mod=WHAM_Run50, out.type='html')
# plot_wham_output(mod=WHAM_Run50, out.type='png', dir.main = paste(here::here(), "WHAM_Run50", sep="/"))
```

### Save output
```{r}
# Save fitted model
saveRDS(WHAM_Run50, file=paste(here::here(), "WG_Revised_Runs", "WHAM_Run50_addEnvCov-R-anomBT-noEffect-ar1", "WHAM_Run50_model.rds", sep="/"))
```

### Rerun model using saved input data
Load data from saved input RData and rerun model
```{r}
inputRerun <- readRDS(paste(here::here(), "WG_Revised_Runs",
                     "WHAM_Run50_addEnvCov-R-anomBT-noEffect-ar1/WHAM_Run50_input.rds", sep="/"))

# Rerun data
ReRun50 <- fit_wham(input = inputRerun, MakeADFun.silent = TRUE)
```

## Comment
AIC was smaller for run 50A (see notes in that run's Script for more specifics) but was within +/-2 of the AIC value for run 50 so these runs should be considered equivalent. Mohn's rho values were smaller in run 50A for SSB and F but larger for R. Run 50 is the preferred run because the AIC scores are equivalent, Mohn's rho values are generally lower and run 50 fits to less data.
