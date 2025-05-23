library(tidyverse)
library(sf)
library(readxl)
library(zoo)
library(lubridate)


# Download the latest full files from Fayetteville police open data
# For crimes against people
download.file("https://opendata.arcgis.com/api/v3/datasets/f52ad2a08f5c405d8b1d0f333c34824e_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "data/source/fayetteville_crime_people.csv")
# Then for crimes against property
download.file("https://opendata.arcgis.com/api/v3/datasets/74f34da7e6f1404f868fd9e22bf9f09c_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "data/source/fayetteville_crime_property.csv")

# Read in the files we just downloaded
fay_property <- read_csv("data/source/fayetteville_crime_property.csv") %>% janitor::clean_names()
fay_people <- read_csv("data/source/fayetteville_crime_people.csv") %>% janitor::clean_names()

# Read in the SEPARATELY processed recent incidents file gathered in get_fayetteville_recent.R
fay_recent <- readRDS("scripts/rds/fayetteville_new.rds")

# Merge into a single primary fay_crime file
fay_crime <- rbind(fay_property,fay_people)

# Rebuild data into fields consistent with the recent incidents stream we're adding next
fay_crime$date <- ymd(substr(fay_crime$date_incident,1,10))
fay_crime$hour <- substr(fay_crime$fay_pd_tod,1,2)
fay_crime$year <- year(fay_crime$date)
fay_crime$month <- lubridate::floor_date(as.Date(fay_crime$date),"month")

# Drop premise, apt, date_incident and date_secure from dataframe
fay_crime$date_incident <- NULL
fay_crime$date_secure <- NULL
fay_crime$reportarea <- NULL
fay_crime$x <- NULL
fay_crime$y <- NULL

# Merge in the recent file
fay_crime <- rbind(fay_crime,fay_recent)
# There will be some duplicate records in the recent file already in the full files
# We're deleting those duplicates
fay_crime <- distinct(fay_crime)

# Recoding and defining standard categories for tracker; we're leaving out sexual assault because
# extremely redacted in the Fayetteville PD data, so any stats are an inaccurate representation
fay_crime$category <- case_when(fay_crime$ucr_code=="09A" ~ "Murder",
                                    fay_crime$ucr_code=="13A" ~ "Aggravated Assault",
                                    fay_crime$ucr_code=="120" ~ "Robbery",
                                    fay_crime$ucr_code=="220" ~ "Burglary",
                                    fay_crime$ucr_code %in% 
                                      c("23A","23B","23C","23D","23E","23F","23G","23H") ~ "Theft",
                                    fay_crime$ucr_code=="240" ~ "Motor Vehicle Theft",
                                    TRUE ~ "Other/Unknown")

fay_crime$type <- case_when(fay_crime$ucr_code=="09A" ~ "Violent",
                   fay_crime$ucr_code=="13A" ~ "Violent",
                   fay_crime$ucr_code=="120" ~ "Violent",
                   fay_crime$ucr_code=="220" ~ "Property",
                   fay_crime$ucr_code %in% 
                     c("23A","23B","23C","23D","23E","23F","23G","23H") ~ "Property",
                   fay_crime$ucr_code=="240" ~ "Property",
                   TRUE ~ "Other/Unknown")

# Rename some key columns for merging with geography and
# consistency with the code that processes the analysis of latest data/change
fay_crime <- fay_crime %>% rename("description"="offense_description")
fay_crime <- fay_crime %>% rename("district_name"="district")
fay_crime <- fay_crime %>% rename("district"="zone")
fay_crime$district[is.na(fay_crime$district)] <- "Unknown"

# Slide off a separate table of crimes from the last full 12 months
fay_crime_last12 <- fay_crime %>% filter(fay_crime$date > max(fay_crime$date)-365)

### CITYWIDE CRIME 
### TOTALS AND OUTPUT

# Set variable of city population; needs to be updated annually
fay_population <- 208778

# Calculate each detailed offense type CITYWIDE
citywide_detailed <- fay_crime %>%
  group_by(category,description,year) %>%
  summarise(count = n()) %>%
  arrange(year) %>%
  pivot_wider(names_from=year, values_from=count)
# rename the year columns
citywide_detailed <- citywide_detailed %>% 
  rename("total10" = "2010",
         "total11" = "2011",
         "total12" = "2012",
         "total13" = "2013",
         "total14" = "2014",
         "total15" = "2015",
         "total16" = "2016",
         "total17" = "2017",
         "total18" = "2018",
         "total19" = "2019",
         "total20" = "2020",
         "total21" = "2021",
         "total22" = "2022",
         "total23" = "2023")
# add last 12 months
citywide_detailed_last12 <- fay_crime_last12 %>%
  group_by(category,description) %>%
  summarise(last12mos = n())
citywide_detailed <- left_join(citywide_detailed,citywide_detailed_last12,by=c("category","description"))
# add zeros where there were no crimes tallied that year
citywide_detailed[is.na(citywide_detailed)] <- 0
rm(citywide_detailed_last12)
# Calculate a total across the 3 prior years
citywide_detailed$total_prior3years <- citywide_detailed$total20+citywide_detailed$total21+citywide_detailed$total22
citywide_detailed$avg_prior3years <- round(citywide_detailed$total_prior3years/3,1)
# calculate increases
citywide_detailed$inc_19to22 <- round(citywide_detailed$total22/citywide_detailed$total19*100-100,1)
citywide_detailed$inc_19tolast12 <- round(citywide_detailed$last12mos/citywide_detailed$total19*100-100,1)
citywide_detailed$inc_22tolast12 <- round(citywide_detailed$last12mos/citywide_detailed$total22*100-100,1)
citywide_detailed$inc_prior3yearavgtolast12 <- round((citywide_detailed$last12mos/citywide_detailed$avg_prior3years)*100-100,0)
# calculate the citywide rates
citywide_detailed$rate19 <- round(citywide_detailed$total19/fay_population*100000,1)
citywide_detailed$rate20 <- round(citywide_detailed$total20/fay_population*100000,1)
citywide_detailed$rate21 <- round(citywide_detailed$total21/fay_population*100000,1)
citywide_detailed$rate22 <- round(citywide_detailed$total22/fay_population*100000,1)
citywide_detailed$rate_last12 <- round(citywide_detailed$last12mos/fay_population*100000,1)
# calculate a multiyear rate
citywide_detailed$rate_prior3years <- round(citywide_detailed$avg_prior3years/fay_population*100000,1)
# for map/table making purposes, changing Inf and NaN in calc fields to NA
citywide_detailed <- citywide_detailed %>%
  mutate_if(is.numeric, ~ifelse(. == Inf, NA, .))
citywide_detailed <- citywide_detailed %>%
  mutate_if(is.numeric, ~ifelse(. == "NaN", NA, .))

# Calculate of each detailed offense type CITYWIDE
citywide_detailed_monthly <- fay_crime %>%
  group_by(category,description,month) %>%
  summarise(count = n())
# add rolling average of 3 months for chart trend line & round to clean
citywide_detailed_monthly <- citywide_detailed_monthly %>%
  dplyr::mutate(rollavg_3month = rollsum(count, k = 3, fill = NA, align = "right")/3)
citywide_detailed_monthly$rollavg_3month <- round(citywide_detailed_monthly$rollavg_3month,0)
# write to save for charts for detailed monthly
write_csv(citywide_detailed_monthly,"data/output/monthly/citywide_detailed_monthly.csv")

# Calculate of each category of offense CITYWIDE
citywide_category <- fay_crime %>%
  group_by(category,year) %>%
  summarise(count = n()) %>%
  arrange(year) %>%
  pivot_wider(names_from=year, values_from=count)
# rename the year columns
citywide_category <- citywide_category %>% 
  rename("total10" = "2010",
         "total11" = "2011",
         "total12" = "2012",
         "total13" = "2013",
         "total14" = "2014",
         "total15" = "2015",
         "total16" = "2016",
         "total17" = "2017",
         "total18" = "2018",
         "total19" = "2019",
         "total20" = "2020",
         "total21" = "2021",
         "total22" = "2022",
         "total23" = "2023")
# add last 12 months
citywide_category_last12 <- fay_crime_last12 %>%
  group_by(category) %>%
  summarise(last12mos = n())
citywide_category <- left_join(citywide_category,citywide_category_last12,by=c("category"))
# add zeros where there were no crimes tallied that year
citywide_category[is.na(citywide_category)] <- 0
# Calculate a total across the 3 prior years
citywide_category$total_prior3years <- citywide_category$total20+citywide_category$total21+citywide_category$total22
citywide_category$avg_prior3years <- round(citywide_category$total_prior3years/3,1)
# calculate increases
citywide_category$inc_19to22 <- round(citywide_category$total22/citywide_category$total19*100-100,1)
citywide_category$inc_19tolast12 <- round(citywide_category$last12mos/citywide_category$total19*100-100,1)
citywide_category$inc_22tolast12 <- round(citywide_category$last12mos/citywide_category$total22*100-100,1)
citywide_category$inc_prior3yearavgtolast12 <- round((citywide_category$last12mos/citywide_category$avg_prior3years)*100-100,0)
# calculate the citywide rates
citywide_category$rate19 <- round(citywide_category$total19/fay_population*100000,1)
citywide_category$rate20 <- round(citywide_category$total20/fay_population*100000,1)
citywide_category$rate21 <- round(citywide_category$total21/fay_population*100000,1)
citywide_category$rate22 <- round(citywide_category$total22/fay_population*100000,1)
citywide_category$rate_last12 <- round(citywide_category$last12mos/fay_population*100000,1)
# calculate a multiyear rate
citywide_category$rate_prior3years <- round(citywide_category$avg_prior3years/fay_population*100000,1)

# Calculate monthly totals for categories of crimes CITYWIDE
citywide_category_monthly <- fay_crime %>%
  group_by(category,month) %>%
  summarise(count = n())
# add rolling average of 3 months for chart trend line & round to clean
citywide_category_monthly <- citywide_category_monthly %>%
  arrange(category,month) %>%
  dplyr::mutate(rollavg_3month = rollsum(count, k = 3, fill = NA, align = "right")/3)
citywide_category_monthly$rollavg_3month <- round(citywide_category_monthly$rollavg_3month,0)

# write series of monthly files for charts (NOTE murder is written above in detailed section)
write_csv(citywide_category_monthly,"data/output/monthly/citywide_category_monthly.csv")
citywide_category_monthly %>% filter(category=="Sexual Assault") %>% write_csv("data/output/monthly/sexassaults_monthly.csv")
citywide_category_monthly %>% filter(category=="Motor Vehicle Theft") %>% write_csv("data/output/monthly/autothefts_monthly.csv")
citywide_category_monthly %>% filter(category=="Theft") %>% write_csv("data/output/monthly/thefts_monthly.csv")
citywide_category_monthly %>% filter(category=="Burglary") %>% write_csv("data/output/monthly/burglaries_monthly.csv")
citywide_category_monthly %>% filter(category=="Robbery") %>% write_csv("data/output/monthly/robberies_monthly.csv")
citywide_category_monthly %>% filter(category=="Aggravated Assault") %>% write_csv("data/output/monthly/assaults_monthly.csv")
citywide_category_monthly %>% filter(category=="Murder") %>% write_csv("data/output/monthly/murders_monthly.csv")


### Some YEARLY tables for charts for our pages
citywide_category %>% select(1:14,16) %>% rename_with(~ gsub("total", "20", .x)) %>% filter(category=="Murder") %>% write_csv("data/output/yearly/murders_city.csv")
citywide_category %>% select(1:14,16) %>% rename_with(~ gsub("total", "20", .x)) %>% filter(category=="Sexual Assault") %>%  write_csv("data/output/yearly/sexassaults_city.csv")
citywide_category %>% select(1:14,16) %>% rename_with(~ gsub("total", "20", .x)) %>% filter(category=="Motor Vehicle Theft") %>%  write_csv("data/output/yearly/autothefts_city.csv")
citywide_category %>% select(1:14,16) %>% rename_with(~ gsub("total", "20", .x)) %>% filter(category=="Theft") %>%  write_csv("data/output/yearly/thefts_city.csv")
citywide_category %>% select(1:14,16) %>% rename_with(~ gsub("total", "20", .x)) %>% filter(category=="Burglary") %>%  write_csv("data/output/yearly/burglaries_city.csv")
citywide_category %>% select(1:14,16) %>% rename_with(~ gsub("total", "20", .x)) %>% filter(category=="Robbery") %>%  write_csv("data/output/yearly/robberies_city.csv")
citywide_category %>% select(1:14,16) %>% rename_with(~ gsub("total", "20", .x)) %>% filter(category=="Aggravated Assault") %>%  write_csv("data/output/yearly/assaults_city.csv")

# Calculate of each type of crime CITYWIDE
citywide_type <- fay_crime %>%
  group_by(type,year) %>%
  summarise(count = n()) %>%
  arrange(year) %>%
  pivot_wider(names_from=year, values_from=count)
# rename the year columns
citywide_type <- citywide_type %>% 
  rename("total10" = "2010",
         "total11" = "2011",
         "total12" = "2012",
         "total13" = "2013",
         "total14" = "2014",
         "total15" = "2015",
         "total16" = "2016",
         "total17" = "2017",
         "total18" = "2018",
         "total19" = "2019",
         "total20" = "2020",
         "total21" = "2021",
         "total22" = "2022",
         "total23" = "2023")
# add last 12 months
citywide_type_last12 <- fay_crime_last12 %>%
  group_by(type) %>%
  summarise(last12mos = n())
citywide_type <- left_join(citywide_type,citywide_type_last12,by=c("type"))
# Calculate a total across the 3 prior years
citywide_type$total_prior3years <- citywide_type$total20+citywide_type$total21+citywide_type$total22
citywide_type$avg_prior3years <- round(citywide_type$total_prior3years/3,1)
# add zeros where there were no crimes tallied that year
citywide_type[is.na(citywide_type)] <- 0
# calculate increases
citywide_type$inc_19to22 <- round(citywide_type$total22/citywide_type$total19*100-100,1)
citywide_type$inc_19tolast12 <- round(citywide_type$last12mos/citywide_type$total19*100-100,1)
citywide_type$inc_22tolast12 <- round(citywide_type$last12mos/citywide_type$total22*100-100,1)
citywide_type$inc_prior3yearavgtolast12 <- round((citywide_type$last12mos/citywide_type$avg_prior3years)*100-100,0)
# calculate the citywide rates
citywide_type$rate19 <- round(citywide_type$total19/fay_population*100000,1)
citywide_type$rate20 <- round(citywide_type$total20/fay_population*100000,1)
citywide_type$rate21 <- round(citywide_type$total21/fay_population*100000,1)
citywide_type$rate22 <- round(citywide_type$total22/fay_population*100000,1)
citywide_type$rate_last12 <- round(citywide_type$last12mos/fay_population*100000,1)
# calculate a multiyear rate
citywide_type$rate_prior3years <- round(citywide_type$avg_prior3years/fay_population*100000,1)

### FAYETTEVILLE PD DISTRICT CRIME TOTALS AND OUTPUT

# MERGE WITH BEATS GEOGRAPHY AND POPULATION
# Geography and populations processed separately in 
districts <- st_read("data/output/geo/fayetteville_districts.geojson")

# we need these unique lists for making the beat tables below
# this ensures that we get crime details for beats even with zero
# incidents of certain types over the entirety of the time period
list_district_category <- crossing(district = unique(fay_crime$district), description = unique(fay_crime$description))
list_district_category <- crossing(district = unique(fay_crime$district), category = unique(fay_crime$category))
list_district_type <- crossing(district = unique(fay_crime$district), type = unique(fay_crime$type))

# Calculate total of each detailed offense type by community area
district_detailed <- fay_crime %>%
  group_by(district,category,description,year) %>%
  summarise(count = n()) %>%
  arrange(year) %>%
  pivot_wider(names_from=year, values_from=count)
# rename the year columns
district_detailed <- district_detailed %>% 
  rename("total10" = "2010",
         "total11" = "2011",
         "total12" = "2012",
         "total13" = "2013",
         "total14" = "2014",
         "total15" = "2015",
         "total16" = "2016",
         "total17" = "2017",
         "total18" = "2018",
         "total19" = "2019",
         "total20" = "2020",
         "total21" = "2021",
         "total22" = "2022",
         "total23" = "2023")
# add last 12 months
district_detailed_last12 <- fay_crime_last12 %>%
  group_by(district,category,description) %>%
  summarise(last12mos = n())
district_detailed <- left_join(district_detailed,district_detailed_last12,by=c("district","category","description"))
rm(district_detailed_last12)
# add zeros where there were no crimes tallied that year
district_detailed[is.na(district_detailed)] <- 0
# Calculate a total across the 3 prior years
district_detailed$total_prior3years <- district_detailed$total20+district_detailed$total21+district_detailed$total22
district_detailed$avg_prior3years <- round(district_detailed$total_prior3years/3,1)
# calculate increases
district_detailed$inc_19to22 <- round(district_detailed$total22/district_detailed$total19*100-100,1)
district_detailed$inc_19tolast12 <- round(district_detailed$last12mos/district_detailed$total19*100-100,1)
district_detailed$inc_22tolast12 <- round(district_detailed$last12mos/district_detailed$total22*100-100,1)
district_detailed$inc_prior3yearavgtolast12 <- round((district_detailed$last12mos/district_detailed$avg_prior3years)*100-100,0)
# add population for beats
district_detailed <- full_join(districts,district_detailed,by=c("zone"="district"))
# calculate the beat by beat rates PER 1K people
district_detailed$rate19 <- round(district_detailed$total19/district_detailed$population*100000,1)
district_detailed$rate20 <- round(district_detailed$total20/district_detailed$population*100000,1)
district_detailed$rate21 <- round(district_detailed$total21/district_detailed$population*100000,1)
district_detailed$rate22 <- round(district_detailed$total22/district_detailed$population*100000,1)
district_detailed$rate_last12 <- round(district_detailed$last12mos/district_detailed$population*100000,1)
# calculate a multiyear rate
district_detailed$rate_prior3years <- round(district_detailed$avg_prior3years/district_detailed$population*100000,1)
# for map/table making purposes, changing Inf and NaN in calc fields to NA
district_detailed <- district_detailed %>%
  mutate_if(is.numeric, ~ifelse(. == Inf, NA, .))
district_detailed <- district_detailed %>%
  mutate_if(is.numeric, ~ifelse(. == "NaN", NA, .))

# Calculate total of each category of offense BY POLICE BEAT
district_category <- fay_crime %>%
  group_by(district,category,year) %>%
  summarise(count = n()) %>%
  arrange(year) %>%
  pivot_wider(names_from=year, values_from=count)
# merging with full list so we have data for every beat, every category_name
district_category <- left_join(list_district_category,district_category,by=c("district"="district","category"="category"))
# rename the year columns
district_category <- district_category %>% 
  rename("total19" = "2019",
         "total20" = "2020",
         "total21" = "2021",
         "total22" = "2022",
         "total23" = "2023")
# add last 12 months
district_category_last12 <- fay_crime_last12 %>%
  group_by(district,category) %>%
  summarise(last12mos = n())
district_category <- left_join(district_category,district_category_last12,by=c("district","category"))
rm(district_category_last12)
# add zeros where there were no crimes tallied that year
district_category[is.na(district_category)] <- 0
# Calculate a total across the 3 prior years
district_category$total_prior3years <- district_category$total20+district_category$total21+district_category$total22
district_category$avg_prior3years <- round(district_category$total_prior3years/3,1)
# calculate increases
district_category$inc_19to22 <- round(district_category$total22/district_category$total19*100-100,1)
district_category$inc_19tolast12 <- round(district_category$last12mos/district_category$total19*100-100,1)
district_category$inc_22tolast12 <- round(district_category$last12mos/district_category$total22*100-100,1)
district_category$inc_prior3yearavgtolast12 <- round((district_category$last12mos/district_category$avg_prior3years)*100-100,0)
# add population for beats
district_category <- full_join(districts,district_category,by=c("zone"="district"))
# calculate the beat by beat rates PER 1K people
district_category$rate19 <- round(district_category$total19/district_category$population*100000,1)
district_category$rate20 <- round(district_category$total20/district_category$population*100000,1)
district_category$rate21 <- round(district_category$total21/district_category$population*100000,1)
district_category$rate22 <- round(district_category$total22/district_category$population*100000,1)
district_category$rate_last12 <- round(district_category$last12mos/district_category$population*100000,1)
# calculate a multiyear rate
district_category$rate_prior3years <- round(district_category$avg_prior3years/district_category$population*100000,1)
# for map/table making purposes, changing Inf and NaN in calc fields to NA
district_category <- district_category %>%
  mutate_if(is.numeric, ~ifelse(. == Inf, NA, .))
district_category <- district_category %>%
  mutate_if(is.numeric, ~ifelse(. == "NaN", NA, .))

# Calculate total of each type of crime BY POLICE BEAT
district_type <- fay_crime %>%
  group_by(district,type,year) %>%
  summarise(count = n()) %>%
  arrange(year) %>%
  pivot_wider(names_from=year, values_from=count)
# merging with full list so we have data for every beat, every type
district_type <- left_join(list_district_type,district_type,by=c("district"="district","type"="type"))
# rename the year columns
district_type <- district_type %>% 
  rename("total19" = "2019",
         "total20" = "2020",
         "total21" = "2021",
         "total22" = "2022",
         "total23" = "2023")
# add last 12 months
district_type_last12 <- fay_crime_last12 %>%
  group_by(district,type) %>%
  summarise(last12mos = n())
district_type <- left_join(district_type,district_type_last12,by=c("district","type"))
rm(district_type_last12)
# add zeros where there were no crimes tallied that year
district_type[is.na(district_type)] <- 0
# Calculate a total across the 3 prior years
district_type$total_prior3years <- district_type$total20+district_type$total21+district_type$total22
district_type$avg_prior3years <- round(district_type$total_prior3years/3,1)
# calculate increases
district_type$inc_19to22 <- round(district_type$total22/district_type$total19*100-100,1)
district_type$inc_19tolast12 <- round(district_type$last12mos/district_type$total19*100-100,1)
district_type$inc_22tolast12 <- round(district_type$last12mos/district_type$total22*100-100,1)
district_type$inc_prior3yearavgtolast12 <- round((district_type$last12mos/district_type$avg_prior3years)*100-100,0)
# add population for beats
district_type <- full_join(districts,district_type,by=c("zone"="district"))
# calculate the beat by beat rates PER 1K people
district_type$rate19 <- round(district_type$total19/district_type$population*100000,1)
district_type$rate20 <- round(district_type$total20/district_type$population*100000,1)
district_type$rate21 <- round(district_type$total21/district_type$population*100000,1)
district_type$rate22 <- round(district_type$total22/district_type$population*100000,1)
district_type$rate_last12 <- round(district_type$last12mos/district_type$population*100000,1)
# calculate a multiyear rate
district_type$rate_prior3years <- round(district_type$avg_prior3years/district_type$population*100000,1)
# for map/table making purposes, changing Inf and NaN in calc fields to NA
district_type <- district_type %>%
  mutate_if(is.numeric, ~ifelse(. == Inf, NA, .))
district_type <- district_type %>%
  mutate_if(is.numeric, ~ifelse(. == "NaN", NA, .))

# output various csvs for basic tables to be made with crime totals
# we are dropping geometry for beats here because this is just for reference tables
district_detailed %>% st_drop_geometry() %>% write_csv("data/output/districts/district_detailed.csv")
district_category %>% st_drop_geometry() %>% write_csv("data/output/districts/district_category.csv")
district_type %>% st_drop_geometry() %>% write_csv("data/output/districts/district_type.csv")
citywide_detailed %>% write_csv("data/output/city/citywide_detailed.csv")
citywide_category %>% write_csv("data/output/city/citywide_category.csv")
citywide_type %>% write_csv("data/output/city/citywide_type.csv")

# Create individual spatial tables of crimes by major categories and types
murders_district <- district_category %>% filter(category=="Murder")
sexassaults_district <- district_category %>% filter(category=="Sexual Assault")
autothefts_district <- district_category %>% filter(category=="Motor Vehicle Theft")
thefts_district <- district_category %>% filter(category=="Theft")
burglaries_district <- district_category %>% filter(category=="Burglary")
robberies_district <- district_category %>% filter(category=="Robbery")
assaults_district <- district_category %>% filter(category=="Aggravated Assault")
violence_district <- district_type %>% filter(type=="Violent")
property_district <- district_type %>% filter(type=="Property")

# Create same set of tables for citywide figures
murders_city <- citywide_category %>% filter(category=="Murder")
sexassaults_city <- citywide_category %>% filter(category=="Sexual Assault")
autothefts_city <- citywide_category %>% filter(category=="Motor Vehicle Theft")
thefts_city <- citywide_category %>% filter(category=="Theft")
burglaries_city <- citywide_category %>% filter(category=="Burglary")
robberies_city <- citywide_category %>% filter(category=="Robbery")
assaults_city <- citywide_category %>% filter(category=="Aggravated Assault")
violence_city <- citywide_type %>% filter(type=="Violent")
property_city <- citywide_type %>% filter(type=="Property")

# Create individual csv files crimes by major categories and types for use in datawrapper tables
murders_district %>% st_drop_geometry() %>% write_csv("data/output/districts/murders_district.csv")
sexassaults_district %>% st_drop_geometry() %>% write_csv("data/output/districts/sexassaults_district.csv")
autothefts_district %>% st_drop_geometry() %>% write_csv("data/output/districts/autothefts_district.csv")
thefts_district %>% st_drop_geometry() %>% write_csv("data/output/districts/thefts_district.csv")
burglaries_district %>% st_drop_geometry() %>% write_csv("data/output/districts/burglaries_district.csv")
robberies_district %>% st_drop_geometry() %>% write_csv("data/output/districts/robberies_district.csv")
assaults_district %>% st_drop_geometry() %>% write_csv("data/output/districts/assaults_district.csv")
violence_district %>% st_drop_geometry() %>% write_csv("data/output/districts/violence_district.csv")
property_district %>% st_drop_geometry() %>% write_csv("data/output/districts/property_district.csv")

# Saving citywide files for each crime category for building tracker pages
saveRDS(murders_city,"scripts/rds/murders_city.rds")
saveRDS(assaults_city,"scripts/rds/assaults_city.rds")
saveRDS(sexassaults_city,"scripts/rds/sexassaults_city.rds")
saveRDS(autothefts_city,"scripts/rds/autothefts_city.rds")
saveRDS(thefts_city,"scripts/rds/thefts_city.rds")
saveRDS(burglaries_city,"scripts/rds/burglaries_city.rds")
saveRDS(robberies_city,"scripts/rds/robberies_city.rds")

# Saving district files for each crime category for building tracker pages
saveRDS(murders_district,"scripts/rds/murders_district.rds")
saveRDS(assaults_district,"scripts/rds/assaults_district.rds")
saveRDS(sexassaults_district,"scripts/rds/sexassaults_district.rds")
saveRDS(autothefts_district,"scripts/rds/autothefts_district.rds")
saveRDS(thefts_district,"scripts/rds/thefts_district.rds")
saveRDS(burglaries_district,"scripts/rds/burglaries_district.rds")
saveRDS(robberies_district,"scripts/rds/robberies_district.rds")

# Get latest date in our file and save for update date in tracker markdowns
asofdate <- max(fay_crime$date)
saveRDS(asofdate,"scripts/rds/asofdate.rds")

# Filters shared death causes data to North Carolina specific table
deaths <- read_excel("data/source/health/deaths.xlsx") 
deaths <- deaths %>% filter(state=="NC")
# Adds latest homicide rate for comparison
deaths$Homicide <- murders_city$rate_last12
write_csv(deaths,"data/source/health/death_rates.csv")