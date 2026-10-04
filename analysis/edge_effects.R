# Edge effects in the multi-scale neighborhood analysis
#
# At large scales (sigma 16-32), conspecific and heterospecific density both raise
# risk for every type. Resources sit in the 101 x 101 core (coordinates within
# +/-50.5), and the kernel is not corrected at its edges, so a resource near the
# center looks denser in both types than one near an edge. Foragers start anywhere
# in the core but are absorbed at +/-55.5, so central resources may also simply be
# found more often. This script tests whether position explains the large-scale
# effects, comparing three per-run logistic models at each scale:
#
#   uncorrected     eaten ~ con + het                (as in neighbor_scales.R)
#   edge-corrected  eaten ~ con_c + het_c            (density / share of kernel inside the core)
#   with position   eaten ~ con + het + edge         (edge = distance to nearest core edge)
#
# Coefficients are per pooled SD of each predictor for that type and scale. It also
# writes the fraction eaten by distance to the nearest edge.
#
# Usage: Rscript analysis/edge_effects.R [results/replacement-handle100-scales.csv ...]

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(parallel)
})

args <- commandArgs(trailingOnly = TRUE)
inputs <- if (length(args) > 0) args else
  c("results/replacement-handle100-scales.csv", "results/additive-handle100-scales.csv")
out_dir <- dirname(inputs[1])

sigmas <- c(0.5, 1, 2, 4, 8, 16, 32)
core <- 50.5                      # resources are placed on patches -50 to 50
cores <- max(1, detectCores() - 1)

num_re <- "-?[0-9]+(\\.[0-9]+)?(E-?[0-9]+)?"
parse_nums <- function(x) lapply(regmatches(x, gregexpr(num_re, x)), as.numeric)
parse_types <- function(x) regmatches(x, gregexpr("R[12]", x))

read_runs <- function(path) {
  dt <- fread(path, skip = 6, colClasses = "character")
  coords <- grep("^\\[\\(list precision xcor", names(dt), value = TRUE)
  stopifnot(length(coords) == 2)
  data.table(
    R1_radius = as.numeric(dt[["R1-radius"]]),
    R2_radius = as.numeric(dt[["R2-radius"]]),
    both_gud = as.logical(toupper(dt[["Both-GUD?"]])),
    R1_num = as.numeric(dt[["R1-num"]]),
    R2_num = as.numeric(dt[["R2-num"]]),
    type_eaten = parse_types(dt[["type-eaten"]]),
    xy_eaten = parse_nums(dt[["eaten-coords"]]),
    xy_R1 = parse_nums(dt[[grep('"R1"', coords, value = TRUE)]]),
    xy_R2 = parse_nums(dt[[grep('"R2"', coords, value = TRUE)]])
  )
}

runs <- rbindlist(lapply(inputs, read_runs))
runs <- runs[R1_num > 0 & R2_num > 0]   # heterospecific neighbors only exist in mixed runs
runs[, run_id := .I]
cat(sprintf("Read %d mixed runs from %s\n", nrow(runs), paste(inputs, collapse = ", ")))

fit_raw <- function(eaten, X) {
  if (sum(eaten) < 5 || sum(1 - eaten) < 5) return(rep(NA_real_, ncol(X)))
  # glm.fit can stop with an error on degenerate data (e.g., a density that is 0 for every resource)
  f <- tryCatch(suppressWarnings(glm.fit(cbind(1, X), eaten, family = binomial())), error = \(e) NULL)
  if (is.null(f) || !f$converged || anyNA(f$coefficients)) return(rep(NA_real_, ncol(X)))
  unname(f$coefficients[-1])
}

process_run <- function(i) {
  r <- runs[i]
  n_eaten <- length(r$type_eaten[[1]])
  xy <- rbind(matrix(r$xy_eaten[[1]], ncol = 2, byrow = TRUE),
              matrix(r$xy_R1[[1]], ncol = 2, byrow = TRUE),
              matrix(r$xy_R2[[1]], ncol = 2, byrow = TRUE))
  type <- c(r$type_eaten[[1]], rep("R1", length(r$xy_R1[[1]]) / 2), rep("R2", length(r$xy_R2[[1]]) / 2))
  eaten <- rep(c(1L, 0L), c(n_eaten, nrow(xy) - n_eaten))
  is_R1 <- type == "R1"
  edge <- core - pmax(abs(xy[, 1]), abs(xy[, 2]))
  d2 <- as.matrix(dist(xy))^2

  # Resource-level rows for the binned check (sigma-independent)
  binned <- data.table(run_id = r$run_id, type, eaten, edge)

  out <- vector("list", length(sigmas))
  for (k in seq_along(sigmas)) {
    s <- sigmas[k]
    K <- exp(-d2 / (2 * s^2)) / (sqrt(2 * pi) * s)
    diag(K) <- 0
    nR1 <- drop(K %*% is_R1)
    nR2 <- drop(K %*% !is_R1)
    # Share of a 2D Gaussian kernel centered on each resource that falls inside the core
    inside <- (pnorm((core - xy[, 1]) / s) - pnorm((-core - xy[, 1]) / s)) *
              (pnorm((core - xy[, 2]) / s) - pnorm((-core - xy[, 2]) / s))
    con <- ifelse(is_R1, nR1, nR2)
    het <- ifelse(is_R1, nR2, nR1)
    preds <- data.table(con, het, con_c = con / inside, het_c = het / inside, edge)
    out[[k]] <- rbindlist(lapply(c("R1", "R2"), \(t) {
      sel <- type == t
      p <- preds[sel]
      models <- list(uncorrected = c("con", "het"),
                     `edge-corrected` = c("con_c", "het_c"),
                     `with position` = c("con", "het", "edge"))
      fits <- rbindlist(lapply(names(models), \(m) {
        vars <- models[[m]]
        data.table(model = m, var = vars, b_raw = fit_raw(eaten[sel], as.matrix(p[, ..vars])))
      }))
      sums <- melt(p[, lapply(.SD, \(v) list(c(sum(v), sum(v^2))))], measure.vars = names(p),
                   variable.name = "var", value.name = "stats")
      sums <- data.table(var = as.character(sums$var),
                         n = sum(sel),
                         sum = vapply(sums$stats, `[`, numeric(1), 1),
                         ss = vapply(sums$stats, `[`, numeric(1), 2))
      merge(fits, sums, by = "var")[, `:=`(run_id = r$run_id, type = t, sigma = s)]
    }))
  }
  list(fits = rbindlist(out), binned = binned)
}

results <- mclapply(seq_len(nrow(runs)), process_run, mc.cores = cores)
fits <- rbindlist(lapply(results, `[[`, "fits"))
binned_rows <- rbindlist(lapply(results, `[[`, "binned"))
conds <- runs[, .(run_id, R1_radius, R2_radius, both_gud)]
fits <- conds[fits, on = "run_id"]
binned_rows <- conds[binned_rows, on = "run_id"]

# Express coefficients per pooled SD of each predictor for that type and scale
pooled <- unique(fits[, .(run_id, type, sigma, var, n, sum, ss)])[
  , .(sd = sqrt((sum(ss) - sum(sum)^2 / sum(n)) / (sum(n) - 1))), by = .(type, sigma, var)]
fits <- pooled[fits, on = .(type, sigma, var)]
fits[, b := b_raw * sd]
fits[, bad := any(abs(b) > 10, na.rm = TRUE), by = .(run_id, type, sigma, model)]
fits[bad == TRUE, b := NA_real_]
fits[, term := fcase(var %in% c("con", "con_c"), "conspecific",
                     var %in% c("het", "het_c"), "heterospecific",
                     var == "edge", "distance to edge")]

conditions <- c("model", "term", "type", "R1_radius", "R2_radius", "both_gud", "sigma")
coef_summary <- fits[, .(runs_fit = sum(!is.na(b)), runs_total = .N,
                         mean = mean(b, na.rm = TRUE), se = sd(b, na.rm = TRUE) / sqrt(sum(!is.na(b)))),
                     by = conditions]
coef_summary[, `:=`(lower = mean - 1.96 * se, upper = mean + 1.96 * se)]
coef_summary[, direction := fcase(lower > 0, "raises risk", upper < 0, "lowers risk", default = "none")]
setorderv(coef_summary, c("term", "type", "R1_radius", "R2_radius", "both_gud", "sigma", "model"))
fwrite(coef_summary, file.path(out_dir, "edge_effects_coefficients.csv"))

# Compact view: heterospecific and conspecific coefficients at each scale, averaged across settings
overview <- coef_summary[term != "distance to edge",
                         .(mean = round(mean(mean), 3), settings_raise = sum(direction == "raises risk"),
                           settings_lower = sum(direction == "lowers risk")),
                         by = .(term, type, sigma, model)]
print(dcast(overview, term + type + sigma ~ model, value.var = "mean"), nrows = Inf)
print(coef_summary[term == "distance to edge",
                   .(mean = round(mean(mean), 3), settings_raise = sum(direction == "raises risk"),
                     settings_lower = sum(direction == "lowers risk")),
                   by = .(type, sigma)], nrows = Inf)

# Fraction eaten by distance to the nearest core edge (5-unit bins)
binned <- binned_rows[, .(n = .N, frac_eaten = mean(eaten)),
                      by = .(type, R1_radius, R2_radius, both_gud, edge_bin = pmin(floor(edge / 5) * 5, 45))]
fwrite(binned, file.path(out_dir, "edge_effects_binned.csv"))

gud_labels <- c(`TRUE` = "Both-GUD on", `FALSE` = "Both-GUD off")
p_coef <- ggplot(coef_summary[term != "distance to edge"],
                 aes(sigma, mean, color = model,
                     group = interaction(model, R1_radius, R2_radius))) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_line(alpha = 0.7) +
  geom_point(size = 0.8) +
  scale_x_log10(breaks = sigmas) +
  facet_grid(paste(type, term) ~ both_gud, labeller = labeller(both_gud = gud_labels),
             scales = "free_y") +
  labs(x = "Neighborhood scale (sigma)",
       y = "Log-odds of being eaten per SD of neighbor density\n(mean of per-run fits)",
       color = "Model",
       caption = "Each line is one combination of R1 radius and R2 radius") +
  theme_bw()

p_edge <- ggplot(binned, aes(edge_bin + 2.5, frac_eaten,
                             color = interaction(R1_radius, R2_radius, sep = " / "))) +
  geom_line() +
  geom_point(size = 1) +
  facet_grid(type ~ both_gud, labeller = labeller(both_gud = gud_labels,
                                                  type = \(x) paste("Focal", x))) +
  labs(x = "Distance to nearest core edge (bin center)", y = "Fraction eaten",
       color = "R1 radius / R2 radius") +
  theme_bw()

ggsave(file.path(out_dir, "edge_effects_coefficients.png"), p_coef, width = 9, height = 9, dpi = 150)
ggsave(file.path(out_dir, "edge_effects_binned.png"), p_edge, width = 8, height = 5, dpi = 150)
cat(sprintf("Wrote coefficients, bins and figures to %s\n", out_dir))
