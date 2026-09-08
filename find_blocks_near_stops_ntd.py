##################################################
## Project:         CIME Availability
## Script name:     find_blocks_near_stops_ntd.py
## Script purpose:  For every census block nationwide, compute the percent of
##                  its area that falls within a 293.33m walk buffer of a
##                  valid transit stop, broken out per transit agency (NTDID).
## Script output:   One shapefile per state (GEOID20, NTDID, Pct_area, ALAND20)
##                     in Availability/blocks_near_stops/ntd/, unique by
##                     (GEOID20, NTDID).
## Author:          Vincent Ader (U-Mich, CIME)
##################################################

import os
import glob
import geopandas as gpd
import pandas as pd

STOPS_PATH = "H:/All Lab/A. Vince Ader/Availability/all_valid_stops_shape.shp"
BLOCKS_DIR = "H:/All Lab/A. Vince Ader/data_processing/shared/blocks"
OUTPUT_DIR = "H:/All Lab/A. Vince Ader/Availability/blocks_near_stops/ntd"

BUFFER_METERS = 293.33
PROJECTED_CRS = "EPSG:5070"  # NAD83 / Conus Albers (metric)

os.makedirs(OUTPUT_DIR, exist_ok=True)


def extract_ntdid(source_file):
    # source_fil looks like ".../availability_finalized/00001/gtfs_1.zip_..."
    # the 5-digit NTDID is the parent folder name, not part of the filename itself.
    return os.path.basename(os.path.dirname(source_file))


# Build the nationwide stop-buffer coverage once, so it isn't redone per state.
# Buffers are dissolved per NTDID (not across agencies) so each coverage piece
# keeps its agency's identity, and each per-agency dissolve is exploded back into
# its individual pieces so the overlay below can use geopandas' spatial index
# (intersecting against one giant multipolygon is much slower than intersecting
# against many small, indexed pieces).
print("Loading valid stops and building buffer coverage...")
stops = gpd.read_file(STOPS_PATH).to_crs(PROJECTED_CRS)
stops["NTDID"] = stops["source_fil"].apply(extract_ntdid)

coverage_pieces = []
for ntdid, group in stops.groupby("NTDID"):
    dissolved_coverage = group.geometry.buffer(BUFFER_METERS).union_all()
    piece = gpd.GeoDataFrame(geometry=[dissolved_coverage], crs=PROJECTED_CRS)
    piece = piece.explode(index_parts=False).reset_index(drop=True)
    piece["NTDID"] = ntdid
    coverage_pieces.append(piece)
coverage = gpd.GeoDataFrame(pd.concat(coverage_pieces, ignore_index=True), crs=PROJECTED_CRS)
print(f"Finished building buffer coverage: {len(coverage)} pieces across {stops['NTDID'].nunique()} agencies.")

block_files = sorted(glob.glob(os.path.join(BLOCKS_DIR, "tl_2024_*_tabblock20.shp")))

for block_path in block_files:
    filename = os.path.basename(block_path)
    state_fips = filename.split("_")[2]

    out_path = os.path.join(OUTPUT_DIR, f"{state_fips}_blocks_near_stops.shp")
    if os.path.exists(out_path):
        print(f"Skipping state {state_fips}, output already exists")
        continue

    print(f"Processing state {state_fips}")

    blocks = gpd.read_file(block_path)
    original_crs = blocks.crs
    blocks = blocks.to_crs(PROJECTED_CRS)
    blocks["full_area"] = blocks.geometry.area

    overlay = gpd.overlay(
        blocks[["GEOID20", "full_area", "geometry"]], coverage, how="intersection"
    )
    overlay["piece_area"] = overlay.geometry.area
    intersection_area = (
        overlay.groupby(["GEOID20", "NTDID"])["piece_area"].sum().reset_index()
    )

    relevant_blocks = intersection_area.merge(
        blocks[["GEOID20", "full_area", "ALAND20", "geometry"]], on="GEOID20", how="left"
    )
    relevant_blocks["Pct_area"] = relevant_blocks["piece_area"] / relevant_blocks["full_area"]
    relevant_blocks = relevant_blocks[relevant_blocks["Pct_area"] > 0].copy()
    relevant_blocks = gpd.GeoDataFrame(relevant_blocks, geometry="geometry", crs=PROJECTED_CRS)
    relevant_blocks = relevant_blocks[["GEOID20", "NTDID", "Pct_area", "ALAND20", "geometry"]]
    relevant_blocks = relevant_blocks.to_crs(original_crs)

    relevant_blocks.to_file(out_path)
    print(f"Finished state {state_fips}: wrote {len(relevant_blocks)} blocks")

print("Finished all states :)")
