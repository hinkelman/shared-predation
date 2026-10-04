# Associational effects in the Replacement experiment
#
# Total resources are fixed at 500 while the R1:R2 mix varies. For each type,
# the associational effect at a given mix is the fraction eaten in the mix minus
# the fraction eaten in its monoculture (500 of that type, 0 of the other).
# Positive values = associational susceptibility (shared doom); negative values =
# associational resistance (associational refuge).
#
# When the forager can only eat a roughly fixed number of a type in 20,000 ticks
# (e.g., R2 with handling time 1000), the fraction eaten scales with 1 / num, so
# check mean_eaten in the _summary.csv output before reading an effect as spatial.
#
# Usage: Rscript analysis/replacement.R [results/replacement.csv]

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
input <- if (length(args) > 0) args[1] else "results/replacement.csv"
out_dir <- dirname(input)
stem <- tools::file_path_sans_ext(basename(input))   # Output files are named after the input file

# BehaviorSpace table output has 6 lines of metadata before the header row
runs <- read_csv(input, skip = 6, show_col_types = FALSE,
                 col_select = c(`[run number]`, `R1-radius`, `R2-radius`, `Both-GUD?`,
                                `R1-num`, `R2-num`, `[step]`, `forager-count`,
                                `energy-gained`, `handling-time`,
                                starts_with("count resources"))) |>
  rename(run = `[run number]`, R1_radius = `R1-radius`, R2_radius = `R2-radius`,
         both_gud = `Both-GUD?`, R1_num = `R1-num`, R2_num = `R2-num`, ticks = `[step]`,
         foragers = `forager-count`, energy = `energy-gained`, handling = `handling-time`,
         R1_left = `count resources with [resource-type = "R1"]`,
         R2_left = `count resources with [resource-type = "R2"]`)

cat(sprintf("Read %d runs from %s\n", nrow(runs), input))

# One row per run and resource type, dropping types that are absent from the run
eaten <- runs |>
  pivot_longer(c(R1_num, R2_num, R1_left, R2_left),
               names_to = c("type", ".value"), names_sep = "_") |>
  filter(num > 0) |>
  mutate(eaten = num - left,
         frac_eaten = eaten / num,
         R1_freq = if_else(type == "R1", num, 500 - num) / 500)

conditions <- c("R1_radius", "R2_radius", "both_gud")

summary_tbl <- eaten |>
  group_by(across(all_of(conditions)), type, num, R1_freq) |>
  summarise(n = n(),
            mean_eaten = mean(eaten),
            mean_frac = mean(frac_eaten),
            se_frac = sd(frac_eaten) / sqrt(n),
            .groups = "drop")

# Compare each mix with the monoculture of the same type under the same conditions
mono <- summary_tbl |>
  filter(num == 500) |>
  select(all_of(conditions), type, mono_frac = mean_frac, mono_se = se_frac)

effects <- summary_tbl |>
  filter(num < 500) |>
  inner_join(mono, by = c(conditions, "type")) |>
  mutate(effect = mean_frac - mono_frac,
         effect_se = sqrt(se_frac^2 + mono_se^2),
         lower = effect - 1.96 * effect_se,
         upper = effect + 1.96 * effect_se,
         direction = case_when(lower > 0 ~ "susceptibility",
                               upper < 0 ~ "resistance",
                               TRUE ~ "none"))

write_csv(summary_tbl, file.path(out_dir, paste0(stem, "_summary.csv")))
write_csv(effects, file.path(out_dir, paste0(stem, "_effects.csv")))

effects |>
  select(all_of(conditions), type, num, effect, lower, upper, direction) |>
  arrange(type, R1_radius, R2_radius, both_gud, num) |>
  mutate(across(c(effect, lower, upper), \(x) round(x, 4))) |>
  print(n = Inf)

facet_labels <- labeller(R1_radius = \(x) paste("R1 radius", x),
                         R2_radius = \(x) paste("R2 radius", x))
gud_labels <- c(`TRUE` = "R1 + R2", `FALSE` = "R1 only")

p_frac <- ggplot(summary_tbl, aes(R1_freq, mean_frac, color = type,
                                  linetype = factor(both_gud))) +
  geom_line() +
  geom_pointrange(aes(ymin = mean_frac - 1.96 * se_frac, ymax = mean_frac + 1.96 * se_frac),
                  size = 0.2) +
  facet_grid(R1_radius ~ R2_radius, labeller = facet_labels) +
  scale_linetype_discrete(name = "Giving-up density", labels = gud_labels) +
  labs(x = "R1 frequency (R1 / 500)", y = "Fraction eaten", color = "Type") +
  theme_bw()

p_effect <- ggplot(effects, aes(R1_freq, effect, color = type,
                                linetype = factor(both_gud))) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_line() +
  geom_pointrange(aes(ymin = lower, ymax = upper), size = 0.2) +
  facet_grid(R1_radius ~ R2_radius, labeller = facet_labels) +
  scale_linetype_discrete(name = "Giving-up density", labels = gud_labels) +
  labs(x = "R1 frequency (R1 / 500)",
       y = "Associational effect\n(fraction eaten in mix - monoculture)",
       color = "Type") +
  theme_bw()

ggsave(file.path(out_dir, paste0(stem, "_fraction_eaten.png")), p_frac, width = 8, height = 6, dpi = 150)
ggsave(file.path(out_dir, paste0(stem, "_effects.png")), p_effect, width = 8, height = 6, dpi = 150)

cat(sprintf("Wrote summaries and figures to %s\n", out_dir))
