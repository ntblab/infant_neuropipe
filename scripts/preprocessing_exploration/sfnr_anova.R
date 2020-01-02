# Run the repeated measures ANOVA comparing the anterior and posterior halves of the participant brains in SFNR
library(psych)
library(ggplot2)
library(car)
library(reshape)
library(lsr)
library(plyr)
library(bear)
library(biotools)
library(ez)

adult = read.csv('~/Desktop/SFNR_adult_back_vs_front_3_median.txt')
infant = read.csv('~/Desktop/SFNR_infant_back_vs_front_3_median.txt')

# Add a column to define the groups
infant$group='infant'
adult$group='adult'

# Add a column to label each participant
infant$ppt_id = seq(nrow(infant))
adult$ppt_id = seq(nrow(adult))

dat = rbind(infant, adult)

# Melt and concatenate the data frames
dat.long = rbind(melt(infant, id.vars = c('group','ppt_id')), melt(adult, id.vars = c('group','ppt_id')))

# Run the anova
ezANOVA(data=dat.long, dv=value, wid=ppt_id, within=variable, between = group, type =2) 

ggplot(dat.long) + aes(x=variable, y=value, group=group, color=group) + geom_line(size=2, aes(color=group))
ggplot(dat.long) + aes(x=variable, y=value) + geom_boxplot() + facet_wrap(~group)


# Calculate the change as a ratio
infant_ratio = infant$Front / infant$Back
infant_ratio_dat = data.frame("data"=infant_ratio, "group"='infant')

adult_ratio = adult$Front / adult$Back
adult_ratio_dat = data.frame("data"=adult_ratio, "group"='adult')

# Combine
dat_ratio = rbind(infant_ratio_dat, adult_ratio_dat)

ggplot(dat_ratio) + aes(x=group, y=data) + geom_boxplot() 

# Do the stats
t.test(infant_ratio, adult_ratio)

