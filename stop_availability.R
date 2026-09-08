##################################################
## Project:         CIME Availability
## Script name:     stop_availability.R
## Script purpose:  Computes average arrivals-per-hour (APH) for every stop in
##                  every GTFS feed found under root_dir. For each transit
##                  agency subfolder, and for each GTFS .zip within it, joins
##                  stop_times to trips, determines each stop/route/service/
##                  direction combination's trip count and span of operating
##                  hours, then averages arrivals-per-hour across all
##                  combinations serving a stop. Expects one subfolder per
##                  transit agency under root_dir, each containing one or more
##                  GTFS .zip files.
## Script output:   One .csv per GTFS .zip, named
##                  "<gtfs_filename>_stops_average_aph.csv", with columns
##                  stop_id, stop_lat, stop_lon, average_aph, start_time,
##                  end_time. Written into the same agency subfolder as the
##                  source GTFS .zip; any pre-existing "*aph*" files in that
##                  subfolder are deleted first.
## Date:            9/8/2026
## Author:          Vincent Ader (U-Mich, CIME)
##################################################

library(sf)
library(data.table)
library(ggplot2)
library(tidytransit)
library(dplyr)
library(lubridate)
library(stringr)
library(hms)

root_dir <- "H:/All Lab/A. Vince Ader/Availability/completed_rerun_half_one"
setwd(root_dir)

# Get a list of folders to process
folder_list <- list.dirs(root_dir, full.names = TRUE, recursive = FALSE)
print(paste("Processing stops of transit systems from", length(folder_list), "folders."))

for(folder in folder_list) {
  
  unlink(paste(folder,"/*aph*", sep=""))
  
  # set directory for easy saving
  setwd(folder)
  
  # find all zips in the folder
  zip_list <- list.files(folder, pattern = "\\.zip$", full.names=TRUE)
  print(paste("Found", length(zip_list), "zipped GTFS files to process."))
  
  for(zip in zip_list) {
    
    #get the name of the file
    gtfs_name <- basename(zip)
    
    # read the gtfs file
    gtfs <- read_gtfs(gtfs_name)
    
    # get relevant tables from the GTFS file
    stops <- gtfs$stops
    trips <- gtfs$trips
    stop_times <- gtfs$stop_times
    
    if (n_distinct(trips$trip_id) != n_distinct(stop_times$trip_id)) {
      print("Mismatched trip IDs.")
    }
    
    # Merge stop times and trips
    schedule <- merge(stop_times, trips, by = "trip_id", all.x = TRUE)
    
    # Some GTFS don't have directions, apply a direction in this case
    if(length(schedule$direction_id[!is.na(schedule$direction_id)]) == 0){
      schedule$direction_id <- 0
    }
    
    # Set up the unique combinations table
    unique_combinations <- unique(schedule[,c("stop_id", "route_id", "service_id", "direction_id")])
    unique_combinations$trip_count <- 0
    unique_combinations$start_time <- lubridate::hms("00:00:00")
    unique_combinations$end_time <- lubridate::hms("00:00:00")
    
    # add a progress bar
    pb <- txtProgressBar(min = 0, max = nrow(unique_combinations), style = 3)
    
    for(i in 1:nrow(unique_combinations)) {
      # Filter schedule by unique combination
      filtered_schedule <- schedule %>% filter(stop_id == unique_combinations$stop_id[i],
                                                    route_id == unique_combinations$route_id[i],
                                                    service_id == unique_combinations$service_id[i],
                                                    direction_id == unique_combinations$direction_id[i])
      
      # If there are no trips for this combination, move on 
      if(nrow(filtered_schedule) < 1) {
        next
      }
      
      # Get count of trips
      unique_combinations$trip_count[i] <- nrow(filtered_schedule)
      
      # Arrange trips in chronological order
      filtered_schedule$arrival_time <- lubridate::hms(filtered_schedule$arrival_time)
      
      filtered_schedule$arrival_time
      filtered_schedule <- arrange(filtered_schedule, arrival_time)
      
      # Grab start & end times
      unique_combinations$start_time[i] <- filtered_schedule$arrival_time[1]
      unique_combinations$end_time[i] <- filtered_schedule$arrival_time[nrow(filtered_schedule)]
      
      # Update progress bar
      setTxtProgressBar(pb, i)
    }
    
    # Calculate hours of operation & make it in hours
    unique_combinations$hours_of_operation <- unique_combinations$end_time - unique_combinations$start_time
    unique_combinations$hours_of_operation <- as.numeric(unique_combinations$hours_of_operation) / 60 / 60
    
    # If there are trips but the hours of operation are less than one, set the hours to 1
    unique_combinations$hours_of_operation <- ifelse(unique_combinations$hours_of_operation < 1 & unique_combinations$trip_count > 0,
                                                     1,
                                                     unique_combinations$hours_of_operation)
    
    # Calculate arrivals per hour of operation
    unique_combinations$arrivals_per_hour_of_operation <- unique_combinations$trip_count / unique_combinations$hours_of_operation
    
    unique_combinations$start_time <- as.numeric(unique_combinations$start_time)
    unique_combinations$end_time <- as.numeric(unique_combinations$end_time)
    
    stop_summaries <- unique_combinations %>%
      group_by(stop_id) %>%
      summarize(
        average_aph = mean(arrivals_per_hour_of_operation),
        start_time = min(start_time),
        end_time = max(end_time)
      )
    
    # data type clean up
    stop_summaries$start_time <- hms::hms(stop_summaries$start_time)
    stop_summaries$end_time <- hms::hms(stop_summaries$end_time)
    
    stops_output <- left_join(stops, stop_summaries, by = "stop_id")
    
    # Make final dataset
    stops_output <- subset(stops_output, select = c(stop_id, stop_lat, stop_lon, average_aph, start_time, end_time))
    
    # Write final dataset
    write.csv(stops_output, paste0(gtfs_name, "_stops_average_aph.csv"), row.names = FALSE)
  }
}