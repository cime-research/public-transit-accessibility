##################################################
## Project:         CIME Adjacency
## Script name:     destination_processing.py
## Script purpose:  Utilizing the main DataAxle csv, extract relevant records
##                  related to the GEOIDs discovered during the preprocessing script.
## Script output:   1. A .csv of all destinations, including parks, in the format 
##                     expected of r5r.
## Date:            5/16/2025
## Author:          Vincent Ader (U-Mich, CIME)
##################################################

import pandas as pd
import numpy as np
import os
from naisc_code_parsing import parse_sic_code_list

year = "2024"

base_dir = f"H:/Data/Data Axle/splits/{year}"
location_base_dir = f"H:/All Lab/A. Vince Ader/data_processing/red_rose/data"

for cell in os.listdir(location_base_dir):
    print("Procssing: " + cell)
    # UPDATE to the folder you are working in
    location_dir = f"H:/All Lab/A. Vince Ader/data_processing/red_rose/data/census_blocks.csv"

    location_data = pd.read_csv(location_dir, dtype=str)
    geoid_list = list(location_data['GEOID20'])
    print(str(len(geoid_list)))
    geoid_list = [g[:-4] for g in geoid_list]
    geoid_list = list(set(geoid_list))
    print(str(len(geoid_list)))
    final_sic_list, final_paired_code_list = parse_sic_code_list()
    final_sic_list_str = list(map(str,final_sic_list))

    filtered_full_data_axle = pd.DataFrame() # need to copy shape + add geoid? 

    for filename in os.listdir(base_dir):

        # Load the main file, this takes a while (it's over 6gigs!)
        print("Loading file: " + str(filename))
        data_axle_input = pd.read_csv(os.path.join(base_dir, filename), dtype=str)

        # Copy the structure of the original file
        filtered_data_axle = data_axle_input[data_axle_input['PRIMARY SIC CODE'].isin(final_sic_list_str)]

        community_data_axle = data_axle_input[data_axle_input['COMPANY'].str.contains('|'.join(["YMCA","YWCA","Jewish Community Center"]),case=False,na=False)]
        filtered_data_axle = pd.concat([filtered_data_axle, community_data_axle])

        for index, row in final_paired_code_list.iterrows():
            # Turn code list into strings for comparison
            code_list = list(map(str,row['code_list']))

            # Find all codes in this iteration of the code list
            paired_filter_data_axle = data_axle_input[data_axle_input['PRIMARY SIC CODE'].isin(code_list)]
            
            # Find all rows with words paired with above codes
            paired_filter_with_words_data_axle = paired_filter_data_axle[paired_filter_data_axle['COMPANY'].str.contains('|'.join(row['word_list']),case=False, na=False)]
            
            # Concatenate the list to our final list
            filtered_data_axle = pd.concat([filtered_data_axle, paired_filter_with_words_data_axle])

        filtered_data_axle['GEOID'] = filtered_data_axle['FIPS CODE'] + filtered_data_axle['CENSUS TRACT']
        filtered_data_axle = filtered_data_axle[filtered_data_axle['GEOID'].isin(geoid_list)]

        filtered_full_data_axle = pd.concat([filtered_full_data_axle, filtered_data_axle])


    # rename some fields so we can merge to parks data and so they fit r5r expectations
    filtered_full_data_axle.rename(columns={"Unnamed: 0": "id"}, inplace= True)
    filtered_full_data_axle.rename(columns={"LATITUDE": "lat"}, inplace= True)
    filtered_full_data_axle.rename(columns={"LONGITUDE": "lon"}, inplace= True)

    # Open parks data
    parks_dir = "U:/Kines/preprocessing_testing/data/park_destinations.csv"
    parks_data = pd.read_csv(parks_dir, dtype=str)

    # Concatenate Parks data to our data axle data
    filtered_full_destinations = pd.concat([filtered_full_data_axle, parks_data])

    # Add a destination field for r5r, all destinations are weighted the same
    filtered_full_destinations['destination'] = 1

    # Save our output
    # UPDATE to the folder you're working in.
    filtered_full_destinations.to_csv(f"H:/All Lab/A. Vince Ader/data_processing/red_rose/data/filtered_destinations.csv")

    print("Finished all files :)")