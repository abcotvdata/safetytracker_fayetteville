library(tidyverse)
library(tidycensus)
library(leaflet)
library(leaflet.extras)
library(leaflet.providers)
library(sf)

# GEOGRAPHY
# Get Raleigh police districts/beats
download.file("https://services.arcgis.com/j3zNT485kmwrBtMJ/ArcGIS/rest/services/Police_Zones/FeatureServer/0/query?where=0%3D0&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&relationParam=&returnGeodetic=false&outFields=*&returnGeometry=true&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=&defaultSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pgeojson",
              "data/source/geo/fayetteville_police_districts.geojson")

# Read in geojson and then transform to sf format
districts_geo <- st_read("data/source/geo/fayetteville_police_districts.geojson") %>% st_transform(3857)

districts_geo <- districts_geo %>% 
  group_by(ZONE) %>%
  summarise(geometry = sf::st_union(geometry)) %>%
  ungroup()

# Get demographic data for Census block groups to aggregate/apportion to precinct geography
# Also transforming to match the planar projection of NYPD's beats spatial file
# This also reduces us down to just the numeric population est and geometry
blocks <- get_decennial(geography = "block", 
                        year = 2020,
                        output = 'wide',
                        variables = "P1_001N", 
                        state = "NC",
                        county = c("Cumberland"),
                        geometry = TRUE) %>%
  rename("population"="P1_001N") %>% 
  select(3) %>%
  janitor::clean_names() %>%
  st_transform(3857)

# Calculate the estimated population of police BEATS geographies/interpolate with tidycensus bgs
# Reminder: ext=true SUMS the population during interpolation
districts_withpop <- st_interpolate_aw(blocks, districts_geo, ext = TRUE)
# Drops geometry so it's not duplicated in the merge
districts_withpop <- st_drop_geometry(districts_withpop)
# Binds that new population column to the table
districts_geo <- cbind(districts_geo,districts_withpop)
# Cleans up unneeded calculation file
# rm(districts_withpop, blocks)

# Check total population assigned/estimated across all precincts
sum(districts_geo$population) # tally is 453321 

# Round the population figure; rounded to nearest thousand
districts_geo$population <- round(districts_geo$population,-2)
# Prep for tracker use
districts_geo <- districts_geo %>% st_transform(4326)
districts_geo <- st_make_valid(districts_geo) %>% janitor::clean_names()

# Quick define of the areas 
districts_geo$placename <- case_when(districts_geo$zone == "01"~ "Murchison Road",
                                     districts_geo$zone == "02"~ "Hillendale, Rivercliff and Country Club North",
                                     districts_geo$zone == "03"~ "North Street Park and Winter Terrace Park",
                                     districts_geo$zone == "04"~ "East Fayetteville",
                                     districts_geo$zone == "05"~ "Southwest of Downtown",
                                     districts_geo$zone == "06"~ "Bordeaux and Holiday Park",
                                     districts_geo$zone == "07"~ "Haymount",
                                     districts_geo$zone == "08"~ "Edenroc and Greenwood Homes",
                                     districts_geo$zone == "09"~ "Green Valley Estates and Kornbow",
                                     districts_geo$zone == "10"~ "Kirkwood",
                                     districts_geo$zone == "11"~ "Downtown Fayetteville",
                                     districts_geo$zone == "12"~ "Wooded Lake and Jordan Soccer Complex",
                                     districts_geo$zone == "13"~ "Montclair",
                                     districts_geo$zone == "14"~ "North Reilly Road",
                                     districts_geo$zone == "15"~ "Beaver Creek and Cottonade",
                                     districts_geo$zone == "16"~ "Loch Lommond and Beaver Creek Pond",
                                     districts_geo$zone == "17"~ "Hollywood Heights",
                                     districts_geo$zone == "18"~ "Southwest Raleigh",
                                     districts_geo$zone == "19"~ "Oakdale, Queensdale and Sherwood Park",
                                     districts_geo$zone == "20"~ "Northeast Raleigh",
                                     districts_geo$zone == "21"~ "Brentwood, Arran Lakes and Ducks Landing",
                                     districts_geo$zone == "22"~ "Murchison Road",
                                     districts_geo$zone == "23"~ "Hickory Grove and Bluewood Springs",
                                     districts_geo$zone == "24"~ "Stoney Point Road",
                                     districts_geo$zone == "25"~ "Lake Rim",
                                     districts_geo$zone == "26"~ "Hoke Loop Road",
                                     districts_geo$zone == "AP"~ "Airport",
                                     TRUE ~ "Unknown")

# saving a clean geojson and separate RDS for use in tracker
file.remove("data/output/geo/fayetteville_districts.geojson")
st_write(districts_geo,"data/output/geo/fayetteville_districts.geojson")
saveRDS(districts_geo,"scripts/rds/fayetteville_districts.rds")

# BEAT MAP JUST FOR TESTING PURPOSES
# CAN COMMENT OUT ONCE FINALIZED
# Set bins for beats pop map
popbins <- c(0,5000,10000,15000,20000,50000, Inf)
poppal <- colorBin("YlOrRd", districts_geo$population, bins = popbins)
poplabel <- paste(sep = "<br>", districts_geo$zone,districts_geo$placename,prettyNum(districts_geo$population, big.mark = ","))

fayetteville_districts_map <- leaflet(districts_geo) %>%
  setView(-78.94, 35.06, zoom = 11.5) %>% 
  addProviderTiles(provider = "CartoDB.Positron") %>%
  addPolygons(color = "white", popup = poplabel, weight = 3, smoothFactor = 0.5,
              opacity = 1, fillOpacity = 0.3,
              fillColor = ~poppal(`population`))
fayetteville_districts_map