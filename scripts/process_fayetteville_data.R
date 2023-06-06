library(tidyverse)
library(sf)
library(readxl)
library(zoo)
library(lubridate)

# starting to lay out crime data sourcing

download.file("https://opendata.arcgis.com/api/v3/datasets/24c0b37fa9bb4e16ba8bcaa7e806c615_0/downloads/data?format=csv&spatialRefId=4326",
              "raleigh_crime.csv")

raleigh_crime <- read_csv("raleigh_crime.csv") %>% select(5:22)
