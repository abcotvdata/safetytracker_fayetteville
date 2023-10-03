library(tidyverse)
library(sf)
library(lubridate)

### PIPELINE TO IMPORT FAYETTEVILLE PD'S FULL DATABASE OF CRIME INCIDENTS FROM ITS ARCGIS SERVICE
# Fayetteville PD updates this data daily, but there's a max output of 1,000 records for each download
# So we're going to automate a stream to grab each and append to a df

# STEP 1: Creating an empty dataframe that matches precisely the format we're going to stream these files into one by one
download.file("https://gismaps.ci.fayetteville.nc.us/opendata/rest/services/Police/IncidentsCrimesAgainstPersons/MapServer/0/query?where=0%3D0&text=&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=*&returnGeometry=true&returnTrueCurves=false&maxAllowableOffset=&geometryPrecision=&outSR=&having=&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&historicMoment=&returnDistinctValues=false&resultOffset=&resultRecordCount=&queryByDistance=&returnExtentOnly=false&datumTransformation=&parameterValues=&rangeValues=&quantizationParameters=&featureEncoding=esriDefault&f=geojson","file.json")
fayetteville_new <- st_read("file.json")
fayetteville_new <- fayetteville_new %>% slice_head(n = 0)

# Set sequences for people, property data stream loops
# Setting separately because each one has a slightly different volume of records
# This setting makes sure we're getting about 6 months worth of recent data, which is overkill, but safest for redundancy
people_offsets <- seq(0, 3000, by = 1000)
property_offsets <- seq(0, 5000, by = 1000)

# Function to build url list and append data for the crimes against people records feed
for(i in people_offsets) {
  # Build full url
  temp_url <- paste0("https://gismaps.ci.fayetteville.nc.us/opendata/rest/services/Police/IncidentsCrimesAgainstPersons/MapServer/0/query?where=0%3D0&text=&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=*&returnGeometry=true&returnTrueCurves=false&maxAllowableOffset=&geometryPrecision=&outSR=&having=&returnIdsOnly=false&returnCountOnly=false&orderByFields=Date_Incident+DESC&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&historicMoment=&returnDistinctValues=false&resultOffset=",
                     i,
                     "&resultRecordCount=&queryByDistance=&returnExtentOnly=false&datumTransformation=&parameterValues=&rangeValues=&quantizationParameters=&featureEncoding=esriDefault&f=geojson")
  # Download and read the JSON file into a dataframe
  temp_df <- st_read(temp_url)
  # Append to df
  fayetteville_new <- bind_rows(fayetteville_new, temp_df)
  # short 3 second between iterations to reduce errors/stoppages
  Sys.sleep(3)
}

# Function to build url list and append data for the crimes against property records
# appending them to the streams of records from the crimes against people records above
for(i in property_offsets) {
  # Build full url
  temp_url <- paste0("https://gismaps.ci.fayetteville.nc.us/opendata/rest/services/Police/IncidentsCrimesAgainstProperty/MapServer/0/query?where=0%3D0&text=&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=*&returnGeometry=true&returnTrueCurves=false&maxAllowableOffset=&geometryPrecision=&outSR=&having=&returnIdsOnly=false&returnCountOnly=false&orderByFields=Date_Incident+DESC&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&historicMoment=&returnDistinctValues=false&resultOffset=",
                     i,
                     "&resultRecordCount=&queryByDistance=&returnExtentOnly=false&datumTransformation=&parameterValues=&rangeValues=&quantizationParameters=&featureEncoding=esriDefault&f=geojson")
  # Download and read the JSON file into a dataframe
  temp_df <- st_read(temp_url)
  # Append to df from above
  fayetteville_new <- bind_rows(fayetteville_new, temp_df)
  # short 3 second between iterations to reduce errors/stoppages
  Sys.sleep(3)
}

# Time fields are in this esri data are ms from a UTC origin
# This is my saved function to convert the milliseconds from UTC 
ms_to_date = function(ms, t0="1970-01-01", timezone) {
  sec = ms / 1000
  as.POSIXct(sec, origin=t0, tz=timezone)
}

# Convert occurrence date fields from esri ms since utc origin to dates in Central tz
# Add time fields as they exist in the main file we're appending to later
fayetteville_new$date <- ms_to_date(as.numeric(fayetteville_new$Date_Incident), timezone="GMT")
fayetteville_new$date <- as.Date(substr(fayetteville_new$date,1,10))
fayetteville_new$hour <- substr(fayetteville_new$fayPD_TOD,1,2)
fayetteville_new$year <- year(fayetteville_new$date)
fayetteville_new$month <- lubridate::floor_date(as.Date(fayetteville_new$date),"month")

# Adapt the fayetteville_new file to match the style of larger full-file dataframe covering 2010-recent
#fayetteville_new$longitude <- st_coordinates(fayetteville_new)[, 1]
#fayetteville_new$latitude <- st_coordinates(fayetteville_new)[, 2]
fayetteville_new <- fayetteville_new %>% janitor::clean_names() %>% st_drop_geometry()
fayetteville_new[fayetteville_new == ""] <- NA

# Drop apt, date_incident and date_secure from dataframe
fayetteville_new$date_incident <- NULL
fayetteville_new$date_secure <- NULL
fayetteville_new$reportarea <- NULL
#fayetteville_new$premise <- NULL

# Save copies of newly-processed recent file for redundancy
# Latest day archived in source data as backup; overwritten daily
saveRDS(fayetteville_new,"data/source/recent/fayetteville_new.rds")
# Latest day stored in scripts file for pickup by script that builds tracker
# If for some reason the script fails, file from day before is there and in recent
saveRDS(fayetteville_new,"scripts/rds/fayetteville_new.rds")
