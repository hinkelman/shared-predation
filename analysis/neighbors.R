# Individual-level neighborhood effects: does a resource's own neighborhood change
# its chance of being eaten?
#
# Each resource's neighborhood density (Gaussian-weighted count of R1 and R2
# neighbors) is calculated at setup. The model records it for every eaten resource
# (type-eaten, R1-neighbor-list, R2-neighbor-list) and, in the Handle100
# experiments, for every survivor at the end of the run. Together these give the
# whole population, so we can model P(eaten) against conspecific and
# heterospecific neighbor density.
#
# Within each run, fit eaten ~ conspecific + heterospecific density (logistic,
# predictors standardized by their pooled SD for that resource type), then
# summarize the per-run coefficients across runs. A positive heterospecific
# coefficient means neighbors of the other type raise risk (shared doom); a
# negative one means they lower it (associational refuge).
#
# Usage: Rscript analysis/neighbors.R [results/replacement-handle100-neighbors.csv ...]

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
inputs <- if (length(args) > 0) args else
  c("results/replacement-handle100-neighbors.csv", "results/additive-handle100-neighbors.csv")
out_dir <- dirname(inputs[1])

num_re <- "-?[0-9]+(\\.[0-9]+)?(E-?[0-9]+)?"
parse_nums <- function(x) lapply(regmatches(x, gregexpr(num_re, x)), as.numeric)
parse_types <- function(x) regmatches(x, gregexpr("R[12]", x))

read_runs <- function(path) {
  dt <- fread(path, skip = 6, colClasses = "character")
  survivors <- grep("^\\[\\(list precision", names(dt), value = TRUE)
  stopifnot(length(survivors) == 2)
  data.table(
    file = basename(path),
    run = as.integer(dt[["[run number]"]]),
    R1_radius = as.numeric(dt[["R1-radius"]]),
    R2_radius = as.numeric(dt[["R2-radius"]]),
    both_gud = as.logical(toupper(dt[["Both-GUD?"]])),
    R1_num = as.numeric(dt[["R1-num"]]),
    R2_num = as.numeric(dt[["R2-num"]]),
    type_eaten = parse_types(dt[["type-eaten"]]),
    R1n_eaten = parse_nums(dt[["R1-neighbor-list"]]),
    R2n_eaten = parse_nums(dt[["R2-neighbor-list"]]),
    R1_surv = parse_nums(dt[[grep('"R1"', survivors, value = TRUE)]]),
    R2_surv = parse_nums(dt[[grep('"R2"', survivors, value = TRUE)]])
  )
}

runs <- rbindlist(lapply(inputs, read_runs))
runs <- runs[R1_num > 0 & R2_num > 0]   # heterospecific neighbors only exist in mixed runs
runs[, run_id := .I]
cat(sprintf("Read %d mixed runs from %s\n", nrow(runs), paste(inputs, collapse = ", ")))

# One row per resource: survivors are stored as alternating (R1-neighbors, R2-neighbors) pairs
surv_rows <- function(x, type) {
  m <- matrix(x, ncol = 2, byrow = TRUE)
  data.table(type = rep(type, nrow(m)), R1n = m[, 1], R2n = m[, 2], eaten = 0L)
}
resources <- runs[, {
  rbind(data.table(type = type_eaten[[1]], R1n = R1n_eaten[[1]], R2n = R2n_eaten[[1]], eaten = 1L),
        surv_rows(R1_surv[[1]], "R1"),
        surv_rows(R2_surv[[1]], "R2"))
}, by = .(run_id, R1_radius, R2_radius, both_gud, R1_num, R2_num)]

# Sanity check: every resource placed at setup is accounted for
counts <- resources[, .(n_R1 = sum(type == "R1"), n_R2 = sum(type == "R2")), by = run_id][runs, on = "run_id"]
stopifnot(all(counts$n_R1 == counts$R1_num), all(counts$n_R2 == counts$R2_num))

# Survivor densities are recorded to 5 decimal places; round eaten ones to match so that,
# for example, a tiny density is 0 for eaten and surviving resources alike
resources[, `:=`(R1n = round(R1n, 5), R2n = round(R2n, 5))]
resources[, `:=`(con = fifelse(type == "R1", R1n, R2n),
                 het = fifelse(type == "R1", R2n, R1n))]
resources[, `:=`(con_z = con / sd(con), het_z = het / sd(het)), by = type]

# Per-run logistic regressions; skip runs where too few or too many of a type were eaten to fit
fit_run <- function(eaten, con_z, het_z) {
  if (sum(eaten) < 5 || sum(1 - eaten) < 5) return(list(b_con = NA_real_, b_het = NA_real_))
  f <- suppressWarnings(glm.fit(cbind(1, con_z, het_z), eaten, family = binomial()))
  b <- f$coefficients
  if (!f$converged || anyNA(b) || any(abs(b[2:3]) > 10)) return(list(b_con = NA_real_, b_het = NA_real_))
  list(b_con = b[[2]], b_het = b[[3]])
}
coefs <- resources[, fit_run(eaten, con_z, het_z),
                   by = .(run_id, type, R1_radius, R2_radius, both_gud, R1_num, R2_num)]

conditions <- c("type", "R1_radius", "R2_radius", "both_gud")
coef_summary <- melt(coefs, measure.vars = c("b_con", "b_het"),
                     variable.name = "term", value.name = "b")[
  , .(runs_fit = sum(!is.na(b)), runs_total = .N,
      mean = mean(b, na.rm = TRUE), se = sd(b, na.rm = TRUE) / sqrt(sum(!is.na(b)))),
  by = c(conditions, "term")]
coef_summary[, `:=`(term = fifelse(term == "b_con", "conspecific", "heterospecific"),
                    lower = mean - 1.96 * se, upper = mean + 1.96 * se)]
coef_summary[, direction := fcase(lower > 0, "raises risk", upper < 0, "lowers risk", default = "none")]
setorderv(coef_summary, c("term", conditions))

fwrite(coef_summary, file.path(out_dir, "neighbors_coefficients.csv"))
print(coef_summary[, .(term, type, R1_radius, R2_radius, both_gud, runs_fit, runs_total,
                       mean = round(mean, 3), lower = round(lower, 3), upper = round(upper, 3),
                       direction)], nrows = Inf)

# Descriptive view: fraction eaten by heterospecific density bin (zero, then pooled quintiles)
resources[, het_bin := {
  breaks <- unique(quantile(het[het > 0], 0:5 / 5))
  fifelse(het == 0, "0", as.character(cut(het, breaks, include.lowest = TRUE, labels = FALSE)))
}, by = type]
binned <- resources[, .(n = .N, frac_eaten = mean(eaten), het_mid = median(het)),
                    by = c(conditions, "het_bin")]
fwrite(binned, file.path(out_dir, "neighbors_binned.csv"))

facet_labels <- labeller(type = \(x) paste("Focal", x),
                         R1_radius = \(x) paste("R1 radius", x),
                         R2_radius = \(x) paste("R2 radius", x))
gud_labels <- c(`TRUE` = "R1 + R2", `FALSE` = "R1 only")

p_coef <- ggplot(coef_summary, aes(interaction(R1_radius, R2_radius, sep = " / "), mean,
                                   color = factor(both_gud))) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_pointrange(aes(ymin = lower, ymax = upper), position = position_dodge(width = 0.4)) +
  facet_grid(type ~ term, labeller = facet_labels) +
  scale_color_discrete(name = "Giving-up density", labels = gud_labels) +
  labs(x = "R1 radius / R2 radius",
       y = "Log-odds of being eaten per SD of neighbor density\n(mean of per-run fits, 95% CI)") +
  theme_bw()

p_bins <- ggplot(binned, aes(het_mid, frac_eaten, color = factor(both_gud))) +
  geom_line() +
  geom_point(size = 1) +
  facet_grid(type ~ R1_radius + R2_radius, labeller = facet_labels, scales = "free_x") +
  scale_color_discrete(name = "Giving-up density", labels = gud_labels) +
  labs(x = "Heterospecific neighbor density (bin median)", y = "Fraction eaten") +
  theme_bw()

ggsave(file.path(out_dir, "neighbors_coefficients.png"), p_coef, width = 8, height = 6, dpi = 150)
ggsave(file.path(out_dir, "neighbors_risk.png"), p_bins, width = 11, height = 6, dpi = 150)
cat(sprintf("Wrote coefficients, bins and figures to %s\n", out_dir))
