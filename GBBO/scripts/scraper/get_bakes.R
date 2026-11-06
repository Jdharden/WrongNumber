#!/usr/bin/env Rscript
# =====================================================================
#  GBBO baker-attributed bakes scraper  (series 10-16)
#  Source: Wikipedia per-episode challenge tables
# ---------------------------------------------------------------------
#  Series 1-9 already exist in the {bakeoff}/TidyTuesday data. Series
#  10-16 only live in Wikipedia's per-episode tables (Baker | Signature |
#  Technical | Showstopper | Result). Wikipedia isn't bot-protected, so
#  plain rvest works -- no headless Chrome needed.
#
#  Output: bakes_s10_16.csv  (series, episode, baker, signature,
#          technical_rank, showstopper, result_raw, result)
#  Upload that CSV into Cowork and I'll extend the ingredient / pairing /
#  trio / winner analysis to cover series 10-16.
#
#  install.packages(c("rvest","dplyr","stringr","purrr","readr"))
#  Run:  Rscript get_bakes.R
# =====================================================================
suppressPackageStartupMessages({ library(rvest); library(dplyr); library(stringr); library(purrr); library(readr) })

setwd(path.expand("~/Documents/Claude/Projects/GBBO"))
SERIES <- 10:16
UA <- "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) research-scraper"

norm_result <- function(x) {
  x <- str_to_lower(str_trim(as.character(x)))
  x[is.na(x)] <- ""
  dplyr::case_when(
    str_detect(x, "star baker")            ~ "STAR BAKER",
    str_detect(x, "eliminat|withdrew|out") ~ "OUT",
    str_detect(x, "winner")                ~ "WINNER",
    str_detect(x, "runner")                ~ "Runner-up",
    TRUE                                    ~ "IN")
}
`%||%` <- function(a,b) if (is.null(a) || length(a)==0 || is.na(a)) b else a

scrape_series <- function(n) {
  url <- sprintf("https://en.wikipedia.org/wiki/The_Great_British_Bake_Off_(series_%d)", n)
  message("Series ", n, ": ", url)
  doc <- tryCatch(read_html(httr::GET(url, httr::user_agent(UA))), error = function(e) NULL)
  if (is.null(doc)) { message("  ! failed to load"); return(NULL) }
  tabs <- html_elements(doc, "table.wikitable")
  ep <- 0; out <- list()
  for (tb in tabs) {
    df <- tryCatch(html_table(tb, fill = TRUE), error = function(e) NULL)
    if (is.null(df) || !nrow(df)) next
    nm <- names(df)
    # an episode bake table has Signature AND Showstopper columns
    if (!(any(str_detect(nm, regex("signature", TRUE))) &&
          any(str_detect(nm, regex("showstopper", TRUE))))) next
    ep <- ep + 1
    pick <- function(pat) { i <- which(str_detect(nm, regex(pat, TRUE)))[1]; if (is.na(i)) NA else df[[i]] }
    baker <- pick("^baker|contestant|^name")
    if (all(is.na(baker))) baker <- df[[1]]
    out[[length(out)+1]] <- tibble(
      series = n, episode = ep,
      baker  = str_trim(as.character(baker)),
      signature = as.character(pick("signature")),
      technical_rank = suppressWarnings(as.integer(str_extract(as.character(pick("technical")), "\\d+"))),
      showstopper = as.character(pick("showstopper")),
      result_raw = as.character(pick("result"))
    )
  }
  if (!length(out)) { message("  ! no bake tables found (page layout may differ)"); return(NULL) }
  bind_rows(out) |>
    filter(!is.na(baker), baker != "", !str_detect(baker, regex("^baker$", TRUE)))
}

all <- map(SERIES, scrape_series) |> compact() |> bind_rows()
all <- all |>
  mutate(across(c(signature, showstopper, result_raw), ~ str_squish(str_replace_all(.x, "\\[[^]]*\\]", ""))),
         result = norm_result(result_raw))

write_csv(all, "bakes_s10_16.csv")
message("Saved bakes_s10_16.csv: ", nrow(all), " rows across series ",
        paste(sort(unique(all$series)), collapse = ", "))
print(all |> count(series, name = "bakes"))
message("Upload bakes_s10_16.csv into Cowork.")
