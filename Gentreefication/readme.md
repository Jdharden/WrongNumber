# The Trees in Your Neighborhood

An analysis of street-tree inventories from cities across the United States, measured against USDA plant-distribution data to ask a simple question: **how much of a city's canopy actually looks like the landscape around it?**

## Overview

City street-tree inventories (from the [eLife 63-city street-tree database](https://elifesciences.org/)) are joined to USDA PLANTS distribution records so each planted species can be traced to where it grows in the wild across the country. This makes it possible to compare a city's planted canopy against the native flora of its own region.

## Data sources

- **City street trees** — cleaned inventories for 63 U.S. cities (`data/all_trees.csv`, ~1.2 GB), from the eLife street-tree database.
- **USDA PLANTS** — species codes (`plantlst.txt`), per-species characteristics, and county-level distribution data scraped from [plants.usda.gov](https://plants.usda.gov).
- **Geography** — U.S. county boundaries (Census `cb_2020_us_county_500k`) and NOAA CONUS climate divisions, used to map county distributions to regions.

## Repository structure

```
WN_trees/
├── data/
│   ├── all_trees.csv              # combined 63-city street-tree inventory
│   ├── tree_distrib.csv           # USDA county-level distribution (long)
│   ├── distrib_climate.csv        # distribution joined to climate regions
│   ├── tree_characteristics*.csv  # USDA species traits
│   ├── names_codes.csv            # scientific/common name <-> USDA symbol
│   ├── tree_usda_ids.csv          # USDA symbol/rank lookup
│   ├── tree_distrib/              # raw per-species distribution downloads
│   └── shapefiles/                # county + climate-division boundaries
├── scripts/
│   ├── distrib_scraper.R          # scrape USDA distribution CSVs (RSelenium)
│   ├── characteristics_pull.R     # pull USDA species characteristics
│   ├── data_cleaning_script.R     # combine + clean city inventories
│   ├── df_01.R / df_02.R          # dataset assembly helpers
│   └── mapping_distribution.R     # join distribution to regions; mapping
├── regional_analysis/             # analysis outputs (charts, summaries, scripts)
└── markdown/                      # R Markdown writeups
```

## Analysis outputs

The `regional_analysis/` folder contains the current results:

- `local_native_chart.png` + `LOCAL_CANOPY_FINDINGS.md` — how much of each city's canopy is native to its own area (main finding).
- `fig1_regional_signature.png`, `fig2_exotic_share.png` + `FINDINGS.md` — which region of the country each city's trees most resemble.
- `local_native.py`, `analyze.py` — reproducible analysis scripts (Python).
- `*.csv` — the underlying share tables.

## Reproducing

R scripts (data assembly) use `tidyverse`, `sf`, `janitor`, `fuzzyjoin`, `rvest`, and `RSelenium`. The analysis scripts in `regional_analysis/` run on Python 3 with `matplotlib`:

```bash
python3 regional_analysis/local_native.py   # native-vs-introduced shares + USDA cross-check
python3 regional_analysis/local_chart.py     # headline chart
```

## Author

Harden, D. John
