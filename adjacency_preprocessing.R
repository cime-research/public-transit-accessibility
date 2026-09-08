##################################################
## Project:         CIME Adjacency
## Script purpose:  Preprocess data for r5r. This script specifically includes
##                  creating a buffer from a set of GTFS .zip files and identifying
##                  surrounding census blocks. From there, it creates origin points
##                  for every every census block centroid for use as r5r origins.
##                  Also searches for the related .osm.pbf file and downloads it.
## Script output:   1. A shapefile of the census blocks, and their dissolve.
##                  2. A .csv of all origins points, with included ID, latitude, 
##                     and longitude.
##                  3. The .osm.pbf file relevant to the local area.
## Date:            9/4/2025
## Author:          Vincent Ader (U-Mich, CIME)
##################################################

library(r5r)
library(sf)
library(data.table)
library(ggplot2)
library(tidytransit)
library(dplyr)
library(osmextract)
library(gtfstools)

# Set working directory, should contain all input data
# UPDATE: change folder name to region you are processing
setwd("H:/All Lab/A. Vince Ader/data_processing/<UPDATE>")
input_dir <- paste(getwd(),"data",sep = "/")
setwd(input_dir)

# Create Origins
# Find all zip files (GTFS)
zip_files <- list.files(path = input_dir, pattern = "\\.zip$")
zip_count <- length(zip_files)

# Open census block file
# UPDATE: to the state census block code related to the region you are processing
census_blocks_full <- "H:/All Lab/A. Vince Ader/data_processing/shared/<UPDATE>"

# Open Census blocks as a simple feature
census_blocks <- read_sf(census_blocks_full)

# Remove Census blocks that are water only
census_blocks <- census_blocks[census_blocks$ALAND20 > 0,]

# CRS 4269 = NAD83, in degrees. Default for Census block shapefiles.
full_gtfs_sf <- st_sf(id = 1:zip_count, crs = 4269, geometry = st_sfc(lapply(1:zip_count, function(x) st_geometrycollection())))

# Create an index to manually assign output in the upcoming loop
index = 1

# Leave commented, sf assumes spherical geometry and sometimes GTFS files
# don't plan for that, uncomment if needed, the error should recommend to do so.
# sf_use_s2(FALSE)

# Loop through each GTFS zip file
for (zip in zip_files) {
  # print(paste0("index = ",index))
  
  # Reads the GTFS file
  gtfs <- read_gtfs(zip)
  
  # Arranging the shapes in order by id
  gtfs$shapes <- gtfs$shapes %>%
    arrange(shape_id, shape_pt_sequence)
  
  # Converting the text shapes to simple features
  gtfs_sf <- convert_shapes_to_sf(gtfs)

  # Setting GTFS to the route geometry variable
  route_geometry <- gtfs_sf 
  
  # Dissolve Geometry 
  route_geometry <- mutate(route_geometry, group = c(rep(0,nrow(route_geometry))))
  route_geometry <- group_by(route_geometry, group)
  
  # Convert to census block CRS (also in meters)
  route_geometry <- st_transform(route_geometry, crs = 4269)
  route_geom_dissolved <- summarise(route_geometry)
  
  #st_write(route_geom_dissolved, paste(input_dir,paste0(zip,".shp"),sep="/"))
  
  # buffer the route
  route_geom_buffered <- st_buffer(route_geom_dissolved, 1500)
  
  # Add route geometry to our final list
  full_gtfs_sf[index,] <- route_geom_buffered
  
  # increment index
  index <- index + 1
}

# Dissolving and merging the GTFS geometry to buffer later
final_geom_dissolved <- mutate(full_gtfs_sf, group = c(rep(0,nrow(full_gtfs_sf))))
final_geom_dissolved <- group_by(final_geom_dissolved, group)
final_geom_dissolved <- summarise(final_geom_dissolved)
final_geom_dissolved <- st_make_valid(final_geom_dissolved)

# Intersect buffer with Census blocks
intersecting_blocks <- st_intersects(census_blocks, final_geom_dissolved)

# Select blocks that intersect
census_blocks_selection <- census_blocks[lengths(intersecting_blocks) > 0, ]

# Writing the census block shapefile relevant to the region
st_write(census_blocks_selection, paste(input_dir,"census_blocks_selection_shapefile.shp",sep = "/"))

# Remove geometry and select GEOID so we can output a list of census blocks
census_blocks_GEOID <- st_drop_geometry(census_blocks_selection[c("GEOID20")])

# Save list of census blocks for origins and destination selection
write.csv(census_blocks_GEOID, paste(input_dir,"census_blocks.csv",sep = "/"))

# Dissolve census blocks into single polygon
census_blocks_selection <- mutate(census_blocks_selection, group = c(rep(0,nrow(census_blocks_selection))))
census_blocks_selection <- group_by(census_blocks_selection, group)
census_blocks_dissolve <- summarise(census_blocks_selection)

# Export this polygon to use for USGS tif finding
st_write(census_blocks_dissolve, paste(input_dir,"census_block_shapefile.shp",sep = "/"))

# convert census blocks to a metric CRS (I should probably find one that's good
# for the overall US, but for now this works)
census_blocks_dissolve <- st_transform(census_blocks_dissolve, crs = 6498)

# Find the origins of each block
origins_grid <- st_centroid(census_blocks_selection)

# Convert grid points to GPS
# CRS 4326 = WGS84, back into degrees as we need coordinates for origins
origins_grid <- st_transform(origins_grid, crs = 4326)

# Make table that works as origins in r5r
origins_table <- do.call(rbind, st_geometry(origins_grid)) %>% 
  as_tibble() %>% setNames(c("lon","lat"))

# add ids so we can use them to link and plot later
origins_table$id <- seq(1:nrow(origins_table))

# write the origins table
write.csv(origins_table, paste(input_dir,paste0("origins_table.csv"),sep = "/"))

# find & download osm.pbf closest to the related area
osm_path <- oe_match(census_blocks_dissolve)

# Uncomment if you want to download the .osm.pbf file
#oe_download(osm_path$url, download_directory = input_dir)
