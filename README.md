# NaNDA Syntax — CIME Transit Adjacency & Availability Scripts

R and Python scripts developed at the University of Michigan's Center for Inclusive and Mobility Excellence (CIME) to measure two transit-related metrics from GTFS, census, and destination data: **adjacency** (how many destinations are reachable from each census block under different traveler profiles) and **availability** (how much of each census block's area is within walking distance of transit service, and how frequently that service runs).

## Repository Contents

| Workflow | Script | Role |
|---|---|---|
| Adjacency | `adjacency_preprocessing.R` | Builds origins (census block centroids) and fetches the street network for a region |
| Adjacency | `destination_proessing.py` | Filters a business-location dataset into candidate destinations |
| Adjacency | `naisc_code_parsing.py` | Helper module imported by `destination_proessing.py`; not run directly |
| Adjacency | `adjacency.R` | Runs r5r accessibility analysis across traveler profiles and travel modes |
| Adjacency | `adjacency_postprocessing.R` | Joins results to census geography, produces maps and a combined table |
| Availability | `stop_availability.R` | Computes average arrivals-per-hour per GTFS stop, per transit agency |
| Availability | `find_blocks_near_stops_ntd.py` | Computes % of each census block's area within a walk buffer of transit stops, broken out by transit agency (NTDID) |

## Setup & Dependencies

**Java:** A JDK is required to run r5r (tested against JDK 21). Set `JAVA_HOME` if r5r cannot find your installation.

**R packages:**
```r
install.packages(c("sf", "data.table", "ggplot2", "tidytransit", "dplyr",
                    "lubridate", "stringr", "hms", "viridis", "gtfstools"))
# osmextract and r5r have their own install instructions — see their project pages
install.packages("osmextract")
# r5r: https://ipeagit.github.io/r5r/
```
`adjacency.R` allocates 18 GB of Java heap (`options(java.parameters = "-Xmx18G")`) before loading r5r — make sure your machine has enough RAM, or lower this value.

**Python packages:**
```bash
pip install pandas numpy geopandas
```

## Data & Path Requirements

These scripts were written for a specific lab file layout and **will not run as-is** — every script contains hardcoded absolute paths (some already marked `<UPDATE>` in the code as a reminder) that need to be replaced with your own paths before running. At minimum you will need to supply:

- **GTFS feeds** (`.zip`) for the region/agencies you're analyzing.
- **Census block shapefiles** (TIGER/Line `tabblock20`, or your own boundary file) for the region.
- **A street network** (`.osm.pbf`) — `adjacency_preprocessing.R` will attempt to auto-match and can download one via `osmextract`.
- **A elevation file** (`.tif`) — `adjacency.R` will use this to vary walking speed by slope.
- **A business-location dataset** for destinations. `destination_proessing.py` was written against a paid, proprietary dataset (Data Axle) that is *not* included in this repository and must be licensed separately (or swapped for your own destination source).
- **SIC/NAICS code and keyword filter lists**, and a **parks/destinations CSV**, both referenced from lab-internal paths in `naisc_code_parsing.py` and `destination_proessing.py` — not included; substitute your own filter and destination inputs.
- **A consolidated stop shapefile** (`all_valid_stops_shape.shp`) with columns for stop location and a `source_fil` path identifying which agency each stop came from. This is the input to `find_blocks_near_stops_ntd.py` and is built by consolidating the per-agency outputs of `stop_availability.R` — that consolidation step is **not included in this repository**.

## Workflow 1: Adjacency

Computes the number of reachable destinations from each census block centroid, under three traveler profiles (design/typical, older adult, disability) and multiple travel modes/cutoffs.

**Run order:**

1. **`adjacency_preprocessing.R`**
   - *Inputs:* GTFS `.zip` files for the region (in a `data/` folder), a state census block shapefile.
   - *Outputs:* `census_blocks_selection_shapefile.shp`, `census_block_shapefile.shp` (dissolved boundary), `census_blocks.csv` (GEOID list), `origins_table.csv` (block centroids as r5r origins), and a matched `.osm.pbf` street network.

2. **`destination_proessing.py`** (depends on `naisc_code_parsing.py`)
   - *Inputs:* `census_blocks.csv` from step 1, the Data Axle business-location dataset, SIC/NAICS filter lists, a parks destinations CSV.
   - *Outputs:* `filtered_destinations.csv` — candidate destinations in r5r's expected format.

3. **`adjacency.R`**
   - *Inputs (all in the same working directory):* GTFS `.zip` files, elevation `.tif` file, `origins_table.csv`, `filtered_destinations.csv`, `census_block_shapefile.shp`, `.osm.pbf` network.
   - *Outputs:* one CSV per traveler profile × mode combination (6 by default): `<profile>_transit_access_60.csv` and `<profile>_walk_access.csv` for `design`, `older`, and `disability`.

4. **`adjacency_postprocessing.R`**
   - *Inputs:* the 6 CSVs from step 3, `census_blocks.csv`, a state census block shapefile.
   - *Outputs:* 9 PNG maps (one per profile × cutoff/mode combination) and a combined `accessibility.csv` joining all profiles by GEOID.

## Workflow 2: Availability

Computes how much of each census block's area is within comfortable walking distance (293.33 m) of a transit stop for older adults with a disability, per transit agency, and how frequently that stop is served.

**Run order:**

1. **`stop_availability.R`**
   - *Inputs:* a root folder containing one subfolder per transit agency, each with one or more GTFS `.zip` files.
   - *Outputs:* one `<gtfs_filename>_stops_average_aph.csv` per GTFS zip (per agency), with average arrivals-per-hour, start/end service time, and stop coordinates.

2. *(external, not included)* — the per-agency CSVs from step 1 are consolidated into a single `all_valid_stops_shape.shp`, tagging each stop with its source agency file path.

3. **`find_blocks_near_stops_ntd.py`**
   - *Inputs:* `all_valid_stops_shape.shp`, a nationwide set of census block shapefiles (`tl_2024_<state>_tabblock20.shp`).
   - *Outputs:* one shapefile per state, unique by `(GEOID20, NTDID)`, with the percent of that block's area within the walk buffer of that agency's stops.

## Workflow 3: Aggregation to tract level

Details explaining the aggregation to tract level is maintained in the data dictionaries of the main project. In general, the blocks near stop data set should be combined with the adjacency dataset to identify what percent area coverage exists within the block.
These values are used to weight the individual adjacency values for each block when aggregating to the tract level.

Aggregation of availability data to the tract is performed by buffering census tracts and identifying transit stops within those buffers. This is also detailed in the data dictionary.

## AI Usage disclosure

Claude was used to help develop this README.md file through analysis of scripts and comments.

## License

This code is released under the [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) license. You are free to use, adapt, and redistribute it, provided you give appropriate credit.

## Citation

[CITATION PENDING — authors, year, dataset/code title, and DOI/URL to be added once finalized.]

## Author

Vincent Ader, Center for Inclusive and Mobility Environments (CIME), University of Michigan.
