suppressPackageStartupMessages({
  library(yaml)
  library(Seurat)
  library(Matrix)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

source("src/R/utils.R")

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

cfg <- yaml::read_yaml(get_arg("--config", "config/project.yaml"))
focused_dir <- file.path(cfg$paths$processed_dir, "gse244832_focused")
if (!file.exists(file.path(focused_dir, "matrix.mtx"))) {
  stop("Missing focused GSE244832 matrix. Run scripts/extract_gse244832_focused_matrix.py first.")
}

mat <- Matrix::readMM(file.path(focused_dir, "matrix.mtx"))
features <- read_tsv(file.path(focused_dir, "features.tsv"), col_names = FALSE, show_col_types = FALSE)[[1]]
barcodes <- read_tsv(file.path(focused_dir, "barcodes.tsv"), col_names = FALSE, show_col_types = FALSE)[[1]]
metadata <- read_csv(file.path(focused_dir, "metadata.csv"), show_col_types = FALSE) |> as.data.frame()
rownames(mat) <- make.unique(features)
colnames(mat) <- make.unique(as.character(barcodes))
rownames(metadata) <- metadata[[1]]
metadata <- metadata[colnames(mat), , drop = FALSE]

obj <- CreateSeuratObject(counts = mat, meta.data = metadata, project = "GSE244832_focused", min.cells = 1, min.features = 1)
obj <- NormalizeData(obj, verbose = FALSE)
obj <- ScaleData(obj, features = rownames(obj), verbose = FALSE)

hsc_markers <- intersect(c("COL1A1", "COL3A1", "ACTA2", "TAGLN", "PDGFRA", "PDGFRB", "LUM", "DCN", "RGS5", "THY1"), rownames(obj))
endo_markers <- intersect(c("PLVAP", "ACKR1", "VWF", "PECAM1"), rownames(obj))
mac_markers <- intersect(c("TREM2", "CD9", "SPP1", "GPNMB", "LST1", "C1QA", "C1QB", "C1QC"), rownames(obj))
obj$hsc_myofibroblast_score <- marker_score(obj, hsc_markers)
obj$endothelial_score <- marker_score(obj, endo_markers)
obj$macrophage_score <- marker_score(obj, mac_markers)
obj$focused_compartment <- case_when(
  obj$hsc_myofibroblast_score >= pmax(obj$endothelial_score, obj$macrophage_score, na.rm = TRUE) ~ "HSC_myofibroblast_like",
  obj$endothelial_score >= pmax(obj$hsc_myofibroblast_score, obj$macrophage_score, na.rm = TRUE) ~ "endothelial_like",
  obj$macrophage_score >= pmax(obj$hsc_myofibroblast_score, obj$endothelial_score, na.rm = TRUE) ~ "macrophage_like",
  TRUE ~ "low_signal"
)

candidate_genes <- intersect(c("SMOC2", "TIMP1", "COL1A1", "COL3A1", "PDGFRA", "PDGFRB", "PLVAP", "ACKR1", "TREM2", "CD9", "SPP1", "GPNMB"), rownames(obj))
expr <- FetchData(obj, vars = c(candidate_genes, "condition", "seurat_clusters", "focused_compartment"))
long <- expr |>
  tibble::rownames_to_column("cell") |>
  pivot_longer(cols = all_of(candidate_genes), names_to = "gene", values_to = "norm_expression")

condition_summary <- long |>
  group_by(gene, condition, focused_compartment) |>
  summarise(
    cells = n(),
    mean_norm_expression = mean(norm_expression, na.rm = TRUE),
    pct_detected = mean(norm_expression > 0, na.rm = TRUE) * 100,
    .groups = "drop"
  ) |>
  group_by(gene, focused_compartment) |>
  mutate(
    nash_mean = mean_norm_expression[match("NASH", condition)],
    normal_mean = mean_norm_expression[match("NORMAL", condition)],
    nash_vs_normal_delta = nash_mean - normal_mean
  ) |>
  ungroup() |>
  select(-nash_mean, -normal_mean)

safe_write(condition_summary, file.path(cfg$paths$tables_dir, "gse244832_focused_object_candidate_summary.csv"))

score_summary <- obj@meta.data |>
  tibble::rownames_to_column("cell") |>
  group_by(condition, focused_compartment) |>
  summarise(
    cells = n(),
    mean_hsc_score = mean(hsc_myofibroblast_score, na.rm = TRUE),
    mean_endothelial_score = mean(endothelial_score, na.rm = TRUE),
    mean_macrophage_score = mean(macrophage_score, na.rm = TRUE),
    .groups = "drop"
  )
safe_write(score_summary, file.path(cfg$paths$tables_dir, "gse244832_focused_object_compartment_scores.csv"))

p <- condition_summary |>
  filter(focused_compartment == "HSC_myofibroblast_like") |>
  mutate(condition = factor(condition, levels = c("NORMAL", "NAFL", "NASH"))) |>
  ggplot(aes(condition, gene, fill = mean_norm_expression)) +
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.2f", mean_norm_expression)), size = 3) +
  scale_fill_gradient(low = "#F7FBFF", high = "#2166AC") +
  labs(title = "GSE244832 focused Seurat object validation", x = NULL, y = NULL, fill = "mean normalized expression") +
  theme_project()
save_plot(p, file.path(cfg$paths$figures_dir, "gse244832_focused_object_validation_heatmap.png"), 8, 5.5)

saveRDS(obj, file.path(cfg$paths$processed_dir, "gse244832_focused_seurat.rds"))
message("GSE244832 focused object-level reanalysis complete.")
