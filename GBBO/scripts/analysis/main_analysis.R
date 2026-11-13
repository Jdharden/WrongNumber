# Packages ----------------------------------------------------------------
suppressPackageStartupMessages({
  library(tidyverse); library(ggplot2); library(ggrepel); library(dplyr); library(readr); library(scales)
})

# Loading Data ------------------------------------------------------------
source("scripts/wn_theme.R")

d <- read_csv("data/gbbo_pairing_scores_withinchallenge.csv") |> 
  filter(n_baker_eps >= 3) |> 
  filter(used_by_winner == TRUE) |> 
  filter(str_detect(winners, "Nadiya"))

sent_mean <- mean(d$bake_sentiment, na.rm = TRUE)   # centre = average bake reception

d <- d |>
  mutate(reward    = reward_graded,
         sentiment = bake_sentiment - sent_mean,      # >0 = bakes reviewed warmer than average
         trusted   = n_baker_eps >= 6) |>
  filter(!is.na(reward))

v <- filter(d, n_baker_eps >= 3)

lab <- bind_rows(
  slice_max(v, sentiment - reward, n = 6),   # warm + poor  (top-left)
  slice_max(v, reward - sentiment, n = 6),   # cool + great (bottom-right)
  slice_max(v, reward + sentiment, n = 6),   # warm + great (top-right)
  slice_min(v, reward + sentiment, n = 4)    # cool + poor  (bottom-left)
) |> distinct()

xlim <- max(abs(d$reward))    * 1.08
ylim <- max(abs(d$sentiment)) * 1.10
quad <- data.frame(
  x  = c(-Inf,  Inf, -Inf,  Inf),
  y  = c( Inf,  Inf, -Inf, -Inf),
  hj = c( -0.05, 1.05, -0.05, 1.05),
  vj = c( 1.3, 1.3, -0.5, -0.5),
  lab = c("Warmer reviews\nweaker results",   # top-left
          "Warmer reviews\nstronger results",  # top-right
          "Cooler reviews\nweaker results",    # bottom-left
          "Cooler reviews\nstronger results")  # bottom-right# bottom-right: low praise / great bake
)

p <- ggplot(d, aes(reward, sentiment, size = n_baker_eps)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = 0, colour = "grey40") +
  geom_point(alpha=0.5) +
  geom_text(data = quad, aes(x, y, label = lab, hjust = hj, vjust = vj),
            inherit.aes = FALSE, size = 3.1, fontface = "bold", colour = "grey50", lineheight = 0.9) +
  scale_x_continuous(labels = label_percent(style_positive = "plus", accuracy = 1), limits = c(-xlim, xlim)) +
  scale_y_continuous(labels = label_percent(style_positive = "plus", accuracy = 1), limits = c(-ylim, ylim)) +
  labs(
    title = "How champions actually win",
    size = "Number of appearances",
    subtitle = "winning is execution, not a likeable flavor.",
    caption = "Wrong Number"
  ) +
  theme_wn(13)

p

plotly::ggplotly(p, tooltip = "all")
