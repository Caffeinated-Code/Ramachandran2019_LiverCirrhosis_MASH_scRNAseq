suppressPackageStartupMessages({
  library(yaml)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(limma)
  library(ggplot2)
  library(AnnotationDbi)
  library(org.Hs.eg.db)
})

source("src/R/utils.R")

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

cfg <- yaml::read_yaml(get_arg("--config", "config/project.yaml"))
series_path <- file.path(cfg$paths$metadata_dir, "GSE207310_series_matrix.txt.gz")
validation_dir <- file.path("data", "validation", "GSE207310")
if (!file.exists(series_path)) stop("Missing GSE207310 series matrix metadata. Run validation data preparation first.")
if (!dir.exists(validation_dir)) stop("Missing data/validation/GSE207310.")

parse_quoted <- function(line) {
  read.delim(text = line, header = FALSE, sep = "\t", quote = "\"", check.names = FALSE, stringsAsFactors = FALSE)[1, ] |>
    unlist(use.names = FALSE)
}

lines <- readLines(gzfile(series_path), warn = FALSE)
sample_accession <- parse_quoted(lines[grepl("^!Sample_geo_accession", lines)])
sample_accession <- sample_accession[-1]
sample_description <- parse_quoted(lines[grepl("^!Sample_description", lines)])
sample_description <- sample_description[-1]
characteristics <- lines[grepl("^!Sample_characteristics_ch1", lines)]
char_rows <- lapply(characteristics, function(line) parse_quoted(line)[-1])
char_labels <- vapply(char_rows, function(values) sub(":.*", "", values[[1]]), character(1))
char_values <- lapply(char_rows, function(values) trimws(sub("^[^:]+:", "", values)))

metadata <- tibble(gsm = sample_accession, sample_number = sample_description)
for (i in seq_along(char_labels)) {
  nm <- make.names(tolower(gsub("[^A-Za-z0-9]+", "_", char_labels[[i]])))
  metadata[[nm]] <- char_values[[i]]
}
metadata <- metadata |>
  mutate(
    disease_state = toupper(.data[["steatosis_activity_and_fibrosis_score"]]),
    fibrosis_numeric = suppressWarnings(as.numeric(gsub("[^0-9.]", "", .data[["kleiner_fibrosis_grade"]]))),
    nafld_activity_score = suppressWarnings(as.numeric(.data[["nafld_activity_score"]])),
    advanced_fibrosis = fibrosis_numeric >= 2,
    contrast_group = case_when(
      disease_state == "NASH" ~ "NASH",
      disease_state == "NAFL" ~ "NAFL",
      TRUE ~ disease_state
    )
  )
safe_write(metadata, file.path(cfg$paths$tables_dir, "validation_gse207310_sample_metadata.csv"))

priority_genes <- c("SMOC2", "TIMP1", "PLVAP", "ACKR1", "COL1A1", "COL3A1", "PDGFRA", "PDGFRB", "TREM2", "CD9", "SPP1", "GPNMB")
gene_map <- AnnotationDbi::select(org.Hs.eg.db, keys = priority_genes, keytype = "SYMBOL", columns = c("ENSEMBL", "SYMBOL")) |>
  as_tibble() |>
  filter(!is.na(ENSEMBL), !is.na(SYMBOL)) |>
  distinct()
safe_write(gene_map, file.path(cfg$paths$tables_dir, "validation_gse207310_candidate_gene_map.csv"))

files <- list.files(validation_dir, pattern = "^GSM.*\\.txt\\.gz$", full.names = TRUE)
sample_lookup <- tibble(file = files, gsm = sub("^(GSM[0-9]+).*", "\\1", basename(files))) |>
  left_join(metadata, by = "gsm")

counts_list <- list()
lib_sizes <- numeric(nrow(sample_lookup))
for (i in seq_len(nrow(sample_lookup))) {
  dat <- read_csv(sample_lookup$file[[i]], show_col_types = FALSE, col_names = TRUE)
  names(dat) <- c("ensembl_id", "count")
  lib_sizes[[i]] <- sum(dat$count, na.rm = TRUE)
  candidate_counts <- dat |>
    semi_join(gene_map, by = c("ensembl_id" = "ENSEMBL")) |>
    group_by(ensembl_id) |>
    summarise(count = sum(count), .groups = "drop")
  counts_list[[sample_lookup$gsm[[i]]]] <- candidate_counts$count[match(gene_map$ENSEMBL, candidate_counts$ensembl_id)] |>
    replace_na(0)
}
count_mat <- do.call(cbind, counts_list)
rownames(count_mat) <- gene_map$ENSEMBL
sample_lookup$library_size <- lib_sizes

symbol_counts <- as_tibble(count_mat, rownames = "ensembl_id") |>
  left_join(gene_map, by = c("ensembl_id" = "ENSEMBL")) |>
  relocate(SYMBOL, .after = ensembl_id) |>
  pivot_longer(cols = all_of(sample_lookup$gsm), names_to = "gsm", values_to = "count") |>
  left_join(sample_lookup |> dplyr::select(gsm, disease_state, kleiner_fibrosis_grade, fibrosis_numeric, nafld_activity_score, library_size), by = "gsm") |>
  mutate(cpm = count / pmax(library_size, 1) * 1e6, log2_cpm = log2(cpm + 0.5))

safe_write(symbol_counts, file.path(cfg$paths$tables_dir, "validation_gse207310_candidate_expression_long.csv"))

summary_tbl <- symbol_counts |>
  group_by(SYMBOL, disease_state) |>
  summarise(
    samples = n_distinct(gsm),
    mean_log2_cpm = mean(log2_cpm, na.rm = TRUE),
    median_log2_cpm = median(log2_cpm, na.rm = TRUE),
    detected_samples = sum(count > 0),
    pct_detected = detected_samples / samples * 100,
    .groups = "drop"
  ) |>
  group_by(SYMBOL) |>
  mutate(nash_vs_nafl_delta_log2_cpm = mean_log2_cpm[disease_state == "NASH"][1] - mean_log2_cpm[disease_state == "NAFL"][1]) |>
  ungroup() |>
  arrange(SYMBOL, disease_state)
safe_write(summary_tbl, file.path(cfg$paths$tables_dir, "validation_gse207310_candidate_expression_by_disease.csv"))

wide_counts <- symbol_counts |>
  group_by(SYMBOL, gsm) |>
  summarise(count = sum(count), .groups = "drop") |>
  pivot_wider(names_from = gsm, values_from = count, values_fill = 0)
mat <- as.matrix(wide_counts[, sample_lookup$gsm])
rownames(mat) <- wide_counts$SYMBOL
log_cpm <- log2(t(t(mat + 0.5) / (sample_lookup$library_size + 1)) * 1e6)
design <- model.matrix(~ contrast_group + fibrosis_numeric, data = sample_lookup)
fit <- limma::eBayes(limma::lmFit(log_cpm, design), trend = TRUE)
nash_de <- limma::topTable(fit, coef = "contrast_groupNASH", number = Inf, sort.by = "none") |>
  tibble::rownames_to_column("gene") |>
  dplyr::rename(log2FC_NASH_vs_NAFL = logFC, p_value = P.Value, p_adj = adj.P.Val)
fibrosis_de <- limma::topTable(fit, coef = "fibrosis_numeric", number = Inf, sort.by = "none") |>
  tibble::rownames_to_column("gene") |>
  dplyr::select(gene, fibrosis_grade_log2FC_per_unit = logFC, fibrosis_p_value = P.Value, fibrosis_p_adj = adj.P.Val)
validation <- nash_de |>
  left_join(fibrosis_de, by = "gene") |>
  arrange(p_value)
safe_write(validation, file.path(cfg$paths$tables_dir, "validation_gse207310_candidate_lm_results.csv"))

p <- summary_tbl |>
  mutate(disease_state = factor(disease_state, levels = c("NAFL", "NASH"))) |>
  ggplot(aes(disease_state, SYMBOL, fill = mean_log2_cpm)) +
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.2f", mean_log2_cpm)), size = 3) +
  scale_fill_gradient(low = "#F7FBFF", high = "#2166AC") +
  labs(title = "GSE207310 bulk RNA-seq validation", x = NULL, y = NULL, fill = "mean log2 CPM") +
  theme_project()
save_plot(p, file.path(cfg$paths$figures_dir, "gse207310_candidate_validation_heatmap.png"), 7.5, 5.5)

message("GSE207310 symbol-level validation complete.")
