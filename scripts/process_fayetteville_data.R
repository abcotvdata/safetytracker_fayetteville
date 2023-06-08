library(tidyverse)
library(sf)
library(readxl)
library(zoo)
library(lubridate)

# starting to lay out crime data sourcing

download.file("https://opendata.arcgis.com/api/v3/datasets/f52ad2a08f5c405d8b1d0f333c34824e_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "data/source/fayetteville_crime_people.csv")
download.file("https://opendata.arcgis.com/api/v3/datasets/7bc2bd68adb3453496b305c764390887_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "data/source/fayetteville_crime_society.csv")
download.file("https://opendata.arcgis.com/api/v3/datasets/74f34da7e6f1404f868fd9e22bf9f09c_0/downloads/data?format=csv&spatialRefId=4326&where=1%3D1",
              "data/source/fayetteville_crime_property.csv")

download.file("https://gismaps.ci.fayetteville.nc.us/opendata/rest/services/Police/IncidentsCrimesAgainstProperty/MapServer/0/query?outFields=*&where=1%3D1&f=geojson",
              "data/source/fayetteville_crime_property.geojson")

prop <- st_read("data/source/fayetteville_crime_property.geojson")


raleigh_crime <- read_csv("raleigh_crime.csv") %>% select(5:22)

# police zones

https://services.arcgis.com/j3zNT485kmwrBtMJ/ArcGIS/rest/services/Police_Zones/FeatureServer/0/query?where=0%3D0&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&relationParam=&returnGeodetic=false&outFields=*&returnGeometry=true&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&defaultSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson&token=
  
  


