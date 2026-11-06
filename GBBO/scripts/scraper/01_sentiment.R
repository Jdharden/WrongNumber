# 01_sentiment.R
# Net "judge sentiment" per ingredient, read from transcript lines.
# Idea: most transcript lines are prep chatter. We keep only lines that carry a
# verdict (praise or criticism words) and score net = (praise - criticism) / total.
# Pure regex, no LLM.

source("R/00_gazetteer.R")
suppressPackageStartupMessages(library(tidyverse))

praise <- c(
  "delicious", "lovely", "beautiful", "gorgeous", "perfect", "fantastic", "wonderful",
  "stunning", "delightful", "exquisite", "superb", "excellent", "brilliant", "impressive",
  "works? (?:well|beautifully|perfectly|really)", "(?:well|nicely|perfectly) balanced",
  "spot[- ]on", "bang[- ]on", "delicate", "\\bmoist\\b", "\\bcrisp",
  "(?:lovely|nice|so|really|beautifully) and fresh", "tastes? fresh",
  "vibrant", "zingy", "punchy", "so good", "really good", "very good",
  "love (?:it|that|the)", "great (?:flavour|texture|bake|balance)",
  "nice (?:flavour|texture|balance|and)"
)

criticism <- c(
  "too much", "too sweet", "too dry", "too dense", "too little", "not enough",
  "overpower", "overwhelm", "\\bdry\\b", "\\bdense\\b", "stodgy", "claggy", "soggy",
  "\\braw\\b", "under ?baked", "under ?cooked", "over ?baked", "over ?cooked", "overdone",
  "\\bbland\\b", "tasteless", "disappoint", "\\bmissing\\b", "\\black", "can.?t taste",
  "does(?:n.?t| not) come through", "did(?:n.?t| not) come through", "not coming through",
  "sickly", "\\bheavy\\b", "\\bsplit\\b", "curdl", "\\btough\\b", "rubbery", "\\bburn",
  "greasy", "sloppy", "\\bwrong\\b", "\\bgummy\\b", "\\bpale\\b", "sludgy", "grainy",
  "\\bsad\\b", "shame", "unfortunate", "struggl", "collaps", "\\bsunk\\b", "sinking",
  "kill(?:ing|s|ed)? the"
)

# "won't curdle / doesn't split" is reassurance, not criticism -> strip before scoring
guard <- paste0("(?:wo|do|does|did|is|are|ca)\\s?n.?t\\s+\\w{0,6}\\s?",
                "(?:curdl|split|separat|collaps|sink|sunk|burn|dry|overpower)",
                "|never\\s+(?:curdl|split|sink|burn)")

pos_re <- str_c(praise,    collapse = "|")
neg_re <- str_c(criticism, collapse = "|")

sentiment <- read_csv("transcript_comments_tidy.csv", show_col_types = FALSE) |>
  mutate(
    ingredient = canonise(ingredient),
    clean   = str_remove_all(snippet, regex(guard, ignore_case = TRUE)),
    verdict = case_when(
      str_detect(clean, regex(neg_re, ignore_case = TRUE)) ~ "criticism_lines",  # criticism wins ties
      str_detect(clean, regex(pos_re, ignore_case = TRUE)) ~ "praise_lines",
      TRUE                                                  ~ "none"
    )
  ) |>
  filter(verdict != "none") |>
  count(ingredient, verdict) |>
  pivot_wider(names_from = verdict, values_from = n, values_fill = 0) |>
  mutate(
    family        = ing_family(ingredient),
    verdict_lines = praise_lines + criticism_lines,
    net_sentiment = round((praise_lines - criticism_lines) / verdict_lines, 4)
  ) |>
  select(ingredient, family, praise_lines, criticism_lines, verdict_lines, net_sentiment) |>
  arrange(desc(verdict_lines))

write_csv(sentiment, "gbbo_ingredient_sentiment_transcript.csv")
message("01_sentiment: ", nrow(sentiment), " ingredients scored -> gbbo_ingredient_sentiment_transcript.csv")
