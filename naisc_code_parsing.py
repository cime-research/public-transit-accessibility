##################################################
## Project:         CIME Adjacency
## Script name:     naisc_code_parsing.py
## Script purpose:  Hosts utility functions for destination processing.py.
## Script output:   See individual functions for details.
## Date:            5/16/2025
## Author:          Vincent Ader (U-Mich, CIME)
##################################################

import pandas as pd
import numpy as np


##################################################
## Function name:       parse_sic_code_list()
## Function purpose:    Parse through our six digit naisc code list and
##                      word list to develop a filter for all records within
##                      DataAxle. At inception, these were social and physical
##                      activity destinations.
## Function return:     1. final_sic_list: a list of all sic codes that are
##                         just code filters. 
##                      2. final_code_and_word_sic_list: a list of lists that
##                         contains all sic codes that are dependent on words
##                         that help define the filter.
##################################################
def parse_sic_code_list():

    base_dir = "U:/Kines/Destinations/input"
    sic_codes_input = pd.read_csv(base_dir + "/six_digit_test.csv", dtype=str, na_values={'Codes_With_Words':'str'})
    sic_codes_input.fillna(value="")
    chain_name_input = pd.read_csv(base_dir + "/technomics_chain_list.csv", dtype=str)

    final_sic_list = []
    interim_code_list = []
    interim_word_list = []

    count = 0

    # Creating a separate list to handle long input word lists, like casual dining
    def parse_chain_names(code_cell_value):

        chain_names = []
        csd_codes = []

        # Parse the chain names list
        for index, row in chain_name_input.iterrows():
            chain_name = row['Chain Name']
            chain_names.append(chain_name)
        
        for item in code_cell_value:      
            # Parse Ranges
            if item == '':
                continue
            elif '-' in item:
                code_range = item.split("-")
                for i in range(int(code_range[0]),int(code_range[1])):
                    csd_codes.append(i)
            # Parse Individual Values
            else: 
                csd_codes.append(int(item))
        
        interim_code_list.append(csd_codes)
        interim_word_list.append(chain_names)



    # Loop through rows
    for index, row in sic_codes_input.iterrows():   

        # Check if there are any values in the Codes column, if not, continue to the next row
        if pd.isna(row['SIC_Codes']) and pd.isna(row['Codes_With_Words']):
            continue

        # Check if this is the casual dining cell, if so we need to parse it using the chain name csv
        if (row['3-LTR Code'] == 'CSD'):
            csd_value = row['Codes_With_Words'].split(';')
            parse_chain_names(csd_value)
            continue

        # Loop through SIC_Codes cell
        cell = row['SIC_Codes'].split(';')
        for item in cell:
            # Parse Ranges
            if item == '':
                continue
            elif '-' in item:
                code_range = item.split("-")
                for i in range(int(code_range[0]),int(code_range[1])):
                        final_sic_list.append(i)
                        count+=1
            # Parse Individual Values
            else: 
                final_sic_list.append(int(item))
                count+=1
        # Check if there are related words
        word_cell = row['Codes_With_Words']
        row_code_word_list = []
        row_word_list = []
        if not pd.isna(word_cell):
            word_cell = word_cell.split(";")
            for item in word_cell:
                # Parse Ranges
                if item == '':
                    continue
                elif '-' in item:
                    code_range = item.split("-")
                    for i in range(int(code_range[0]),int(code_range[1])):
                            row_code_word_list.append(i)
                            count+=1
                # Parse words
                elif '\"' in item:
                    row_word_list.append(item.replace('\"',''))
                    count+=1
                # Parse Individual Values
                else:
                    row_code_word_list.append(int(item))
                    count+=1
            # Add to with words list
            interim_code_list.append(row_code_word_list)
            interim_word_list.append(row_word_list)

    # Create final data frame
    final_code_and_word_sic_list = pd.DataFrame(
        {'code_list': interim_code_list,
        'word_list': interim_word_list})

    print("SIC Parsing Complete :)")

    return final_sic_list, final_code_and_word_sic_list