# Compare associational effects between R2 handling times of 1000 and 100
#
# Reads the _summary.csv and _effects.csv outputs of replacement.R and additive.R
# for both handling times and plots the effects side by side.
#
# Usage: Rscript analysis/compare_handling.R [results]

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
dir <- if (length(args) > 0) args[1] else "results"

files <- tribble(
  ~design,       ~R2_handle, ~stem,
  "Replacement", 1000,       "replacement",
  "Replacement", 100,        "replacement-handle100",
  "Additive",    1000,       "additive",
  "Additive",    100,        "additive-handle100"
)

read_output <- function(suffix) {
  pmap(files, \(design, R2_handle, stem) {
    read_csv(file.path(dir, paste0(stem, suffix)), show_col_types = FALSE) |>
      mutate(design = design, R2_handle = R2_handle)
  }) |>
    list_rbind() |>
    # Put both designs on one x axis: the number of the other type alongside the focal type
    mutate(neighbors = if_else(design == "Replacement", 500 - num, neighbors))
}

effects <- read_output("_effects.csv")
summary_tbl <- read_output("_summary.csv")

# Counts of settings by direction, across the radius and giving-up conditions
effects |>
  count(design, R2_handle, type, direction) |>
  tidyr::pivot_wider(names_from = direction, values_from = n, values_fill = 0) |>
  arrange(design, type, desc(R2_handle)) |>
  print(n = Inf)

# Effect size range at each neighbor level
effects |>
  group_by(design, type, neighbors, R2_handle) |>
  summarise(min = round(min(effect), 3), max = round(max(effect), 3), .groups = "drop") |>
  arrange(design, type, neighbors, desc(R2_handle)) |>
  print(n = Inf)

# Number of each type eaten per run, to check whether handling time caps it
summary_tbl |>
  group_by(design, type, neighbors, R2_handle) |>
  summarise(eaten_min = round(min(mean_eaten), 1), eaten_max = round(max(mean_eaten), 1),
            .groups = "drop") |>
  arrange(design, type, neighbors, desc(R2_handle)) |>
  print(n = Inf)

p <- ggplot(effects, aes(neighbors, effect, color = factor(R2_handle),
                         group = interaction(R2_handle, R1_radius, R2_radius, both_gud))) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_line(alpha = 0.6) +
  geom_point(size = 1) +
  facet_grid(type ~ design, scales = "free_y",
             labeller = labeller(type = \(x) paste("Focal", x))) +
  labs(x = "Number of the other type alongside the focal type",
       y = "Associational effect\n(fraction eaten - fraction eaten alone)",
       color = "R2 handling time",
       caption = "Each line is one combination of R1 radius, R2 radius and Both-GUD?") +
  theme_bw()

ggsave(file.path(dir, "handling_comparison.png"), p, width = 9, height = 6, dpi = 150)
cat(sprintf("Wrote %s\n", file.path(dir, "handling_comparison.png")))
