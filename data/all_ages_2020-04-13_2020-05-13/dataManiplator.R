library(dplyr)
library(readr)


results<- read_csv("vb_rec_exp_results.csv")
head(results)


results %>% group_by(platform, exp_group, age_range) %>%
  select(platform,exp_group, age_range,bbc_hid3) %>%
  distinct()%>%
  mutate(num_hids = n()) %>%
  select(-bbc_hid3)

