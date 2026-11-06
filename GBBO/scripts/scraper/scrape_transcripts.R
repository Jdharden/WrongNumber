#!/usr/bin/env Rscript
# =====================================================================
#  GBBO transcript DOWNLOADER  (headless Chrome, click-through style)
#  Source: transcripts.foreverdreaming.org  (forum f=2837)
# ---------------------------------------------------------------------
#  The forum is bot-protected, so it must be driven by a real browser
#  engine, and each transcript must be reached by CLICKING its link from
#  the forum page (which carries the session cookie + referer that got
#  past the check) -- not by jumping straight to the viewtopic URL.
#
#  This drives your installed Chrome via {chromote} and, for each index
#  page: clicks a topic -> reads <div class="content"> -> history.back()
#  -> next topic. Saves one .txt per episode in ./transcripts/.
#
#  Needs Chrome/Chromium installed.
#  install.packages(c("chromote","jsonlite","stringr"))
#  Run:   Rscript scrape_transcripts.R
# =====================================================================
suppressPackageStartupMessages({ library(chromote); library(jsonlite); library(stringr) })

FORUM_F <- 2837
BASE    <- "https://transcripts.foreverdreaming.org"
OUTDIR  <- "transcripts"
DELAY   <- 2.5
dir.create(OUTDIR, showWarnings = FALSE)

b <- ChromoteSession$new()
wait_load <- function() { tryCatch(b$Page$loadEventFired(timeout_ = 30000), error = function(e) NULL); Sys.sleep(DELAY) }
nav <- function(url) { tryCatch({ b$Page$navigate(url); TRUE }, error = function(e) FALSE); wait_load() }
js  <- function(expr) tryCatch(b$Runtime$evaluate(expr, returnByValue = TRUE)$result$value, error = function(e) NULL)
n_links <- function() { v <- js("document.querySelectorAll('a.topictitle').length"); if (is.null(v)) 0L else as.integer(v) }

fname <- function(title, href) {
  m <- str_match(title, "(?i)(\\d{1,2})\\s*x\\s*(\\d{1,2})")
  if (!is.na(m[1,1])) return(sprintf("s%02de%02d.txt", as.integer(m[1,2]), as.integer(m[1,3])))
  m <- str_match(title, "(?i)series\\s*(\\d{1,2}).*?episode\\s*(\\d{1,2})")
  if (!is.na(m[1,1])) return(sprintf("s%02de%02d.txt", as.integer(m[1,2]), as.integer(m[1,3])))
  tid <- str_match(href %||% "", "t=(\\d+)")[,2]; tid <- if (is.na(tid)) "x" else tid
  slug <- str_replace_all(str_to_lower(title), "[^a-z0-9]+", "-")
  paste0(str_sub(str_replace_all(slug, "^-|-$", ""), 1, 60), "_t", tid, ".txt")
}
`%||%` <- function(a,b) if (is.null(a)) b else a

# discover index pagination offsets from the first rendered page
nav(sprintf("%s/viewforum.php?f=%d&start=0", BASE, FORUM_F))
if (n_links() == 0) { b$close(); stop("Index didn't render any topics - is Chrome installed / did the bot check pass?") }
offs <- js("JSON.stringify([...document.querySelectorAll('a')].map(a=>a.getAttribute('href')).filter(h=>h&&h.includes('viewforum.php')&&h.includes('start=')))")
offsets <- sort(unique(c(0L, as.integer(str_match(fromJSON(offs %||% "[]"), "start=(\\d+)")[,2]))))
offsets <- offsets[!is.na(offsets)]
message("Index pages at start = ", paste(offsets, collapse=", "))

n_ok <- 0
for (off in offsets) {
  idx <- sprintf("%s/viewforum.php?f=%d&start=%d", BASE, FORUM_F, off)
  nav(idx)
  meta <- fromJSON(js("JSON.stringify([...document.querySelectorAll('a.topictitle')].map(a=>({h:a.getAttribute('href'),t:a.textContent.trim()})))") %||% "[]")
  if (!length(meta) || !nrow(meta)) next
  message("== index start=", off, "  (", nrow(meta), " topics) ==")
  for (k in seq_len(nrow(meta))) {
    title <- meta$t[k]; href <- meta$h[k]
    fp <- file.path(OUTDIR, fname(title, href))
    if (file.exists(fp)) { message(sprintf("  [%d] skip %s", k, basename(fp))); next }
    message(sprintf("  [%d] %s", k, title))
    # click the k-th topic link (force same-tab), which carries session+referer
    clicked <- js(sprintf("var L=document.querySelectorAll('a.topictitle'); if(L[%d]){L[%d].target='_self'; L[%d].click(); true} else {false}", k-1, k-1, k-1))
    if (isTRUE(clicked)) wait_load() else { message("    ! link missing"); next }
    txt <- js("(document.querySelector('.content')||{}).innerText||''")
    if (!is.null(txt) && nzchar(txt)) {
      writeLines(paste0(sprintf("# %s\n# %s\n\n", title, href), txt), fp, useBytes = TRUE); n_ok <- n_ok + 1
    } else message("    ! empty content")
    # navigate back to the index and make sure it re-rendered
    js("window.history.back()"); wait_load()
    if (n_links() == 0) nav(idx)
  }
}
b$close()
message("Saved ", n_ok, " transcript files to ./", OUTDIR, "/  -- upload these into Cowork.")
