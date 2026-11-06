# 02_scores.R
# Within-challenge scoring for single ingredients, pairs, and trios.
# Rule: ingredients only pair if they are in the SAME challenge (signature /
# technical / showstopper are separate bakes). Luck = Star-Baker rate minus
# elimination rate. Sentiment/reward are joined from the other tables.
# Pure regex (via the gazetteer); no LLM.

source("R/00_gazetteer.R")
source("R/01_sentiment.R")            # ensures the sentiment file is fresh
suppressPackageStartupMessages(library(tidyverse))

MIN_N <- 2                             # keep rows seen in >= MIN_N baker-episodes

# ---- source data: one bake per baker per episode, with the outcome ----------
challenges <- read_csv("challenges_1_14.csv", show_col_types = FALSE) |>
  filter(!is.na(result)) |>
  transmute(
    series, episode, baker,
    baker_ep = str_c(series, episode, baker, sep = "|"),
    star = as.integer(result %in% c("STAR BAKER", "WINNER")),
    out  = as.integer(result == "OUT"),
    signature, technical, showstopper
  )

# one row per (baker-episode, challenge, ingredient)
challenge_ings <- challenges |>
  pivot_longer(c(signature, technical, showstopper),
               names_to = "challenge", values_to = "text") |>
  mutate(ingredient = map(text, find_ings)) |>
  unnest(ingredient) |>
  distinct(baker_ep, series, baker, star, out, challenge, ingredient)

# ---- lookups for the sentiment + reward columns -----------------------------
senti    <- read_csv("gbbo_ingredient_sentiment_transcript.csv", show_col_types = FALSE)
sent_vec <- deframe(select(senti, ingredient, net_sentiment))
sent_avg <- mean(senti$net_sentiment, na.rm = TRUE)
rew_vec  <- read_csv("ingredient_transcript_read.csv", show_col_types = FALSE) |>
  mutate(ingredient = canonise(ingredient)) |>
  group_by(ingredient) |>
  summarise(reward = mean(reward_graded), .groups = "drop") |>
  deframe()

# average sentiment/reward across the 1-3 ingredients that make up a row
add_sentiment_reward <- function(df, keys) {
  df |>
    mutate(
      judge_sentiment = pmap_dbl(across(all_of(keys)), \(...) round(mean(sent_vec[c(...)], na.rm = TRUE), 4)),
      warmth_vs_avg   = round(judge_sentiment - sent_avg, 4),
      reward_graded   = pmap_dbl(across(all_of(keys)), \(...) round(mean(rew_vec[c(...)],  na.rm = TRUE), 4))
    )
}

# star-baker rate, elimination rate, luck, and the list of winners who used it
summarise_outcomes <- function(df, keys) {
  df |>
    group_by(across(all_of(keys))) |>
    summarise(
      n_baker_eps      = n(),
      star_rate        = round(mean(star), 4),
      elimination_rate = round(mean(out), 4),
      luck_attrib      = round(mean(star) - mean(out), 4),
      used_by_winner   = any(star == 1),
      winners          = str_c(sort(unique(str_c(baker, " (S", series, ")")[star == 1])), collapse = "; "),
      .groups = "drop"
    ) |>
    filter(n_baker_eps >= MIN_N)
}

# ---- singles: dedupe to baker-episode, then score ---------------------------
singles <- challenge_ings |>
  distinct(baker_ep, series, baker, star, out, ingredient) |>
  summarise_outcomes("ingredient") |>
  mutate(family = ing_family(ingredient)) |>
  add_sentiment_reward("ingredient") |>
  select(ingredient, family, n_baker_eps, star_rate, elimination_rate, luck_attrib,
         judge_sentiment, warmth_vs_avg, reward_graded, used_by_winner, winners) |>
  arrange(desc(luck_attrib), desc(n_baker_eps))

write_csv(singles, "gbbo_ingredient_scores_withinchallenge.csv")

# ---- pairs / trios: combinations WITHIN one challenge, deduped per baker-ep --
combo_tbl <- function(x, k) {                      # ingredients -> tibble of a,b(,c)
  set_names(as_tibble(t(combn(sort(x), k)), .name_repair = "minimal"), letters[1:k])
}

combos_within <- function(k) {
  keys <- letters[1:k]
  challenge_ings |>
    group_by(baker_ep, series, baker, star, out, challenge) |>
    filter(n() >= k) |>
    reframe(combo_tbl(ingredient, k)) |>
    distinct(baker_ep, series, baker, star, out, across(all_of(keys))) |>
    summarise_outcomes(keys) |>
    add_sentiment_reward(keys) |>
    select(all_of(keys), n_baker_eps, star_rate, elimination_rate, luck_attrib,
           judge_sentiment, warmth_vs_avg, reward_graded, used_by_winner, winners) |>
    arrange(desc(luck_attrib), desc(n_baker_eps))
}

write_csv(combos_within(2), "gbbo_pairing_scores_withinchallenge.csv")
write_csv(combos_within(3), "gbbo_trio_scores_withinchallenge.csv")

message("02_scores: singles ", nrow(singles),
        " | pairs ",  nrow(read_csv("gbbo_pairing_scores_withinchallenge.csv", show_col_types = FALSE)),
        " | trios ",  nrow(read_csv("gbbo_trio_scores_withinchallenge.csv",   show_col_types = FALSE)))
