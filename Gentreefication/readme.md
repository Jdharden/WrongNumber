# The Trees in Your Neighborhood

Matching city street-tree inventories against the federal USDA PLANTS
distribution database to answer a single question:

> **Which trees in a city's canopy are actually recorded in the federal (USDA)
> distribution database for that city's county?**

City foresters plant what grows well locally, but the USDA PLANTS database
records which species are documented as occurring in each U.S. county. Comparing
the two shows, city by city, how much of the planted canopy is "on the map"
federally — and which species are growing in a place the federal record doesn't
list for that county.

---

## Data

All inputs live under `data/`.

| File / folder | What it is | Produced by |
|---|---|---|
| `data/archive/*.csv` | 65 raw city street-tree inventories (Dryad) | source data |
| `data/all_trees.csv` | The 65 inventories stacked into one table | source data |
| `data/keys/tree_name_crosswalk.csv` | `common_name` → USDA `join_key` (symbol) | `data_cleaning_script.R` |
| `data/names_codes.csv` | Fuzzy match of city names to USDA codes | `data_cleaning_script.R` |
| `data/tree_distrib/` | Per-species USDA county distribution downloads | `distrib_scraper.R` |
| `data/tree_distrib.csv` | Those downloads stacked (`symbol`, `county_key`, …) | `df_02.R` |
| `data/tree_characteristics.csv` | USDA plant characteristics per symbol | `characteristics_pull.R` |
| `data/county_places.csv` | Place (city) → county (`GEOID_2`) crosswalk | Census |
| `data/shapefiles/` | County, state and climate-zone geometries | Census / NOAA |

`county_key` and `GEOID_2` are both 5-digit county FIPS codes
(`STATEFP` + `COUNTYFP`), which is what lets the canopy join to the federal
distribution.

---

## Pipeline

The repository is organized as a collect → clean → join → analyze flow.

**1. Collect** (run occasionally; hits USDA / the web)

- `data_cleaning_script.R` — stacks the city inventories and fuzzy-matches city
  tree names to USDA plant codes.
- `distrib_scraper.R` — Selenium scraper that downloads each species' county
  distribution from `plants.usda.gov`.
- `characteristics_pull.R` — pulls plant IDs and characteristics from the USDA
  API.

**2. Clean · Join · Analyze** (the main deliverable)

- **`scripts/canopy_in_federal_database.R`** — the single, consolidated,
  reproducible script. It reads the saved intermediate CSVs above and answers
  the research question end to end. It does **not** scrape or call the API.

Supporting/legacy scripts (`df_01.R`, `df_02.R`, `mapping_distribution.R`,
`share_of_canopy.R`) contain the original exploratory versions of these steps
and the choropleth mapping code.

---

## Running the analysis

Open `WN_trees.Rproj` in RStudio (so the working directory is the project root),
then:

```r
source("scripts/canopy_in_federal_database.R")
```

Requirements: R (≥ 4.1, for the native `|>` pipe), `tidyverse`, and `janitor`.

### What it produces

Two files written to `data/mapping_files/`:

- **`canopy_federal_match.csv`** — one row per city × canopy species, with an
  `in_usda` flag (`TRUE` = USDA records that species in the city's county).
- **`canopy_federal_summary.csv`** — one row per city, with both:
  - `species_share` — % of *distinct canopy species* in the federal county db, and
  - `trees_share` — % of *individual trees* (canopy-weighted) in the federal county db.

### Drilling into one city

```r
sf <- canopy_in_federal_db("San Francisco")
#> San Francisco: 8/113 species (7.1%) and … trees are in the USDA county database.

sf |> filter(!in_usda)   # species growing in SF's canopy but not in USDA's county record
```

Pass any city name present in `unique(canopy$city)`.

---

## Notes & caveats

- **Two shares, on purpose.** `species_share` treats every species equally;
  `trees_share` weights by how many trees of each species a city actually has.
  They answer slightly different versions of "how much of the canopy is in the
  federal record."
- **State-only USDA rows are dropped.** Distribution rows without a county FIP
  can't match a 5-digit county, so only county-level federal records are used.
- **Unmatched places.** A small number of trees sit in places that don't resolve
  to a county in `county_places.csv` (mostly tiny suburbs); they carry a missing
  `GEOID_2` and are treated as not matched. The District of Columbia is coded
  explicitly to county `11001`.
- A 0% share for a city means none of its matched canopy species are recorded by
  USDA for that county — that is a real feature of the data, not a join error.

---

*Author: D. John Harden*
