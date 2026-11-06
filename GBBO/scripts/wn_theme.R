# =====================================================================
#  Wrong Number brand theme for the GBBO charts
#  source("wn_theme.R") at the top of any chart script, then use the
#  WN_* colours and theme_wn().
# =====================================================================
suppressPackageStartupMessages(library(ggplot2))

WN_DARK   <- "#03685C"   # primary deep green (symbol dark)
WN_MID    <- "#408A7E"   # secondary green (circle dark)
WN_SAGE   <- "#E3E9E0"   # light sage (symbol light)
WN_CREAM  <- "#F8F7F3"   # off-white background (circle light)
WN_ACCENT <- "#C1694F"   # warm clay — the "bad/low" pole & winner accent
WN_ACCENT2<- "#8A4B3A"   # deep clay — handshake marker
WN_GOOD   <- "#E3E9E0"   # good-quadrant tint (sage)
WN_BAD    <- "#F3E4DE"   # danger-quadrant tint (pale clay)

# diverging luck scale: clay (bad) -> sage (neutral) -> green (good)
scale_fill_wn_div <- function(name = "Luck score", midpoint = 0)
  scale_fill_gradient2(low = WN_ACCENT, mid = WN_SAGE, high = WN_DARK,
                       midpoint = midpoint, name = name)

theme_wn <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      text            = element_text(colour = WN_DARK),
      plot.title      = element_text(face = "bold", colour = WN_DARK, size = base_size + 4),
      plot.subtitle   = element_text(colour = WN_MID),
      plot.caption    = element_text(colour = WN_MID, size = base_size - 3),
      axis.text       = element_text(colour = WN_MID),
      axis.title      = element_text(colour = WN_DARK),
      plot.background  = element_rect(fill = WN_CREAM, colour = NA),
      panel.background = element_rect(fill = WN_CREAM, colour = NA),
      legend.background = element_rect(fill = WN_CREAM, colour = NA),
      panel.grid.major = element_line(colour = WN_SAGE),
      panel.grid.minor = element_blank(),
      legend.position = "top")
}
