# The Great British Analysis

Which flavors actually win on *The Great British Bake Off*? This project scrapes episode transcripts and bake lists, tags every bake with its flavor ingredients, and scores each ingredient (and each pair and trio of ingredients) on two things:

- **Results:** how often bakers who used it were named Star Baker compared with how often they were sent home.
- **Reception:** how warmly the judges talked about it, based on praise and criticism words in the transcripts.

Plotting one against the other shows which flavours the judges love but that don't win, and which ones quietly do well.

Charts use the Wrong Number house style (`scripts/wn_theme.R`).

## Project layout

```
GBBO/
├── GBBO.Rproj
├── data/
│   ├── transcripts/                              # one .txt per episode (s01e01.txt …), plus _done_ids.txt
│   ├── gbbo_ingredient_scores_withinchallenge.csv # one row per ingredient
│   ├── gbbo_pairing_scores_withinchallenge.csv    # one row per ingredient pair
│   ├── gbbo_trio_scores_withinchallenge.csv       # one row per ingredient trio
│   └── gbbo_flavour_sentiment.csv                 # judge praise/criticism counts per ingredient
└── scripts/
    ├── scraper/                   # data collection and scoring pipeline
    │   ├── scrape_transcripts.R   # transcript downloader (clicks through the forum index)
    │   ├── get_contents.R         # transcript downloader (from a list of topic IDs)
    │   ├── get_bakes.R            # series 10–16 bakes from Wikipedia
    │   ├── 00_gazetteer.R         # ingredient dictionary (regex patterns by flavour family)
    │   ├── 01_sentiment.R         # judge sentiment per ingredient
    │   ├── 02_scores.R            # single / pair / trio scoring
    │   ├── 03_llm_optional.R      # optional LLM pass to catch ingredients the regex misses
    │   ├── gbbo_taste_profiles.csv
    │   └── test.R                 # pairing heatmap
    └── analysis/
        ├── main_analysis.R        # reception-vs-results scatter for all pairs
        └── function_search.R      # gbbo_search(): the same chart for one ingredient
```

## Requirements

The transcript scrapers drive a headless Chrome, so Google Chrome or Chromium needs to be installed. The optional LLM step needs an `ANTHROPIC_API_KEY` environment variable.

## Quick start: the charts

The scored CSVs in `data/` are already built, so you can go straight to the charts. Open `GBBO.Rproj` so the working directory is the project root, then:

```r
source("scripts/analysis/main_analysis.R")   # every pair seen in 3+ baker-episodes
```

To look at a single ingredient, use `gbbo_search()` from `function_search.R`:

```r
source("scripts/analysis/function_search.R")

gbbo_search("single", "Chocolate")   # the ingredient on its own
gbbo_search("pair",   "Orange")      # every pair that includes orange
gbbo_search("trio",   "Lemon")       # every trio that includes lemon
```

It returns a ggplot object, so you can add `labs()`, labels and so on afterwards.

## Rebuilding the data

1. **Transcripts.** Run `scrape_transcripts.R` (walks the forum index) or `get_contents.R` (works from a list of topic IDs). Both save one `.txt` per episode to `transcripts/`. `_done_ids.txt` records topics already fetched, so a rerun skips them.
2. **Bakes.** Series 1–9 come from the `{bakeoff}` / TidyTuesday data. `get_bakes.R` scrapes series 10–16 from Wikipedia's episode tables into `bakes_s10_16.csv`. Combine them into `challenges_1_14.csv` (columns `series, episode, baker, signature, technical, showstopper, result`).
3. **Ingredients.** `00_gazetteer.R` defines the ingredient dictionary. Edit the patterns there to add or merge ingredients. `03_llm_optional.R` can catch foreign or one-off names the regex misses (for example, Amarena → cherry).
4. **Sentiment.** `01_sentiment.R` keeps only transcript lines that give a verdict and scores each ingredient as (praise − criticism) / total. Reassurances like "it won't curdle" are removed before scoring.
5. **Scores.** `02_scores.R` writes the ingredient, pairing and trio CSVs.

## How the scoring works

- **Within-challenge pairing.** Two ingredients count as a pair only if they appear in the *same* bake (Signature, Technical or Showstopper), not just in the same episode.
- **Unit of analysis.** A baker-episode. `n_baker_eps` is how many baker-episodes used the ingredient or combination. The chart scripts filter on it (3+ for the main chart; 6+ before a point gets a label).
- **Luck** (`luck_attrib`) = Star Baker rate − elimination rate. Winning the final counts as Star Baker.
- **Judge sentiment** comes from regex matching on the transcripts. No LLM is involved except in the optional step 3.

### Key columns

| Column | Meaning |
|---|---|
| `a`, `b`, `c` / `ingredient` | The ingredient(s) in the row |
| `family_*`, `taste_profile` | Flavour family (Fruit, Citrus, Nuts …) and their combination |
| `n_baker_eps` | Number of baker-episodes that used this combination |
| `star_rate`, `elimination_rate` | Share of those baker-episodes that ended in Star Baker / elimination |
| `luck_attrib` | `star_rate − elimination_rate` |
| `judge_sentiment`, `warmth_vs_avg` | Transcript sentiment, and how far it sits from the average |
| `bake_sentiment` | Reception of the bakes that used the combination; the y-axis of the charts |
| `reward_graded` | Graded results score; the x-axis of the charts |
| `pairing_harmony`, `harmony_note` | Whether the judges said the flavours work together (+1) or clash (−1), with the quote |
| `used_by_winner`, `winners` | Whether a series winner used it, and who |
| `judges_read`, `read_quote` | A one-line summary of the judges' view and a supporting snippet |

## Known issues

## Sources and credits

- Transcripts: [Forever Dreaming](https://transcripts.foreverdreaming.org), fan-made. They're used here for analysis and shouldn't be redistributed.
- Bakes and results: the [`{bakeoff}`](https://github.com/apreshill/bakeoff) R package / TidyTuesday (series 1–9) and Wikipedia (series 10–16).
- Analysis and charts: John D. Harden / Wrong Number.

