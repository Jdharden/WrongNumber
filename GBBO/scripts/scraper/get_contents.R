#!/usr/bin/env Rscript
# =====================================================================
#  GBBO transcript CONTENTS downloader
#  Base page: https://transcripts.foreverdreaming.org/viewtopic.php?t=<ID>
# ---------------------------------------------------------------------
#  Takes a list of topic IDs, opens each viewtopic page in headless
#  Chrome ({chromote}, so it renders like a real browser and clears the
#  bot check), reads the transcript from the first post's
#  <div class="content">, and saves one .txt per episode in ./transcripts/.
#
#  Where the IDs come from (first match wins):
#    1) topics.csv  with a column named  t_id  or  t   (optional 'title' column)
#    2) topics.txt  containing IDs or full viewtopic URLs, one per line
#    3) the TOPIC_IDS vector hard-coded just below
#
#  install.packages(c("chromote","jsonlite","stringr"))   # Chrome must be installed
#  Run:  Rscript get_contents.R
# =====================================================================
suppressPackageStartupMessages({ library(chromote); library(jsonlite); library(stringr); library(readxl) })

# Run from the project folder so relative file names resolve.
PROJECT <- path.expand("data/GBBO")
if (dir.exists(PROJECT)) setwd(PROJECT)
message("Working directory: ", getwd())

BASE   <- "https://transcripts.foreverdreaming.org/viewtopic.php?t="
OUTDIR <- "transcripts"
DELAY  <- 2.5
dir.create(OUTDIR, showWarnings = FALSE)
`%||%` <- function(a,b) if (is.null(a) || length(a)==0) b else a

# paste IDs here if you don't have a topics.csv / topics.txt
TOPIC_IDS <- c(
  "32146", "254745", "254744", "254743", "254742", "254741", "254740", "254739", "254738", "254737",
  "254736", "254735", "254734", "254733", "254732", "254731", "254730", "254729", "254728", "157503",
  "157502", "157501", "157500", "157499", "157498", "157497", "157496", "157495", "157494", "157493",
  "157492", "157491", "157490", "157489", "157488", "157487", "157486", "157485", "157484", "157483",
  "157482", "157481", "157480", "157479", "157478", "157477", "157476", "157475", "157474", "157473",
  "157472", "157471", "157470", "157469", "157468", "157467", "157466", "157465", "157464", "157463",
  "157462", "157461", "157460", "157459", "157458", "157457", "157456", "157455", "157454", "157453",
  "157452", "157451", "157450", "157449", "157448", "157447", "157446", "157445", "157444", "157443",
  "157442", "157441", "157440", "157439", "157438", "157437", "157436", "157435", "157434", "157433",
  "157432", "157431", "157430", "157429", "157428", "157427", "157426", "157425", "157424", "157423",
  "157422", "157421", "157420", "157419", "157418", "157417", "157416", "157415", "157414", "157413",
  "157412", "157411", "157410", "157142", "157141", "157140", "157139", "157138", "157137", "157136",
  "157135", "157134", "157133", "157132", "157131", "157130", "157129", "157128", "157127", "157126",
  "157125", "157124", "157123", "157122", "157121", "157120", "157119", "157118", "157117", "157116",
  "157115", "157114", "157113", "157112", "157111", "157110", "157109", "157108", "157107", "157106",
  "157105", "157104", "157103", "157102", "157101", "157100", "157099", "157098", "157097", "157096",
  "157095", "157094", "157093"
)   # embedded from topics.xlsx (163 topics)

## ---- load the topic IDs (+ titles if available) --------------------
load_ids <- function() {
  # pull every 3+-digit topic id out of any vector/table of cells
  extract_ids <- function(x) {
    x <- as.character(unlist(x, use.names = FALSE))
    ids <- str_match(x, "(?:t=)?(\\d{3,})")[, 2]
    unique(ids[!is.na(ids)])
  }
  # 1) Excel: read with NO header so the first id (e.g. 32146) isn't lost to the
  #    column name, then harvest ids from every cell (works with or without a header row)
  if (file.exists("topics.xlsx")) {
    d   <- suppressMessages(readxl::read_excel("topics.xlsx", col_names = FALSE))
    ids <- str_match(as.character(d[[1]]), "(\\d{3,})")[, 2]          # column A = topic ids
    ttl <- if (ncol(d) >= 2) as.character(d[[2]]) else rep(NA, length(ids))  # column B = titles
    ok  <- !is.na(ids)
    if (any(ok)) {
      message("Loaded ", sum(ok), " ids from topics.xlsx")
      return(data.frame(id = ids[ok], title = ttl[ok], stringsAsFactors = FALSE))
    }
  }
  # 2) CSV: use a named id column if present, else harvest from every cell
  if (file.exists("topics.csv")) {
    d <- read.csv("topics.csv", stringsAsFactors = FALSE, check.names = FALSE)
    idcol <- intersect(c("t_id","t","id","topic","tid"), names(d))[1]
    if (!is.na(idcol)) {
      ids <- str_match(as.character(d[[idcol]]), "(\\d{3,})")[, 2]
      ttl <- if ("title" %in% names(d)) d$title else rep(NA, length(ids))
      ok  <- !is.na(ids)
      return(data.frame(id = ids[ok], title = ttl[ok], stringsAsFactors = FALSE))
    }
    ids <- extract_ids(d)
    if (length(ids)) return(data.frame(id = ids, title = NA, stringsAsFactors = FALSE))
  }
  # 3) plain text: ids or full viewtopic URLs, one per line
  if (file.exists("topics.txt")) {
    ids <- extract_ids(readLines("topics.txt", warn = FALSE))
    if (length(ids)) return(data.frame(id = ids, title = NA, stringsAsFactors = FALSE))
  }
  # 4) hard-coded fallback
  if (length(TOPIC_IDS)) return(data.frame(id = as.character(TOPIC_IDS), title = NA, stringsAsFactors = FALSE))
  stop("No topic IDs found. Provide topics.xlsx / topics.csv / topics.txt, or fill TOPIC_IDS.")
}

topics <- load_ids()
topics <- topics[!is.na(topics$id) & !duplicated(topics$id), , drop = FALSE]
message("Topic IDs to fetch: ", nrow(topics))

## ---- filename from the episode title -------------------------------
fname <- function(title, id) {
  title <- title %||% ""
  m <- str_match(title, "(?i)(\\d{1,2})\\s*x\\s*(\\d{1,2})")
  if (!is.na(m[1,1])) return(sprintf("s%02de%02d.txt", as.integer(m[1,2]), as.integer(m[1,3])))
  slug <- str_replace_all(str_to_lower(title), "[^a-z0-9]+", "-")
  slug <- str_replace_all(slug, "^-|-$", "")
  if (nchar(slug) == 0) return(sprintf("topic_%s.txt", id))
  paste0(str_sub(slug, 1, 60), "_t", id, ".txt")
}

## ---- headless Chrome ----------------------------------------------
b <- ChromoteSession$new()
wait <- function() { tryCatch(b$Page$loadEventFired(timeout_ = 30000), error=function(e) NULL); Sys.sleep(DELAY) }
nav  <- function(url) { tryCatch(b$Page$navigate(url), error=function(e) NULL); wait() }
js   <- function(e) tryCatch(b$Runtime$evaluate(e, returnByValue = TRUE)$result$value, error=function(e) NULL)

done_log <- file.path(OUTDIR, "_done_ids.txt")
done <- if (file.exists(done_log)) readLines(done_log, warn = FALSE) else character(0)

n_ok <- 0
for (i in seq_len(nrow(topics))) {
  id <- topics$id[i]
  if (id %in% done) { message(sprintf("[%d/%d] skip t=%s (done)", i, nrow(topics), id)); next }
  message(sprintf("[%d/%d] t=%s", i, nrow(topics), id))
  nav(paste0(BASE, id))
  # title from the first post heading (falls back to the CSV title, then the page title)
  title <- js("(document.querySelector('.postbody h3')||{}).innerText||''")
  if (is.null(title) || !nzchar(title)) title <- topics$title[i]
  if (is.null(title) || is.na(title) || !nzchar(title)) title <- js("document.title") %||% ""
  title <- gsub("\u00a0", " ", title %||% "")   # titles use non-breaking spaces
  # first post's transcript text; innerText preserves the <br> line breaks
  txt <- js("(document.querySelector('.postbody .content')||document.querySelector('.content')||{}).innerText||''")
  if (is.null(txt) || !nzchar(txt)) { message("    ! empty content (bot check?)"); next }
  fp <- file.path(OUTDIR, fname(title, id))
  writeLines(paste0(sprintf("# %s\n# %s%s\n\n", str_trim(title), BASE, id), txt), fp, useBytes = TRUE)
  cat(id, file = done_log, sep = "\n", append = TRUE)
  n_ok <- n_ok + 1
}
b$close()
message("Saved ", n_ok, " transcripts to ./", OUTDIR, "/  -- upload these into Cowork.")
