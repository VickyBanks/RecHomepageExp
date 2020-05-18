### Proxy connection to CRAN ###

proxy_url <- "http://www-cache-bol.reith.bbc.co.uk:80"
Sys.setenv(http_proxy = proxy_url, https_proxy = proxy_url, ftp_proxy = proxy_url)

### Loading packages needed ###
# install.packages('devtools')
# install.packages("ggstatsplot")
# install.packages("robust")
# install.packages("ggplot2")
# install.packages("ggjoy")
# install.packages("ggpubr")
# install.packages("readxl")
library(ggstatsplot)
library(robust)
library(ggplot2)
library(ggjoy)
library(ggpubr)
library(readxl)
library(devtools)
library(readr)
library(scales)
devtools::install_github("r-lib/rlang", build_vignettes = TRUE)

### Read in your files ###
Control <- read_csv('control.csv', col_names = c('Visitor_ID', 'Metric1', 'Metric2'))
#Variant <- read_excel('variant.xlsx', col_names = c('Visitor_ID', 'Metric1', 'Metric2'))
Variant <- read_csv('variation_1.csv', col_names = c('Visitor_ID', 'Metric1', 'Metric2'))
Variant1 <- read_csv('variation_2.csv', col_names = c('Visitor_ID', 'Metric1', 'Metric2'))

### Execute the following code to create the remove_outliers function ###
### This function will remove outliers greater than than 3 standard deviations away from the mean ###

remove_outliers <- function (x) {
   y <- x[x > 0]
   outliers <- 3*sd(y) + mean(y)
   filtered <- x[x < outliers]
   valsremaining <- length(filtered)/length(x)
   if (valsremaining < 0.95){
      stop ("This function will remove more than 5% percent of your data. You need to remove outliers manually.")}
   
   else if (length(filtered)/length(x) < 0.99){
      warning("This calculation has removed between 1% and 5% of your data.") 
      filtered
   }
   else
   {filtered}
}

### Joins data to create experiment dataframe ###

#Variant2$Variant <- paste("Variant2")
Variant1$Variant <- paste("Variant1")
Variant$Variant <- paste("Variant")
Control$Variant <- paste("Control")
Experiment <- rbind(Control, Variant, Variant1)#, Variant2)
Experiment <- as.data.frame(Experiment)
head(Experiment)

## Performs remove_outliers function on new experiment dataframe ###

remove_outliers(Experiment$Metric1)

### The following code reads in your data and uses the ggbetweenstats function to calculate your statistic and present your plot ###
###### Metric 1 - num starts ######
ggbetween_plot_metric1 <- Experiment %>%
   ggstatsplot::ggbetweenstats(
   x = Variant,
   y = Metric1, ### CHANGE THIS TO THE METRIC OF INTEREST! ###
   mean.label.size = 2.5,
   type = "parametric",
   k = 3,
   pairwise.comparisons = TRUE,
   pairwise.annotation = "p.value",
   p.adjust.method = "bonferroni",
   title = "AB/N Test",
   messages = TRUE)

pb_metric1 <- ggplot_build(ggbetween_plot_metric1)
results_metric1<-pb_metric1$plot$plot_env$df_pairwise
View(results_metric1)
ggbetween_plot_metric1


###### Metric 2 - num watched ######
ggbetween_plot_metric2 <- Experiment %>%
   ggstatsplot::ggbetweenstats(
      x = Variant,
      y = Metric2, ### CHANGE THIS TO THE METRIC OF INTEREST! ###
      mean.label.size = 2.5,
      type = "parametric",
      k = 3,
      pairwise.comparisons = TRUE,
      pairwise.annotation = "p.value",
      p.adjust.method = "bonferroni",
      title = "AB/N Test",
      messages = TRUE)

pb_metric2 <- ggplot_build(ggbetween_plot_metric2)
results_metric2<-pb_metric2$plot$plot_env$df_pairwise
View(results_metric2)
ggbetween_plot_metric2


### The following code runs an Fz distribution of your cleaned data ###

ggplot(Experiment, aes(x = Metric1, y = Variant, fill = Variant)) + 
   geom_joy() + 
   xlab("Metric1")+
   ylab("Variant")+
   ggtitle("AB/N Test")+
   theme_classic()


### This section of the script calculators individual uplifts between variants ###
uplift_calculator <- function(Control_Metric, Variant_Metric){
   uplift <- (Variant_Metric/Control_Metric)-1
   uplift <- percent(uplift)
   if (uplift > 0){
      sprintf("The variant beat the control by %s", uplift, Control_Metric, Variant_Metric)
   }else{sprintf("The variant performed worse than the control by %s", uplift, Control_Metric, Variant_Metric)}
}

### Here are the means of all your varaiants ###
Control_Metric <- mean(Control$Metric1)
Variant_Metric <- mean(Variant$Metric1)
Variant1_Metric <- mean(Variant1$Metric1)
Variant2_Metric <- mean(Variant2$Metric1)
### Fill in this function with your mean values ###
uplift_calculator(Control_Metric, Variant_Metric)
uplift_calculator(Control_Metric, Variant1_Metric)
uplift_calculator(Variant_Metric, Variant1_Metric)
