# =============================================================================
# canopy_in_federal_database.R
# -----------------------------------------------------------------------------
# Question:  Which trees in a city's canopy are recorded in the federal (USDA
#            PLANTS) distribution database for that city's county?
#
# This script CLEANS, JOINS and ANALYZES the already-collected data that lives
# in `data/`. It does not scrape or hit the USDA API -- those collection steps
# live in their own scripts (see README):
#     data_cleaning_script.R  -> data/names_codes.csv
#     distrib_scraper.R       -> data/tree_distrib/  -> data/tree_distrib.csv
#     characteristics_pull.R  -> data/tree_characteristics.csv
#
# Run from the project root (open WN_trees.Rproj first) so the relative paths
# below resolve.
#
# Outputs:
#     data/mapping_files/canopy_federal_match.csv   (species-level match table)
#     data/mapping_files/canopy_federal_summary.csv (one row per city)
# =============================================================================

# -----------------------------------------------------------------------------
# Packages --------------------------------------------------------------------
# -----------------------------------------------------------------------------
library(tidyverse)
library(janitor)

# -----------------------------------------------------------------------------
# Config ----------------------------------------------------------------------
# -----------------------------------------------------------------------------
data_dir <- "data"
out_dir  <- file.path(data_dir, "mapping_files")

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Small helper: lower-case + trim, used everywhere we key on names -------------
tidy_name <- function(x) {
  x |>
    as.character() |>
    tolower() |>
    trimws(which = "both")
}

# -----------------------------------------------------------------------------
# Load Data -------------------------------------------------------------------
# -----------------------------------------------------------------------------

# City canopy inventories (65 cities, already stacked) ------------------------
all_trees_raw <- read_csv(
  file.path(data_dir, "all_trees.csv"),
  col_types = cols(.default = col_character())
)

# common_name -> USDA symbol (join_key) crosswalk -----------------------------
tree_name_crosswalk <- read_csv(file.path(data_dir, "keys/tree_name_crosswalk.csv")) |>
  mutate(common_name = tidy_name(common_name)) |>
  distinct(common_name, .keep_all = TRUE)

# city + state -> county (GEOID_2) --------------------------------------------
county_places <- read_csv(file.path(data_dir, "county_places.csv")) |>
  select(city = NAME, NAMELSAD, state = STATE_NAME, COUNTYNS, GEOID_2) |>
  distinct(city, state, .keep_all = TRUE)

# Federal (USDA) county-level distribution ------------------------------------
tree_distrib <- read_csv(
  file.path(data_dir, "tree_distrib.csv"),
  col_types = cols(.default = col_character())
)

# USDA characteristics (optional enrichment) ----------------------------------
usda_tree_char <- read_csv(file.path(data_dir, "tree_characteristics.csv")) |>
  mutate(common_name_x = tidy_name(common_name_x)) |>
  select(symbol, common_name = common_name_x, scientific_name_with_author, family,
         growth_rate, height_mature_feet, lifespan, shape_and_orientation,
         drought_tolerance, fire_tolerance) |>
  distinct(symbol, .keep_all = TRUE)

# -----------------------------------------------------------------------------
# Clean + Build the City Canopy Table -----------------------------------------
# -----------------------------------------------------------------------------
# Attach the USDA symbol (join_key) and the county FIP (GEOID_2) to every tree,
# then attach characteristics. This mirrors `all_trees_02` from the originals.

canopy <- all_trees_raw |>
  mutate(common_name = tidy_name(common_name)) |>
  left_join(tree_name_crosswalk, by = "common_name") |>
  filter(!is.na(join_key)) |>
  left_join(county_places, by = c("city", "state")) |>
  mutate(
    # District of Columbia is coded as a place with no county; force the FIP.
    GEOID_2 = if_else(state == "District of Columbia", "11001", GEOID_2)
  ) |>
  select(common_name, scientific_name, city, state,
         latitude_coordinate, longitude_coordinate, GEOID_2, join_key) |>
  left_join(usda_tree_char, by = c("join_key" = "symbol"))

# -----------------------------------------------------------------------------
# Build the Federal Distribution Lookup ---------------------------------------
# -----------------------------------------------------------------------------
# One row per (county, species) that USDA records as present. County-level rows
# only (state-only rows have no county FIP and cannot match a 5-digit GEOID).

federal_distrib <- tree_distrib |>
  clean_names() |>
  filter(!is.na(county_key), str_length(county_key) == 5) |>
  distinct(county_key, symbol) |>
  mutate(in_usda = TRUE)

# -----------------------------------------------------------------------------
# Core Analysis: Canopy Species vs the Federal County Database -----------------
# -----------------------------------------------------------------------------
# For each city, take its distinct canopy species and flag whether USDA records
# that species in the city's county. `in_usda == FALSE` = present in the city
# but NOT in the federal distribution for that county.

canopy_species <- canopy |>
  distinct(city, state, GEOID_2, join_key, common_name)

canopy_federal_match <- canopy_species |>
  left_join(
    federal_distrib,
    by = c("GEOID_2" = "county_key", "join_key" = "symbol")
  ) |>
  mutate(in_usda = coalesce(in_usda, FALSE)) |>
  arrange(city, common_name)

# -----------------------------------------------------------------------------
# City-Level Summary Table ----------------------------------------------------
# -----------------------------------------------------------------------------
# Two complementary views of the same question:
#   species_* : share of DISTINCT canopy species that are in the federal db
#   trees_*   : share of INDIVIDUAL trees (canopy weighted) that are in the db

trees_view <- canopy |>
  distinct(city, state, GEOID_2, join_key) |>          # species present per city
  select(city, state, GEOID_2, join_key)

canopy_tree_match <- canopy |>
  left_join(
    federal_distrib,
    by = c("GEOID_2" = "county_key", "join_key" = "symbol")
  ) |>
  mutate(in_usda = coalesce(in_usda, FALSE))

species_summary <- canopy_federal_match |>
  group_by(city, state, GEOID_2) |>
  summarise(
    n_species         = n(),
    n_species_in_usda = sum(in_usda),
    species_share     = round(n_species_in_usda / n_species * 100, 1),
    .groups = "drop"
  )

trees_summary <- canopy_tree_match |>
  group_by(city, state) |>
  summarise(
    n_trees         = n(),
    n_trees_in_usda = sum(in_usda),
    trees_share     = round(n_trees_in_usda / n_trees * 100, 1),
    .groups = "drop"
  )

canopy_federal_summary <- species_summary |>
  left_join(trees_summary, by = c("city", "state")) |>
  arrange(desc(species_share))

# -----------------------------------------------------------------------------
# Single-City Drill-Down Function ---------------------------------------------
# -----------------------------------------------------------------------------
# canopy_in_federal_db("San Francisco") -> the species table for that city,
# with an `in_usda` flag and the printed species / tree shares.

canopy_in_federal_db <- function(city_name) {
  city_species <- canopy_federal_match |>
    filter(city == city_name)

  if (nrow(city_species) == 0) {
    warning("No canopy rows found for city: ", city_name,
            " -- check spelling against unique(canopy$city).")
    return(invisible(NULL))
  }

  shares <- canopy_federal_summary |>
    filter(city == city_name)

  message(city_name, ": ",
          shares$n_species_in_usda, "/", shares$n_species,
          " species (", shares$species_share, "%) and ",
          shares$n_trees_in_usda, "/", shares$n_trees,
          " trees (", shares$trees_share, "%) are in the USDA county database.")

  city_species
}

# -----------------------------------------------------------------------------
# Write Outputs ---------------------------------------------------------------
# -----------------------------------------------------------------------------
write_csv(canopy_federal_match,   file.path(out_dir, "canopy_federal_match.csv"))
write_csv(canopy_federal_summary, file.path(out_dir, "canopy_federal_summary.csv"))

# -----------------------------------------------------------------------------
# Example Usage ---------------------------------------------------------------
# -----------------------------------------------------------------------------
# print(canopy_federal_summary)
# sf <- canopy_in_federal_db("San Francisco")
# sf |> filter(!in_usda)          # species in SF's canopy but not USDA's county db
# canopy_in_federal_db("Grand Rapids")
