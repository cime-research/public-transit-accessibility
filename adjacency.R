##################################################
## Project:         CIME Adjacency
## Script purpose:  Post-processed data for r5r. This script utilizes processed 
##                  data sources to run through r5r. Expected files within working
##                  directory:
##                  1. GTFS files as .zip files
##                  2. Origin .csv
##                  3. Destination .csv
##                  4. Street network file as osm.pbf (generally needs to be clipped)
## Script output:   1. A .csv for each parameter set and transit scenario included,
##                     default 6. These include the number of reachable destinations
##                     from each census block centroid origin.
## Date:            9/4/2026
## Author:          Vincent Ader (U-Mich, CIME)
##################################################

# r5r Setup
# Identify local Java installation
# Sys.setenv(JAVA_HOME='C:/Program Files/Eclipse Adoptium/jdk-21.0.5.11-hotspot')

# Increase processing power
options(java.parameters = "-Xmx18G")

library(r5r)
library(sf)
library(data.table)
library(ggplot2)
library(tidytransit)
library(dplyr)

# UPDATE to your regional folder you are processing
setwd("H:/All Lab/A. Vince Ader/data_processing/red_rose")
input_dir <- paste(getwd(),"data",sep = "/")
output_dir <- paste(getwd(),"output",sep = "/")
setwd(input_dir)

# identify origins
origin <- fread("origins_table.csv")

# identify destinations
destination <- fread("filtered_destinations.csv")
destination <- st_as_sf(x = destination,
                        coords = c("lon","lat"),
                        crs = 4326)
destination$destination <- 1

# Use the census blocks as a boundary to filter out park destinations not within
# the region
boundary <- read_sf("census_block_shapefile.shp")
boundary <- st_transform(boundary, crs = 4326)

# Only select filtered destinations in the range 
intersecting_destination <- st_intersects(destination, boundary)

# Select blocks that intersect
destination_selection <- destination[lengths(intersecting_destination) > 0, ]

# Setting up base parameters
transit <- c("WALK","TRANSIT")
walk_only <- c("WALK")
mode_egress <- c("WALK")
time_window <- 600 # minutes

parameters <- data.frame(
  case_name = c("design", "older", "disability"), #
  walk_speed = c(4.4,2.7,2.2), # 
  max_walk_time = c(10,8,8) #
)

# UPDATE: Departure date time, using a series of intervals + time_window allows 
# us to test adjacency throughout the week
departure_datetime_in <- as.POSIXct("15-10-2025 08:15:00", format = "%d-%m-%Y %H:%M:%S")

print("Setting up network")

# Running r5r
# Setup r5r network, requires all preprocessed data in singular folder
data_path <- system.file(input_dir, package='r5r')
r5r_network_new <- build_network(input_dir, overwrite = TRUE, verbose = FALSE)

print("Beginning processing.")

# Looping through transit use cases
for (i in 1:nrow(parameters)){

  travel_time_matrix <- accessibility(r5r_network = r5r_network_new, 
                                           origins = origin, 
                                           destinations = destination_selection,
                                           mode = transit,
                                           mode_egress = mode_egress,
                                           max_walk_time = parameters$max_walk_time[i],
                                           walk_speed = parameters$walk_speed[i],
                                           max_trip_duration = 60,
                                           departure_datetime = departure_datetime_in,
                                           time_window = time_window,
                                           progress = TRUE,
                                           opportunities_colnames = c("destination"),
                                           cutoffs = c(30,60),
                                           verbose = FALSE)#output_dir = paste(output_dir) ,60
  
  # Save the output
  write.csv(travel_time_matrix, paste(output_dir,paste0(parameters$case_name[i],"_transit_access_60",".csv"),sep = "/"))
  rm(travel_time_matrix)
}

# Looping through walk-only use cases
for (i in 1:nrow(parameters)){
  
  
  travel_time_matrix <- accessibility(r5r_network = r5r_network_new, 
                                           origins = origin, 
                                           destinations = destination_selection,
                                           mode = walk_only,
                                           mode_egress = mode_egress,
                                           max_walk_time = parameters$max_walk_time[i],
                                           walk_speed = parameters$walk_speed[i],
                                           max_trip_duration = 15,
                                           departure_datetime = departure_datetime_in,
                                           time_window = time_window,
                                           progress = FALSE,
                                           opportunities_colnames = c("destination"),
                                           cutoffs = c(15))
                                           #output_dir = paste(output_dir))
   
  # Save the output
  write.csv(travel_time_matrix, paste(output_dir,paste0(parameters$case_name[i],"_walk_access",".csv"),sep = "/"))
  rm(travel_time_matrix)
}



# stop the network
r5r::stop_r5(r5r_network_new)

# call java garbage collection to clean up memory space
rJava::.jgc(R.gc = TRUE)