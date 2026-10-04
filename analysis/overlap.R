# How does overlap between R1 and R2 clusters change associational effects?
#
# Reads the Overlap-Handle100 experiment: both radii 8, cluster-overlap from -1
# (separated) to 1 (shared cluster centers), R1:R2 at 250:0, 0:250 and 250:250, an
# opportunistic and a selective forager, and Both-GUD? on/off.
#
# Landscape level: the associational effect on each type is the fraction eaten in
# the 250:250 mix minus the fraction eaten alone (250 of that type, none of the
# other). Overlap cannot matter without the other type, so each monoculture is
# pooled across overlap levels.
#
# Realized mixing: mean R1 neighbor density at R2 locations (model kernel, sigma =
# the forager's sigma), from the neighbor values of eaten and surviving R2.
#
# Individual level: if neighbor_scales.R has been run on the same file, its
# heterospecific coefficients are plotted against overlap.
#
# Usage: Rscript analysis/overlap.R [results/overlap-handle100.csv]

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
input <- if (length(args) > 0) args[1] else "results/overlap-handle100.csv"
out_dir <- dirname(input)
stem <- tools::file_path_sans_ext(basename(input))   # Output files are named after the input file

num_re <- "-?[0-9]+(\\.[0-9]+)?(E-?[0-9]+)?"
parse_nums <- function(x) lapply(regmatches(x, gregexpr(num_re, x)), as.numeric)
parse_types <- function(x) regmatches(x, gregexpr("R[12]", x))

dt <- fread(input, skip = 6, colClasses = "character")
# Look columns up by pattern: fread keeps the CSV's doubled quotes in these names
col <- function(pattern) {
  hit <- grep(pattern, names(dt), value = TRUE)
  stopifnot(length(hit) == 1)
  dt[[hit]]
}
runs <- data.table(
  overlap = as.numeric(dt[["cluster-overlap"]]),
  both_gud = as.logical(toupper(dt[["Both-GUD?"]])),
  forager = fifelse(toupper(dt[["Selective?"]]) == "TRUE",
                    paste("selective, reject above", dt[["rejection-density"]]), "opportunistic"),
  R1_num = as.numeric(dt[["R1-num"]]),
  R2_num = as.numeric(dt[["R2-num"]]),
  R1_left = as.numeric(col('^count resources with .*= "+R1"+\\]$')),
  R2_left = as.numeric(col('^count resources with .*= "+R2"+\\]$')),
  type_eaten = parse_types(dt[["type-eaten"]]),
  R1n_eaten = parse_nums(dt[["R1-neighbor-list"]]),
  R2_surv = parse_nums(col('^\\[\\(list precision R1-neighbors.*= "+R2"+\\]$'))
)
runs[, run_id := .I]
cat(sprintf("Read %d runs from %s\n", nrow(runs), input))

# Landscape-level effects ------------------------------------------------------

focal <- rbind(
  runs[R1_num > 0, .(overlap, both_gud, forager, type = "R1", mixed = R2_num > 0, frac = (R1_num - R1_left) / R1_num)],
  runs[R2_num > 0, .(overlap, both_gud, forager, type = "R2", mixed = R1_num > 0, frac = (R2_num - R2_left) / R2_num)]
)
alone <- focal[mixed == FALSE, .(alone_frac = mean(frac), alone_se = sd(frac) / sqrt(.N)),
               by = .(both_gud, forager, type)]
mix <- focal[mixed == TRUE, .(n = .N, mix_frac = mean(frac), mix_se = sd(frac) / sqrt(.N)),
             by = .(overlap, both_gud, forager, type)]
effects <- alone[mix, on = .(both_gud, forager, type)]
effects[, `:=`(effect = mix_frac - alone_frac, effect_se = sqrt(mix_se^2 + alone_se^2))]
effects[, `:=`(lower = effect - 1.96 * effect_se, upper = effect + 1.96 * effect_se)]
effects[, direction := fcase(lower > 0, "susceptibility", upper < 0, "resistance", default = "none")]
setorder(effects, forager, type, both_gud, overlap)

# Realized mixing: R1 density at every R2 (eaten or surviving) in mixed runs
mixing <- runs[R1_num > 0 & R2_num > 0, {
  eaten_R2 <- R1n_eaten[[1]][type_eaten[[1]] == "R2"]
  surv <- matrix(R2_surv[[1]], ncol = 2, byrow = TRUE)[, 1]
  .(R1_density_at_R2 = mean(c(eaten_R2, surv)))
}, by = .(run_id, overlap, both_gud, forager)]
mixing_summary <- mixing[, .(R1_density_at_R2 = mean(R1_density_at_R2)), by = overlap][order(overlap)]
effects <- mixing_summary[effects, on = "overlap"]

fwrite(effects, file.path(out_dir, paste0(stem, "_effects.csv")))
cat("\nRealized mixing (mean R1 density at R2 locations):\n")
print(mixing_summary)
cat("\nLandscape-level associational effects (fraction eaten in mix - alone):\n")
print(effects[, .(forager, type, both_gud, overlap, mix_frac = round(mix_frac, 3), alone_frac = round(alone_frac, 3),
                  effect = round(effect, 3), lower = round(lower, 3), upper = round(upper, 3), direction)],
      nrows = Inf)

gud_labels <- c(`TRUE` = "Both-GUD on", `FALSE` = "Both-GUD off")
p_effect <- ggplot(effects, aes(overlap, effect, color = type, linetype = factor(both_gud),
                                group = interaction(type, both_gud))) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_line() +
  geom_pointrange(aes(ymin = lower, ymax = upper), size = 0.2) +
  facet_wrap(~ forager) +
  scale_linetype_discrete(name = NULL, labels = gud_labels) +
  labs(x = "cluster-overlap (-1 separated, 0 independent, 1 shared centers)",
       y = "Associational effect\n(fraction eaten in mix - alone)", color = "Type") +
  theme_bw()
ggsave(file.path(out_dir, paste0(stem, "_effects.png")), p_effect, width = 9, height = 4.5, dpi = 150)

# Individual-level effects, if neighbor_scales.R has been run on this file -----

coef_file <- file.path(out_dir, paste0(stem, "_neighbor_scales_coefficients.csv"))
if (file.exists(coef_file)) {
  # Cells where few runs could be fit (e.g., overlap -1, where almost no resource has heterospecific neighbors) are dropped
  coefs <- fread(coef_file)[term == "heterospecific" & sigma %in% c(1, 2, 4, 8) & runs_fit >= 30]
  coefs[, forager := fifelse(rejection == "never", "opportunistic", paste("selective, reject above", rejection))]
  cat("\nIndividual-level heterospecific effects (log-odds per SD, edge-corrected):\n")
  print(dcast(coefs[, .(forager, type, both_gud, sigma, overlap, mean = round(mean, 2))],
              forager + type + both_gud + sigma ~ overlap, value.var = "mean"), nrows = Inf)
  p_ind <- ggplot(coefs, aes(overlap, mean, color = factor(sigma), linetype = factor(both_gud),
                             group = interaction(sigma, both_gud))) +
    geom_hline(yintercept = 0, color = "grey50") +
    geom_line() +
    geom_pointrange(aes(ymin = lower, ymax = upper), size = 0.2) +
    facet_grid(paste("Focal", type) ~ forager, scales = "free_y") +
    scale_linetype_discrete(name = NULL, labels = gud_labels) +
    labs(x = "cluster-overlap", color = "sigma",
         y = "Log-odds of being eaten per SD of\nheterospecific neighbor density") +
    theme_bw()
  ggsave(file.path(out_dir, paste0(stem, "_individual.png")), p_ind, width = 9, height = 6, dpi = 150)
} else {
  cat(sprintf("\n%s not found; run neighbor_scales.R on %s for individual-level effects\n", coef_file, input))
}

cat(sprintf("Wrote summaries and figures to %s\n", out_dir))
