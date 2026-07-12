# =============================================================================
# 02_download_distribution_data.R
# -----------------------------------------------------------------------------
# STEP 2 of the pipeline: download the USDA PLANTS county-level distribution
# data for every tree symbol in the canopy, using a HEADLESS Firefox browser.
#
# USDA serves the county distribution as a "Download Distribution Data" button
# on each plant-profile page (there is no bulk endpoint), so we drive a real
# browser and let it save each CSV. One file lands in data/tree_distrib/ per
# symbol; STEP 3 (df_02.R) stacks them into data/tree_distrib.csv.
#
# Input :  data/names_codes.csv   (symbols to fetch; from 01/data_cleaning_script.R)
# Output:  data/tree_distrib/DistributionData*.csv   (one per symbol)
#
# Run from the project root (open WN_trees.Rproj first).
# Requires a local Firefox + geckodriver (RSelenium manages the driver).
# =============================================================================

# -----------------------------------------------------------------------------
# Packages --------------------------------------------------------------------
# -----------------------------------------------------------------------------
library(RSelenium)
library(tidyverse)
library(fs)

# -----------------------------------------------------------------------------
# Config ----------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Firefox needs an ABSOLUTE download directory. Keep it inside the project.
download_dir <- path_abs(path("data", "tree_distrib"))
dir_create(download_dir)

headless    <- TRUE   # <- the whole point of script 2
page_pause  <- 4      # seconds to let each profile page settle
wait_range  <- 6:10   # polite random delay between symbols (seconds)

# -----------------------------------------------------------------------------
# 🚀 Start (headless) Firefox with auto-download prefs ------------------------
# -----------------------------------------------------------------------------
start_selenium <- function(headless = TRUE) {
  prefs <- list(
    "browser.download.folderList"                = 2L,            # use custom dir
    "browser.download.dir"                       = download_dir,
    "browser.helperApps.neverAsk.saveToDisk"     = "text/csv,application/csv,text/plain",
    "browser.download.manager.showWhenStarting"  = FALSE,
    "pdfjs.disabled"                             = TRUE
  )

  rsDriver(
    browser  = "firefox",
    geckover = "latest",
    chromever = NULL,
    phantomver = NULL,
    verbose  = FALSE,
    extraCapabilities = list(
      "moz:firefoxOptions" = list(
        args  = if (headless) list("--headless") else list(),
        prefs = prefs
      )
    )
  )
}

# ⏳ Wait for an element to appear (simple polling) ----------------------------
wait_for_xpath <- function(driver, xpath, timeout = 10) {
  for (i in seq_len(timeout)) {
    el <- driver$findElements(using = "xpath", value = xpath)
    if (length(el) > 0) return(el[[1]])
    Sys.sleep(1)
  }
  stop("Element not found: ", xpath)
}

# 🌳 Download one symbol's distribution CSV -----------------------------------
download_usda_csv <- function(symbol, remDr) {
  tryCatch({
    message("🌱 Starting symbol: ", symbol)
    url <- paste0("https://plants.usda.gov/plant-profile/", symbol)
    remDr$navigate(url)
    Sys.sleep(page_pause)

    # Step 1: open the download modal
    modal_btn <- wait_for_xpath(remDr, "//a[contains(text(), 'Download Distribution Data')]")
    modal_btn$clickElement()
    Sys.sleep(2)

    # Step 2: click the blob download link inside the modal
    blob_xpath <- "/html/body/div/div/div/div/div/div/a"
    blob_link  <- wait_for_xpath(remDr, blob_xpath, timeout = 10)
    blob_link$clickElement()
    Sys.sleep(page_pause)

    message("✅ Download triggered for: ", symbol)
    TRUE
  }, error = function(e) {
    message("⚠️  Skipping ", symbol, " -- ", conditionMessage(e))
    FALSE
  })
}

# -----------------------------------------------------------------------------
# Symbols to pull -------------------------------------------------------------
# -----------------------------------------------------------------------------
joined <- read_csv("data/names_codes.csv") |>
  mutate(symbol = as.character(symbol)) |>
  filter(!is.na(symbol)) |>
  distinct(symbol)

plant_symbols <- joined$symbol
message("📋 ", length(plant_symbols), " symbols queued -> ", download_dir)

# -----------------------------------------------------------------------------
# 🔁 Main run -----------------------------------------------------------------
# -----------------------------------------------------------------------------
rD     <- start_selenium(headless = headless)
remDr  <- rD$client

walk(plant_symbols, function(sym) {
  download_usda_csv(sym, remDr)
  wait_time <- sample(wait_range, 1)
  message("⏳ Waiting ", wait_time, "s before next...")
  Sys.sleep(wait_time)
})

# ✅ Close everything ----------------------------------------------------------
remDr$close()
rD$server$stop()
message("🏁 Done. Files in: ", download_dir)

# -----------------------------------------------------------------------------
# Resume note -----------------------------------------------------------------
# -----------------------------------------------------------------------------
# To resume after an interruption, drop symbols already downloaded before the
# main run, e.g.:
#   done <- dir_ls("data/tree_distrib") |> path_file() |> str_remove("\\.csv$")
#   plant_symbols <- setdiff(plant_symbols, done)
