# Individual-level neighborhood effects at multiple spatial scales
#
# The model calculates each resource's neighborhood density with the forager's
# sigma, which also sets how the forager perceives density, so it cannot be varied
# without changing forager behavior. Instead, the Handle100 experiments record the
# coordinates of every eaten resource (eaten-coords) and every survivor. Resources
# do not move, so this script rebuilds each run's landscape and recalculates
# Gaussian-weighted conspecific and heterospecific neighbor density at several
# scales, using the same kernel as the model's kernel-sum.
#
# By default, densities are edge-corrected: each is divided by the share of its
# Gaussian kernel that falls inside the core where resources are placed (+/-50.5),
# so resources near the edges are not undercounted at large scales (see
# edge_effects.R). Pass --uncorrected to use the model's uncorrected kernel.
#
# For each scale, it fits eaten ~ conspecific + heterospecific density within each
# run (logistic, coefficients expressed per pooled SD of density for that type and
# scale) and summarizes the per-run coefficients across runs. A positive
# heterospecific coefficient means neighbors of the other type raise risk (shared
# doom); a negative one means they lower it (associational refuge).
#
# As a check, uncorrected densities at sigma = 1 are compared with the model's own
# values for eaten resources (R1-neighbor-list, R2-neighbor-list).
#
# Usage: Rscript analysis/neighbor_scales.R [--uncorrected] [results/replacement-handle100-scales.csv ...]

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(parallel)
})

args <- commandArgs(trailingOnly = TRUE)
edge_correct <- !("--uncorrected" %in% args)
inputs <- setdiff(args, "--uncorrected")
if (length(inputs) == 0)
  inputs <- c("results/replacement-handle100-scales.csv", "results/additive-handle100-scales.csv")
out_dir <- dirname(inputs[1])
out_stem <- if (edge_correct) "neighbor_scales" else "neighbor_scales_uncorrected"
core <- 50.5                      # resources are placed on patches -50 to 50

sigmas <- c(0.5, 1, 2, 4, 8, 16, 32)
cores <- max(1, detectCores() - 1)

num_re <- "-?[0-9]+(\\.[0-9]+)?(E-?[0-9]+)?"
parse_nums <- function(x) lapply(regmatches(x, gregexpr(num_re, x)), as.numeric)
parse_types <- function(x) regmatches(x, gregexpr("R[12]", x))

read_runs <- function(path) {
  dt <- fread(path, skip = 6, colClasses = "character")
  coords <- grep("^\\[\\(list precision xcor", names(dt), value = TRUE)
  stopifnot(length(coords) == 2)
  data.table(
    run = as.integer(dt[["[run number]"]]),
    R1_radius = as.numeric(dt[["R1-radius"]]),
    R2_radius = as.numeric(dt[["R2-radius"]]),
    both_gud = as.logical(toupper(dt[["Both-GUD?"]])),
    R1_num = as.numeric(dt[["R1-num"]]),
    R2_num = as.numeric(dt[["R2-num"]]),
    type_eaten = parse_types(dt[["type-eaten"]]),
    R1n_eaten = parse_nums(dt[["R1-neighbor-list"]]),
    R2n_eaten = parse_nums(dt[["R2-neighbor-list"]]),
    xy_eaten = parse_nums(dt[["eaten-coords"]]),
    xy_R1 = parse_nums(dt[[grep('"R1"', coords, value = TRUE)]]),
    xy_R2 = parse_nums(dt[[grep('"R2"', coords, value = TRUE)]])
  )
}

runs <- rbindlist(lapply(inputs, read_runs))
runs <- runs[R1_num > 0 & R2_num > 0]   # heterospecific neighbors only exist in mixed runs
runs[, run_id := .I]
cat(sprintf("Read %d mixed runs from %s (%s densities)\n", nrow(runs), paste(inputs, collapse = ", "),
            if (edge_correct) "edge-corrected" else "uncorrected"))

fit_raw <- function(eaten, con, het) {
  if (sum(eaten) < 5 || sum(1 - eaten) < 5) return(c(NA_real_, NA_real_))
  f <- suppressWarnings(glm.fit(cbind(1, con, het), eaten, family = binomial()))
  if (!f$converged || anyNA(f$coefficients)) return(c(NA_real_, NA_real_))
  f$coefficients[2:3]
}

# Neighbor densities at every scale for one run; returns raw per-run coefficients, sums
# for pooled SDs, and the largest difference from the model's sigma = 1 densities
process_run <- function(i) {
  r <- runs[i]
  n_eaten <- length(r$type_eaten[[1]])
  xy <- rbind(matrix(r$xy_eaten[[1]], ncol = 2, byrow = TRUE),
              matrix(r$xy_R1[[1]], ncol = 2, byrow = TRUE),
              matrix(r$xy_R2[[1]], ncol = 2, byrow = TRUE))
  type <- c(r$type_eaten[[1]], rep("R1", length(r$xy_R1[[1]]) / 2), rep("R2", length(r$xy_R2[[1]]) / 2))
  eaten <- rep(c(1L, 0L), c(n_eaten, nrow(xy) - n_eaten))
  stopifnot(sum(type == "R1") == r$R1_num, sum(type == "R2") == r$R2_num)
  is_R1 <- type == "R1"
  d2 <- as.matrix(dist(xy))^2

  check <- NA_real_
  out <- vector("list", length(sigmas))
  for (k in seq_along(sigmas)) {
    s <- sigmas[k]
    K <- exp(-d2 / (2 * s^2)) / (sqrt(2 * pi) * s)
    diag(K) <- 0
    nR1 <- drop(K %*% is_R1)
    nR2 <- drop(K %*% !is_R1)
    if (s == 1 && n_eaten > 0) {
      check <- max(abs(c(nR1[1:n_eaten] - r$R1n_eaten[[1]], nR2[1:n_eaten] - r$R2n_eaten[[1]])))
    }
    if (edge_correct) {
      # Share of a 2D Gaussian kernel centered on each resource that falls inside the core
      inside <- (pnorm((core - xy[, 1]) / s) - pnorm((-core - xy[, 1]) / s)) *
                (pnorm((core - xy[, 2]) / s) - pnorm((-core - xy[, 2]) / s))
      nR1 <- nR1 / inside
      nR2 <- nR2 / inside
    }
    con <- ifelse(is_R1, nR1, nR2)
    het <- ifelse(is_R1, nR2, nR1)
    out[[k]] <- rbindlist(lapply(c("R1", "R2"), \(t) {
      sel <- type == t
      b <- fit_raw(eaten[sel], con[sel], het[sel])
      data.table(run_id = r$run_id, type = t, sigma = s, b_con_raw = b[1], b_het_raw = b[2],
                 n = sum(sel), sum_con = sum(con[sel]), ss_con = sum(con[sel]^2),
                 sum_het = sum(het[sel]), ss_het = sum(het[sel]^2))
    }))
  }
  res <- rbindlist(out)
  res[, max_diff_sigma1 := check]
  res
}

fits <- rbindlist(mclapply(seq_len(nrow(runs)), process_run, mc.cores = cores))
fits <- runs[, .(run_id, R1_radius, R2_radius, both_gud, R1_num, R2_num)][fits, on = "run_id"]

check <- fits[, .(max_diff = max(max_diff_sigma1, na.rm = TRUE))]
cat(sprintf("Largest difference from the model's sigma = 1 densities: %.2e\n", check$max_diff))

# Express coefficients per pooled SD of density for each type and scale
pooled <- fits[, .(sd_con = sqrt((sum(ss_con) - sum(sum_con)^2 / sum(n)) / (sum(n) - 1)),
                   sd_het = sqrt((sum(ss_het) - sum(sum_het)^2 / sum(n)) / (sum(n) - 1))),
               by = .(type, sigma)]
fits <- pooled[fits, on = .(type, sigma)]
fits[, `:=`(b_con = b_con_raw * sd_con, b_het = b_het_raw * sd_het)]
fits[abs(b_con) > 10 | abs(b_het) > 10, `:=`(b_con = NA_real_, b_het = NA_real_)]

conditions <- c("type", "R1_radius", "R2_radius", "both_gud", "sigma")
coef_summary <- melt(fits, id.vars = conditions, measure.vars = c("b_con", "b_het"),
                     variable.name = "term", value.name = "b")[
  , .(runs_fit = sum(!is.na(b)), runs_total = .N,
      mean = mean(b, na.rm = TRUE), se = sd(b, na.rm = TRUE) / sqrt(sum(!is.na(b)))),
  by = c(conditions, "term")]
coef_summary[, `:=`(term = fifelse(term == "b_con", "conspecific", "heterospecific"),
                    lower = mean - 1.96 * se, upper = mean + 1.96 * se)]
coef_summary[, direction := fcase(lower > 0, "raises risk", upper < 0, "lowers risk", default = "none")]
setorderv(coef_summary, c("term", "type", "R1_radius", "R2_radius", "both_gud", "sigma"))

fwrite(coef_summary, file.path(out_dir, paste0(out_stem, "_coefficients.csv")))
print(coef_summary[term == "heterospecific",
                   .(type, R1_radius, R2_radius, both_gud, sigma, runs_fit,
                     mean = round(mean, 3), lower = round(lower, 3), upper = round(upper, 3), direction)],
      nrows = Inf)

gud_labels <- c(`TRUE` = "Both-GUD on", `FALSE` = "Both-GUD off")
p <- ggplot(coef_summary, aes(sigma, mean, color = interaction(R1_radius, R2_radius, sep = " / "))) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_line() +
  geom_pointrange(aes(ymin = lower, ymax = upper), size = 0.2) +
  scale_x_log10(breaks = sigmas) +
  facet_grid(paste(type, term) ~ both_gud, labeller = labeller(both_gud = gud_labels),
             scales = "free_y") +
  labs(x = "Neighborhood scale (sigma)",
       y = "Log-odds of being eaten per SD of neighbor density\n(mean of per-run fits, 95% CI)",
       color = "R1 radius / R2 radius") +
  theme_bw()

ggsave(file.path(out_dir, paste0(out_stem, ".png")), p, width = 9, height = 9, dpi = 150)
cat(sprintf("Wrote coefficients and figure to %s\n", out_dir))
