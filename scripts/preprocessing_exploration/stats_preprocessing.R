# Run repeated measures ANOVAs on the preprocessing exploration analyses

library(psych)
library(ggplot2)
library(car)
library(reshape)
library(lsr)
library(plyr)
library(bear)
library(biotools)
library(ez)
library(lme4)
library(lmerTest)

data_type = 'runwise' # 'sessionwise'
conditions = c(
'MotionConfounds_fslmotion_thr0.5_MotionConfounds_fslmotion_thr1_MotionConfounds_fslmotion_thr3_MotionConfounds_fslmotion_thr6_MotionConfounds_fslmotion_thr12',
'default_Motion_recovery_1_Motion_recovery_2',
'smoothing_0_smoothing_3_smoothing_5_smoothing_8',
'MELODIC_thresh_0.25_fslmotion_thr3_MELODIC_thresh_0.5_fslmotion_thr3_MELODIC_thresh_1.00_fslmotion_thr3',
'Despiking_None_default',
'Temporal_derivative_default')
ROIs = c('V1', 'LOC', 'A1')
reflevel = c(3, 1, 3, 3, 2, 2)


ANOVA_preprocessing = function(data_type, condition, ROI){
  # Load the data
  data = read.csv(sprintf('~/cohort_1_%s_%s_%s_comparison.txt', data_type, condition, ROI))
  
  # Remove the ppt age column
  data = subset(data, select = -c(Ppt_age))
  
  # Get the ppt id
  data$ppt_id = factor(seq(1, nrow(data)))
  
  # Melt data
  dat.long = melt(data, id.vars = c('ppt_id'))
  
  # Converting to factor
  dat.long$ppt_id = factor(dat.long$ppt_id)
  
  # If any of these values are nans, do a between subjects ANOVA (one-way), else do a repeated measures
  if(sum(is.nan(dat.long$value)) > 0){
    
    # Remove NaNs
    dat.long = na.omit(dat.long)
    
    # Add a unique ppt identifier
    dat.long$ppt_id_unique = factor(seq(1, nrow(dat.long)))
    
    # Run the one way anova
    print('One-way anova')
    print(ezANOVA(data=dat.long, dv=value, wid=ppt_id_unique, between=variable, type =2))
    
    # Remove all participant rows with nans
    data = na.omit(data)
    
    # Melt data again
    dat.long = melt(data, id.vars = c('ppt_id'))
    
    # Converting to factor
    dat.long$ppt_id = factor(dat.long$ppt_id)
    
    # Run the repeated-measures anova
    print('Repeated-measures anova')
    print(ezANOVA(data=dat.long, dv=value, wid=ppt_id, within=variable, type =2))
    
  } else {
    # Run the anova
    print('Repeated-measures anova')
    print(ezANOVA(data=dat.long, dv=value, wid=ppt_id, within=variable, type =2))
    
  }
  
}

lm_preprocessing = function(data_type, condition, ROI){
  # Load the data
  data = read.csv(sprintf('~/cohort_1_%s_%s_%s_comparison.txt', data_type, condition, ROI))
  
  # Remove the ppt age column
  data = subset(data, select = -c(Ppt_age))
  
  # Get the ppt id
  data$ppt_id = factor(seq(1, nrow(data)))
  
  # Melt data
  dat.long = melt(data, id.vars = c('ppt_id'))
  
  # Converting to factor
  dat.long$ppt_id = factor(dat.long$ppt_id)
  
  # Run the linear fixed effects model, treating ppt_id as a random effect
  model = lm(value ~ variable, data=dat.long)
  model_summary = summary(model)
  
  # Get the F statistics from the model
  f = model_summary$fstatistic
  p_value = pf(f[1],f[2],f[3],lower.tail=FALSE)
  attributes(p_value) <- NULL
  
  # Print the F test
  print(sprintf('F(%d,%d)=%0.3f, p = %0.3f', f[2], f[3], f[1], p_value))
  
  
}

lmer_preprocessing = function(data_type, condition, ROI, reflevel=NULL){
  # Load the data
  data = read.csv(sprintf('cohort_1_%s_%s_%s_comparison.txt', data_type, condition, ROI))
  
  # Remove the ppt age column
  data = subset(data, select = -c(Ppt_age))
  
  # Get the ppt id
  data$ppt_id = factor(seq(1, nrow(data)))
  
  # Melt data
  dat.long = melt(data, id.vars = c('ppt_id'))
  
  # Converting to factor
  dat.long$ppt_id = factor(dat.long$ppt_id)
  
  # Change the reference factor to be what you want
  if(is.null(reflevel) == FALSE){
    dat.long = within(dat.long, variable <- relevel(variable, ref = reflevel))
  }
  
  lmm = lmer(value ~ variable + (1|ppt_id), data = dat.long, REML=FALSE)
  print(Anova(lmm))
  print(coef(summary(lmm)))
  
  # # It seems the data is mostly non-normal (but is log normal) hence the following could be used to fix it
  # # Add a small number because the software doesn't like 0s
  # dat.long$value =  dat.long$value + 1e-7
  # PQL = glmmPQL(value ~ variable, ~1 | ppt_id, family = gaussian(link = "log"), data = dat.long, verbose = F)
  # print(Anova(PQL))
  # print(summary(PQL)$tTable)
}

# Loop through the conditions and ROIs
for(ROI in ROIs){
  for(counter in seq(NROW(conditions))){
    print(sprintf('%s %s', conditions[counter], ROI))
    lmer_preprocessing(data_type, conditions[counter], ROI, reflevel[counter])
  }
}

