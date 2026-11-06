gbbo_search <- function(file, ingredient_name){
  
  suppressPackageStartupMessages({
    library(ggplot2); library(ggrepel); library(dplyr); library(readr); library(scales)
  })

  source("scripts/wn_theme.R")
  
  if (file == "single") {
    
    d <- read_csv("data/gbbo_ingredient_scores_withinchallenge.csv", show_col_types = FALSE) |> 
      filter(ingredient %in% ingredient_name)
    
  } else if (file == "pair") {
    
    d <- read_csv("data/gbbo_pairing_scores_withinchallenge.csv", show_col_types = FALSE) |> 
      filter(a %in% ingredient_name | b %in% ingredient_name)
    
  } else if (file == "trio") {
    
    d <- read_csv("data/gbbo_trio_scores_withinchallenge.csv", show_col_types = FALSE) |> 
      filter(
        a %in% ingredient_name |
          b %in% ingredient_name |
          c %in% ingredient_name
      )
  } 
  
  sent_mean <- mean(d$flavour_score, na.rm = TRUE)   # centre = average flavour liking
  d <- d |>
    mutate(reward    = reward_graded,
           sentiment = flavour_score - sent_mean,      # >0 = flavour liked more than average
           verified  = !is.na(luck_attrib)) |>
    filter(!is.na(reward))
  
  
  # label the corners (prefer verified = real bake combos)
  v <- filter(d, n_baker_eps >= 6)
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
      title = "The Great British Analysis",
      size = "Number of appearances"
    ) +
    theme_wn(13)
  
}


apple_01 <- gbbo_search("pair", "Apple")

apple_01 + 
  annotate(
    geom = "curve", x = .19, y = .1, xend = -.04, yend = .04, 
    # geom = "curve", x = -.06, y = .04, xend = .19, yend = .1, 
    curvature = .3, arrow = arrow(length = unit(1, "mm"))
  ) +
  annotate(
    geom = "text", 
    x = .19, y = .07, 
    label = "    Ingredients paired with apple 
    often performs poorly unless 
    it's  paired with with 
    ingredients like cream 
    and almond.", 
    hjust = "left",
    size = 3
  ) +
  labs(
    caption = "SOURCE + CAPTION"
  )


chocolate_01 <- gbbo_search("pair", "Chocolate")
chocolate_01 +
  labs(
    subtitle = "Chocolate appears in more bakes than anything else."
  ) +
  ggrepel::geom_text_repel(
    data = ~ dplyr::bind_rows(
      dplyr::slice_max(.x, reward, n = 1),   # best-performing partner
      # dplyr::slice_min(.x, reward, n = 1)    # worst-performing partner
    ),
    ggplot2::aes(label = a),
    fontface = "bold", size = 3.5, min.segment.length = 4
  )


Pineapple_01 <- gbbo_search("pair", "Pineapple")
Pineapple_01 +
  labs(
    subtitle = "Stop using pineapple ...",
    caption = "SOURCE + CAPTION"
  ) +
  ggrepel::geom_text_repel(
    data = ~ dplyr::bind_rows(
      dplyr::slice_max(.x, reward, n = 1),   # best-performing partner
      dplyr::slice_min(.x, reward, n = 1)    # worst-performing partner
    ),
    ggplot2::aes(label = a),
    fontface = "bold", size = 3.5, min.segment.length = 4
  )

rum_01 <- gbbo_search("pair", c("Rum","Brandy", "Liqueur","Wine","Whisky"))
rum_01 +
  labs(
    subtitle = "Prue loves alcohol, but it doesn't do well."
  ) +
  ggrepel::geom_text_repel(
    data = ~ dplyr::bind_rows(
      dplyr::slice_max(.x, reward, n = 1),   # best-performing partner
      dplyr::slice_min(.x, reward, n = 1)    # worst-performing partner
    ),
    ggplot2::aes(label = a),
    fontface = "bold", size = 3.5, min.segment.length = 4
  )


Banana_01 <- gbbo_search("pair", "Banana")
Banana_01 +
  labs(
    subtitle = "Banana rarely gets the spotlight, but its pairings mostly land"
  ) +
  ggrepel::geom_text_repel(
    data = ~ dplyr::bind_rows(
      dplyr::slice_max(.x, reward, n = 1),   # best-performing partner
      dplyr::slice_min(.x, reward, n = 1)    # worst-performing partner
    ),
    ggplot2::aes(label = b),
    fontface = "bold", size = 3.5, min.segment.length = 4
  )



Mango_01 <- gbbo_search("pair", "Mango")
Mango_01 +
  labs(
    subtitle = "Banana rarely gets the spotlight, but its pairings mostly land"
  ) +
  ggrepel::geom_text_repel(
    data = ~ dplyr::bind_rows(
      dplyr::slice_max(.x, reward, n = 1),   # best-performing partner
      dplyr::slice_min(.x, reward, n = 1)    # worst-performing partner
    ),
    ggplot2::aes(label = paste0(a, " + ",b)),
    fontface = "bold", size = 3.5, min.segment.length = 4
  ) 


fig_01 <- gbbo_search("pair", "Orange")
fig_01 +
  labs(
    subtitle = "Banana rarely gets the spotlight, but its pairings mostly land"
  ) +
  ggrepel::geom_text_repel(
    data = ~ dplyr::bind_rows(
      dplyr::slice_max(.x, reward, n = 1),   # best-performing partner
      dplyr::slice_min(.x, reward, n = 1)    # worst-performing partner
    ),
    ggplot2::aes(label = a),
    fontface = "bold", size = 3.5, min.segment.length = 4
  )


install.packages("gt")
library(gt)
library(dplyr)

d |> 
  select(a, b, flavour_score) |> 
  # arrange(flavour_score)|>
  arrange(desc(flavour_score)) |>
  head(15) |> 
  gt()
