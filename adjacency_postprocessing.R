##################################################
## Project:         CIME Adjacency
## Script purpose:  Processes generated adjacency data from r5r. This script 
##                  generates a data set for each origin consider in the adjacency.R
##                  script.
## Script output:   1. 9 images of all census block origins for each parameter set
##                     and trip scenario.
##                  2. A final data set of all 9 combinations of parameter set and trip
##                     scenarios, providing a reachable destination count for each
##                     by census block.
## Date:            9/4/2026
## Author:          Vincent Ader (U-Mich, CIME)
##################################################

library(sf)
library(data.table)
library(ggplot2)
library(dplyr)
library(viridis)
library(stringr)

# grab shapefile
setwd("H:/All Lab/A. Vince Ader/data_processing/shared/")
# UPDATE to the state code
census_blocks_shape <- read_sf("state_census_block.shp")

# UPDATE to the region you are processing
setwd("H:/All Lab/A. Vince Ader/data_processing/<UPDATE>")
input_dir <- paste(getwd(),"data",sep = "/")
output_dir <- paste(getwd(),"output",sep = "/")

# Grab census blocks so we can join
setwd(input_dir)
census_blocks_csv <- fread("census_blocks.csv")
 
# Open all of our 
setwd(output_dir)
design_transit <- fread("design_transit_access_60.csv")
design_walk <- fread("design_walk_access.csv")
older_transit <- fread("older_transit_access_60.csv")
older_walk <- fread("older_walk_access.csv")
disability_transit <- fread("disability_transit_access_60.csv")
disability_walk <- fread("disability_walk_access.csv")

# design joining to census tract
design_30 <- design_transit[design_transit$cutoff == 30,]
design_60 <- design_transit[design_transit$cutoff == 60,]
design_30 <- design_30 %>% rename(design_30 = accessibility)
design_60 <- design_60 %>% rename(design_60 = accessibility)
design_walk <- design_walk %>% rename(design_walk = accessibility)
design_wide <- left_join(design_30, design_60, c("id" = "id"))
design_wide <- left_join(design_wide, design_walk, c("id" = "id"))

design_geoid <- left_join(design_wide, census_blocks_csv, c("V1" = "V1"))
design_geoid <- design_geoid %>%
  mutate(GEOID20 = str_pad(GEOID20, width=15, pad="0"))
design_shape <- left_join(design_geoid, census_blocks_shape, c("GEOID20" = "GEOID20"))
design_shape$area <- design_shape$ALAND

range_30 <- range(design_30$design_30)
range_60 <- range(design_60$design_60)
range_walk <- range(design_walk$design_walk)

# draw design 30
ggplot() +
  geom_sf(data = design_shape, aes(geometry = geometry, fill = design_30), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_30) 
ggsave("design_access_30.png", width = 6, height = 6, units = "in")

# draw design 60
ggplot() +
  geom_sf(data = design_shape, aes(geometry = geometry, fill = design_60), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_60) 
ggsave("design_access_60.png", width = 6, height = 6, units = "in")

# draw design walk
ggplot() +
  geom_sf(data = design_shape, aes(geometry = geometry, fill = design_walk), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_walk) 
ggsave("design_access_walk.png", width = 6, height = 6, units = "in")

# older joining to census tract
older_30 <- older_transit[older_transit$cutoff == 30,]
older_60 <- older_transit[older_transit$cutoff == 60,]
older_30 <- older_30 %>% rename(older_30 = accessibility)
older_60 <- older_60 %>% rename(older_60 = accessibility)
older_walk <- older_walk %>% rename(older_walk = accessibility)
older_wide <- left_join(older_30, older_60, c("id" = "id"))
older_wide <- left_join(older_wide, older_walk, c("id" = "id"))

older_geoid <- left_join(older_wide, census_blocks_csv, c("V1" = "V1"))
older_geoid <- older_geoid %>%
  mutate(GEOID20 = str_pad(GEOID20, width=15, pad="0"))
older_shape <- left_join(older_geoid, census_blocks_shape, c("GEOID20" = "GEOID20"))

# draw older 30
ggplot() +
  geom_sf(data = older_shape, aes(geometry = geometry, fill = older_30), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_30)  
ggsave("older_access_30.png", width = 6, height = 6, units = "in")

# draw older 60
ggplot() +
  geom_sf(data = older_shape, aes(geometry = geometry, fill = older_60), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_60) 
ggsave("older_access_60.png", width = 6, height = 6, units = "in")

# draw older walk
ggplot() +
  geom_sf(data = older_shape, aes(geometry = geometry, fill = older_walk), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_walk) 
ggsave("older_access_walk.png", width = 6, height = 6, units = "in")

# disability joining to census tract
disability_30 <- disability_transit[disability_transit$cutoff == 30,]
disability_60 <- disability_transit[disability_transit$cutoff == 60,]
disability_30 <- disability_30 %>% rename(disability_30 = accessibility)
disability_60 <- disability_60 %>% rename(disability_60 = accessibility)
disability_walk <- disability_walk %>% rename(disability_walk = accessibility)
disability_wide <- left_join(disability_30, disability_60, c("id" = "id"))
disability_wide <- left_join(disability_wide, disability_walk, c("id" = "id"))

disability_geoid <- left_join(disability_wide, census_blocks_csv, c("V1" = "V1"))
disability_geoid <- disability_geoid %>%
  mutate(GEOID20 = str_pad(GEOID20, width=15, pad="0"))
disability_shape <- left_join(disability_geoid, census_blocks_shape, c("GEOID20" = "GEOID20"))

# draw disability 30
ggplot() +
  geom_sf(data = disability_shape, aes(geometry = geometry, fill = disability_30), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_30) 
ggsave("disability_access_30.png", width = 6, height = 6, units = "in")

# draw disability 60
ggplot() +
  geom_sf(data = disability_shape, aes(geometry = geometry, fill = disability_60), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_60) 
ggsave("disability_access_60.png", width = 6, height = 6, units = "in")

# draw disability walk
ggplot() +
  geom_sf(data = disability_shape, aes(geometry = geometry, fill = disability_walk), color = NA)+
  scale_fill_gradientn(colors=viridis_pal()(9), limits = range_walk) 
ggsave("disability_access_walk.png", width = 6, height = 6, units = "in")


# Merge all data into a singular file for better visualisations
interim_table <- merge(x = design_shape[, c("GEOID20","area","design_30","design_60","design_walk")], 
                     y = older_shape[, c("GEOID20","older_30","older_60","older_walk")],
                     by = "GEOID20",
                     all.x=TRUE)
final_table <- merge(x = interim_table,
                     y = disability_shape[, c("GEOID20","disability_30","disability_60","disability_walk")],
                     by = "GEOID20",
                     all.x=TRUE)
write.csv(final_table, "accessibility.csv", row.names = FALSE)
summary(final_table)