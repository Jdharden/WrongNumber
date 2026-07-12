# Methodology

How the project goes from raw city tree inventories to the question at its
center: **which trees in a city's canopy are recorded in the federal (USDA
PLANTS) distribution database for that city's county?**

---

## 1. Assemble and code the city canopy

*Script: `data_cleaning_script.R`*

The 63 city street-tree inventories (Dryad) are stacked into one table, reading
every column as character so that inconsistently typed city files don't silently
coerce. The USDA master plant list (`plantlst.txt`) is loaded from
`plants.sc.egov.usda.gov` and reduced to distinct common names.

**Why this step is fragile.** Common names are not unique or standardized: "cedar,"
"locust," and "ash" each cover many species, and a single string edit
(`max_dist = 1`) can match the wrong taxon. This is the largest source of
matching error in the project, and it is inherent to keying horticultural common
names against a botanical database.

## 2. Resolve USDA IDs and characteristics

*Script: `characteristics_pull.R`*

For each symbol, the USDA `PlantProfile` API returns the accepted plant ID,
symbol, and taxonomic rank (`tree_usda_ids.csv`). Symbols are frequently
**synonyms** that resolve to a different accepted ID, so this step is what lets a
city's name map to the taxon USDA actually tracks. A handful of manual symbol
corrections are recorded (commented) in the script for cases the automated
resolution got wrong.

## 3. Download the county distribution (headless)

*Script: `02_download_distribution_data.R` (headless rewrite of `distrib_scraper.R`)*

USDA exposes county-level distribution only as a per-species "Download
Distribution Data" button on each plant-profile page — there is no bulk
download. Script 2 drives a **headless Firefox** browser (via `RSelenium`) with
auto-download preferences set, visits each symbol's profile, and saves one CSV
per species into `data/tree_distrib/`. Polite randomized delays separate
requests, and the run can be resumed by subtracting already-downloaded symbols.

## 4. Build the geographic crosswalks

## About the USDA PLANTS database (important caveats)

The federal database is the reference point for this whole analysis, so its
nature governs how the results should be read.

**Distribution data is presence-only, not an inventory.** A county record means
a documented occurrence exists (largely from herbaria, floristic surveys, and
partners such as BONAP). **Absence of a species from a county does not mean it
can't or doesn't grow there** — only that no documented record was compiled.
Survey effort is uneven across the country, so gaps reflect data coverage as
much as biology. An `in_usda == FALSE` result should be read as "not in the
federal *record* for that county," never as "shouldn't be there."

**Nativity comes from a different source.** The `native` flag in the Dryad
inventories was assigned by the original authors from BONAP, not from USDA
PLANTS; the two sources can disagree, so nativity and federal-record membership
are independent signals.

### How these caveats bound the interpretation

The headline metric is best framed as *the share of a city's planted canopy that
overlaps the documented wild flora of its county*. A low share is as likely to
reflect a heavily ornamental, non-native urban forest — or thin USDA survey
coverage — as any ecological mismatch. The results are a lens on that overlap,
not a scorecard of whether a city planted the "right" trees.

---

## Known limitations (summary)

- Fuzzy common-name matching (`max_dist = 1`) trades precision for recall and is
  the main matching-error source.
- County-level federal rows only; state-only rows are dropped.
- Places that don't resolve to a county in `county_places.csv` (mostly small
  suburbs) carry a missing `GEOID_2` and count as unmatched.
- Presence-only distribution: `FALSE` = not in the federal *record*, not "absent."
- Cultivated ornamentals are systematically underrepresented in the federal data.

See **README.md** for data sources and full citations.
