library(tidyverse)
library(sf)
library(readxl)
library(zoo)
library(lubridate)

# starting to lay out crime data sourcing

download.file("https://opendata.arcgis.com/api/v3/datasets/f52ad2a08f5c405d8b1d0f333c34824e_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "fayetteville_crime_people.csv")
download.file("https://opendata.arcgis.com/api/v3/datasets/7bc2bd68adb3453496b305c764390887_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "fayetteville_crime_society.csv")
download.file("https://opendata.arcgis.com/api/v3/datasets/f52ad2a08f5c405d8b1d0f333c34824e_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "fayetteville_crime_property.csv")


raleigh_crime <- read_csv("raleigh_crime.csv") %>% select(5:22)
