# When does selectivity pay, and what does it do to each resource type?
#
# Reads the Selective-HandleSweep experiment: R2 handling time 50, 100 or 200,
# rejection density 0.01 to 10 plus 1000 (never reject, the non-selective
# baseline), giving-up density 1e-4 to 1, both radii {8, 64}, Both-GUD? on/off and
# three R1:R2 mixes.
#
# For each condition and rejection density, it takes the giving-up density that
# maximizes mean energy gained (the forager's best response to that threshold), then
# compares the best selective threshold with never rejecting. It reports energy, the
# fraction of each type eaten and the number of rejections.
#
# Picking the best of many noisy cells inflates its mean, and there are 35 selective
# cells per condition but only 5 baseline cells. So thresholds are chosen on half of
# each cell's repetitions (odd run numbers) and evaluated on the other half (even).
#
# Usage: Rscript analysis/selective.R [results/selective-handlesweep.csv]

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
input <- if (length(args) > 0) args[1] else "results/selective-handlesweep.csv"
out_dir <- dirname(input)
stem <- tools::file_path_sans_ext(basename(input))   # Output files are named after the input file

never <- 1000   # rejection density above any R1 density in the model: the forager never rejects

# BehaviorSpace table output has 6 lines of metadata before the header row
runs <- read_csv(input, skip = 6, show_col_types = FALSE,
                 col_select = c(`[run number]`, `R1-radius`, `R2-radius`, `Both-GUD?`, `R2-handle`,
                                `rejection-density`, `giving-up-density`, `R1-num`, `R2-num`,
                                `energy-gained`, `resource-rejections`,
                                starts_with("count resources"))) |>
  rename(run = `[run number]`, R1_radius = `R1-radius`, R2_radius = `R2-radius`, both_gud = `Both-GUD?`,
         R2_handle = `R2-handle`, rejection = `rejection-density`, gud = `giving-up-density`,
         R1_num = `R1-num`, R2_num = `R2-num`, energy = `energy-gained`,
         rejections = `resource-rejections`,
         R1_left = `count resources with [resource-type = "R1"]`,
         R2_left = `count resources with [resource-type = "R2"]`) |>
  mutate(R1_frac = (R1_num - R1_left) / R1_num,
         R2_frac = (R2_num - R2_left) / R2_num)

cat(sprintf("Read %d runs from %s\n", nrow(runs), input))

conditions <- c("R2_handle", "R1_radius", "R2_radius", "both_gud", "R1_num", "R2_num")

cells <- runs |>
  mutate(half = if_else(run %% 2 == 1, "choose", "evaluate")) |>
  group_by(across(all_of(conditions)), rejection, gud, half) |>
  summarise(n = n(),
            energy_mean = mean(energy), energy_se = sd(energy) / sqrt(n),
            R1_frac = mean(R1_frac), R2_frac = mean(R2_frac),
            rejections = mean(rejections),
            .groups = "drop")

# Best giving-up density for each rejection threshold, chosen on one half and
# evaluated on the other
evaluate <- cells |> filter(half == "evaluate") |> select(-half)
pick_gud <- cells |>
  filter(half == "choose") |>
  group_by(across(all_of(conditions)), rejection) |>
  slice_max(energy_mean, n = 1, with_ties = FALSE) |>
  ungroup()
by_rejection <- pick_gud |>
  select(all_of(conditions), rejection, gud, choose_energy = energy_mean) |>
  inner_join(evaluate, by = c(conditions, "rejection", "gud"))

baseline <- by_rejection |>
  filter(rejection == never) |>
  select(all_of(conditions), base_energy = energy_mean, base_se = energy_se,
         base_R1_frac = R1_frac, base_R2_frac = R2_frac)

best <- by_rejection |>
  filter(rejection != never) |>
  group_by(across(all_of(conditions))) |>
  slice_max(choose_energy, n = 1, with_ties = FALSE) |>
  ungroup() |>
  inner_join(baseline, by = conditions) |>
  mutate(gain = energy_mean - base_energy,
         gain_se = sqrt(energy_se^2 + base_se^2),
         pays = gain - 1.96 * gain_se > 0,
         R2_frac_change = R2_frac - base_R2_frac,
         R1_frac_change = R1_frac - base_R1_frac)

write_csv(by_rejection, file.path(out_dir, paste0(stem, "_by_rejection.csv")))
write_csv(best, file.path(out_dir, paste0(stem, "_best.csv")))

# How often selectivity pays, by handling time
best |>
  group_by(R2_handle) |>
  summarise(conditions = n(), pays = sum(pays),
            median_gain_pct = round(100 * median(gain / base_energy), 1),
            median_best_rejection = median(rejection),
            median_R2_frac_change = round(median(R2_frac_change), 3),
            median_R1_frac_change = round(median(R1_frac_change), 3)) |>
  print()

best |>
  select(all_of(conditions), rejection, gud, energy_mean, base_energy, gain, pays,
         R1_frac_change, R2_frac_change, rejections) |>
  mutate(across(c(energy_mean, base_energy, gain), \(x) round(x)),
         across(c(R1_frac_change, R2_frac_change), \(x) round(x, 3)),
         rejections = round(rejections)) |>
  arrange(R2_handle, R1_num, R1_radius, R2_radius, both_gud) |>
  print(n = Inf, width = Inf)

mix_labels <- \(x) paste0("R1:R2 = ", x)
gud_labels <- c(`TRUE` = "R1 + R2", `FALSE` = "R1 only")
plot_data <- by_rejection |>
  mutate(mix = paste0(R1_num, ":", R2_num),
         radii = paste(R1_radius, "/", R2_radius),
         rejection_label = if_else(rejection == never, "never", format(rejection, drop0trailing = TRUE)),
         rejection_label = factor(rejection_label,
                                  levels = c(format(sort(unique(rejection[rejection != never])),
                                                    drop0trailing = TRUE), "never")))

p_energy <- ggplot(plot_data, aes(rejection_label, energy_mean, color = factor(R2_handle),
                                  linetype = factor(both_gud),
                                  group = interaction(R2_handle, both_gud))) +
  geom_line() +
  geom_point(size = 0.8) +
  facet_grid(mix ~ radii, labeller = labeller(mix = mix_labels), scales = "free_y") +
  scale_linetype_discrete(name = "Giving-up density", labels = gud_labels) +
  labs(x = "Rejection density (reject R2 where R1 density is above this)",
       y = "Mean energy gained\n(at the best giving-up density)",
       color = "R2 handling time",
       title = "Facets: R1 radius / R2 radius") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

p_frac <- plot_data |>
  pivot_longer(c(R1_frac, R2_frac), names_to = "type", values_to = "frac") |>
  mutate(type = sub("_frac", "", type)) |>
  ggplot(aes(rejection_label, frac, color = factor(R2_handle), linetype = type,
             group = interaction(R2_handle, both_gud, type))) +
  geom_line(alpha = 0.7) +
  facet_grid(mix ~ radii, labeller = labeller(mix = mix_labels)) +
  labs(x = "Rejection density", y = "Fraction eaten\n(at the best giving-up density)",
       color = "R2 handling time", linetype = "Type",
       title = "Facets: R1 radius / R2 radius") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(out_dir, paste0(stem, "_energy.png")), p_energy, width = 10, height = 8, dpi = 150)
ggsave(file.path(out_dir, paste0(stem, "_fraction_eaten.png")), p_frac, width = 10, height = 8, dpi = 150)
cat(sprintf("Wrote summaries and figures to %s\n", out_dir))
