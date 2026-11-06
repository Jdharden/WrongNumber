top <- read_csv("~/Desktop/GBBO/data/gbbo_ingredient_scores_withinchallenge.csv", show_col_types = FALSE) |>
  slice_max(n_baker_eps, n = 22) |> pull(ingredient)

grid <- read_csv("~/Desktop/GBBO/data/gbbo_pairing_scores_withinchallenge.csv", show_col_types = FALSE) |>
  filter(a %in% top, b %in% top) |>
  transmute(a, b, val = judge_sentiment)
grid <- bind_rows(grid, rename(grid, a = b, b = a))

ord <- grid |> group_by(a) |> summarise(m = mean(val, na.rm = TRUE)) |>
  arrange(desc(m)) |> pull(a)
grid <- mutate(grid, a = factor(a, ord), b = factor(b, rev(ord)))

ggplot(grid, aes(a, b, fill = val)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  # geom_text(aes(label = percent(val, accuracy = 1)), size = 2.2, colour = "grey15") +
  scale_fill_gradient2(low = WN_ACCENT, mid = WN_SAGE, high = WN_DARK,
                       midpoint = median(grid$val, na.rm = TRUE), na.value = "#F0EEE9",
                       labels = percent, name = "sentiment toward the bake") +
  coord_fixed() +
  labs(title = "The Great British Analysis",
       subtitle = "Judges' sentiment toward bakes that combined each pair of ingredients",
       x = NULL, y = NULL, caption = "John D. Harden/Wrong Number") +
  theme_wn(11) + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
