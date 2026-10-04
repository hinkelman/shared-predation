# Associational effects in the Additive experiment
#
# One type (the focal type) is fixed at 250 while 0 to 500 of the other type are
# added. Each type takes a turn as the focal type; the 250:250 runs serve both.
# The associational effect at a given number of neighbors is the fraction of the
# focal type eaten minus the fraction eaten with no neighbors (other type = 0).
# Positive values = associational susceptibility (shared doom); negative values =
# associational resistance (associational refuge).
#
# When the forager can only eat a roughly fixed number of a type in 20,000 ticks
# (e.g., R2 with handling time 1000), compare mean_eaten in additive_summary.csv
# before reading an effect as spatial.
#
# Usage: Rscript analysis/additive.R [results/additive.csv]

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
input <- if (length(args) > 0) args[1] else "results/additive.csv"
out_dir <- dirname(input)

# BehaviorSpace table output has 6 lines of metadata before the header row
runs <- read_csv(input, skip = 6, show_col_types = FALSE,
                 col_select = c(`[run number]`, `R1-radius`, `R2-radius`, `Both-GUD?`,
                                `R1-num`, `R2-num`, starts_with("count resources"))) |>
  rename(run = `[run number]`, R1_radius = `R1-radius`, R2_radius = `R2-radius`,
         both_gud = `Both-GUD?`, R1_num = `R1-num`, R2_num = `R2-num`,
         R1_left = `count resources with [resource-type = "R1"]`,
         R2_left = `count resources with [resource-type = "R2"]`)

cat(sprintf("Read %d runs from %s\n", nrow(runs), input))

# One row per run and focal type: the focal type is the one held at 250
focal <- bind_rows(
  runs |> filter(R1_num == 250) |>
    transmute(run, R1_radius, R2_radius, both_gud, type = "R1",
              neighbors = R2_num, eaten = 250 - R1_left),
  runs |> filter(R2_num == 250) |>
    transmute(run, R1_radius, R2_radius, both_gud, type = "R2",
              neighbors = R1_num, eaten = 250 - R2_left)
) |>
  mutate(frac_eaten = eaten / 250)

conditions <- c("R1_radius", "R2_radius", "both_gud")

summary_tbl <- focal |>
  group_by(across(all_of(conditions)), type, neighbors) |>
  summarise(n = n(),
            mean_eaten = mean(eaten),
            mean_frac = mean(frac_eaten),
            se_frac = sd(frac_eaten) / sqrt(n),
            .groups = "drop")

# Compare each neighbor level with the focal type alone under the same conditions
alone <- summary_tbl |>
  filter(neighbors == 0) |>
  select(all_of(conditions), type, alone_frac = mean_frac, alone_se = se_frac)

effects <- summary_tbl |>
  filter(neighbors > 0) |>
  inner_join(alone, by = c(conditions, "type")) |>
  mutate(effect = mean_frac - alone_frac,
         effect_se = sqrt(se_frac^2 + alone_se^2),
         lower = effect - 1.96 * effect_se,
         upper = effect + 1.96 * effect_se,
         direction = case_when(lower > 0 ~ "susceptibility",
                               upper < 0 ~ "resistance",
                               TRUE ~ "none"))

write_csv(summary_tbl, file.path(out_dir, "additive_summary.csv"))
write_csv(effects, file.path(out_dir, "additive_effects.csv"))

effects |>
  select(all_of(conditions), type, neighbors, effect, lower, upper, direction) |>
  arrange(type, R1_radius, R2_radius, both_gud, neighbors) |>
  mutate(across(c(effect, lower, upper), \(x) round(x, 4))) |>
  print(n = Inf)

facet_labels <- labeller(R1_radius = \(x) paste("R1 radius", x),
                         R2_radius = \(x) paste("R2 radius", x))
gud_labels <- c(`TRUE` = "R1 + R2", `FALSE` = "R1 only")

p_frac <- ggplot(summary_tbl, aes(neighbors, mean_frac, color = type,
                                  linetype = factor(both_gud))) +
  geom_line() +
  geom_pointrange(aes(ymin = mean_frac - 1.96 * se_frac, ymax = mean_frac + 1.96 * se_frac),
                  size = 0.2) +
  facet_grid(R1_radius ~ R2_radius, labeller = facet_labels) +
  scale_linetype_discrete(name = "Giving-up density", labels = gud_labels) +
  labs(x = "Number of the other type added", y = "Fraction of focal type eaten",
       color = "Focal type") +
  theme_bw()

p_effect <- ggplot(effects, aes(neighbors, effect, color = type,
                                linetype = factor(both_gud))) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_line() +
  geom_pointrange(aes(ymin = lower, ymax = upper), size = 0.2) +
  facet_grid(R1_radius ~ R2_radius, labeller = facet_labels) +
  scale_linetype_discrete(name = "Giving-up density", labels = gud_labels) +
  labs(x = "Number of the other type added",
       y = "Associational effect\n(fraction eaten with neighbors - alone)",
       color = "Focal type") +
  theme_bw()

ggsave(file.path(out_dir, "additive_fraction_eaten.png"), p_frac, width = 8, height = 6, dpi = 150)
ggsave(file.path(out_dir, "additive_effects.png"), p_effect, width = 8, height = 6, dpi = 150)

cat(sprintf("Wrote summaries and figures to %s\n", out_dir))
