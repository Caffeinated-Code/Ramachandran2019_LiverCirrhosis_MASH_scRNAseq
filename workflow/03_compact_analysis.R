suppressPackageStartupMessages({
  library(yaml)
  library(Seurat)
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(Matrix)
  library(patchwork)
})

source("src/R/utils.R")

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

set.seed(20260524)
cfg <- yaml::read_yaml(get_arg("--config", "config/project.yaml"))
manifest_path <- file.path(cfg$paths$metadata_dir, "gse136103_sample_manifest.csv")
if (!file.exists(manifest_path)) stop("Run workflow/02_curate_metadata.R first.")
manifest <- read_csv(manifest_path, show_col_types = FALSE) |> filter(include_primary)

extract_dir <- file.path(cfg$paths$processed_dir, "extracted_gse136103")
objects <- vector("list", nrow(manifest))
for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, ]
  message("Reading ", row$sample_token)
  mat <- read_10x_from_tar(cfg$datasets$primary$archive, row, extract_dir)
  obj <- CreateSeuratObject(
    counts = mat,
    project = "GSE136103",
    min.cells = cfg$analysis$min_cells_per_gene,
    min.features = cfg$analysis$min_genes_per_cell
  )
  obj$sample_id <- row$sample_token
  obj$gsm <- row$gsm
  obj$donor <- row$donor
  obj$disease_state <- row$disease_state
  obj$fraction <- row$fraction
  obj$tissue <- row$tissue
  obj$species <- row$species
  obj[["percent.mt"]] <- PercentageFeatureSet(obj, pattern = "^MT-")
  obj[["percent.ribo"]] <- PercentageFeatureSet(obj, pattern = "^RP[SL]")
  obj[["percent.hb"]] <- PercentageFeatureSet(obj, pattern = "^HB[ABDEGMQZ]")
  obj$log10_genes_per_umi <- log10(obj$nFeature_RNA + 1) / log10(obj$nCount_RNA + 1)
  objects[[i]] <- obj
}

combined <- merge(objects[[1]], y = objects[-1], add.cell.ids = manifest$sample_token, project = "GSE136103")
combined <- JoinLayers(combined)

qc_raw <- combined@meta.data |>
  tibble::rownames_to_column("cell") |>
  group_by(disease_state, donor, sample_id, fraction) |>
  summarise(
    cells = n(),
    median_genes = median(nFeature_RNA),
    q05_genes = quantile(nFeature_RNA, 0.05),
    q95_genes = quantile(nFeature_RNA, 0.95),
    median_umis = median(nCount_RNA),
    q05_umis = quantile(nCount_RNA, 0.05),
    q95_umis = quantile(nCount_RNA, 0.95),
    median_percent_mt = median(percent.mt),
    q95_percent_mt = quantile(percent.mt, 0.95),
    median_percent_ribo = median(percent.ribo),
    q95_percent_ribo = quantile(percent.ribo, 0.95),
    median_percent_hb = median(percent.hb),
    q95_percent_hb = quantile(percent.hb, 0.95),
    median_log10_genes_per_umi = median(log10_genes_per_umi),
    .groups = "drop"
  )
safe_write(qc_raw, file.path(cfg$paths$tables_dir, "qc_by_library.csv"))

qc_metric_summary <- combined@meta.data |>
  tibble::rownames_to_column("cell") |>
  summarise(
    total_cells_before_filter = n(),
    median_genes = median(nFeature_RNA),
    q05_genes = quantile(nFeature_RNA, 0.05),
    q95_genes = quantile(nFeature_RNA, 0.95),
    median_umis = median(nCount_RNA),
    q05_umis = quantile(nCount_RNA, 0.05),
    q95_umis = quantile(nCount_RNA, 0.95),
    median_percent_mt = median(percent.mt),
    q95_percent_mt = quantile(percent.mt, 0.95),
    median_percent_ribo = median(percent.ribo),
    q95_percent_ribo = quantile(percent.ribo, 0.95),
    median_percent_hb = median(percent.hb),
    q95_percent_hb = quantile(percent.hb, 0.95),
    median_log10_genes_per_umi = median(log10_genes_per_umi)
  )
safe_write(qc_metric_summary, file.path(cfg$paths$tables_dir, "qc_metric_summary.csv"))

max_mt <- cfg$analysis$max_mito_percent_default
qc_filter_status <- combined@meta.data |>
  tibble::rownames_to_column("cell") |>
  mutate(
    pass_min_genes = nFeature_RNA >= cfg$analysis$min_genes_per_cell,
    pass_mito = percent.mt <= max_mt,
    pass_qc = pass_min_genes & pass_mito
  )
qc_filter_summary <- qc_filter_status |>
  summarise(
    total_cells_before_filter = n(),
    cells_after_filter = sum(pass_qc),
    cells_removed_low_genes = sum(!pass_min_genes),
    cells_removed_high_mito = sum(!pass_mito),
    cells_removed_any_filter = sum(!pass_qc),
    pct_retained = cells_after_filter / total_cells_before_filter * 100
  )
safe_write(qc_filter_summary, file.path(cfg$paths$tables_dir, "qc_filter_summary.csv"))

qc_decisions <- tibble::tribble(
  ~metric, ~threshold_or_action, ~used_for_filtering, ~reason,
  "Detected genes per cell", paste0(">=", cfg$analysis$min_genes_per_cell), TRUE, "Removes low-complexity droplets while retaining stressed disease-relevant cells.",
  "Mitochondrial percent", paste0("<=", max_mt, "%"), TRUE, "Removes likely damaged cells; threshold is conservative because fibrotic liver can contain stressed biology.",
  "UMI count", "reviewed by library; no hard upper cutoff in compact run", FALSE, "High UMI cells can be doublets, but liver cell types differ in RNA content; hard filtering could remove large or active cells.",
  "Ribosomal percent", "reviewed by library; no hard cutoff", FALSE, "High ribosomal signal can reflect cell state or technical stress and is interpreted with other metrics.",
  "Hemoglobin percent", "reviewed by library; no hard cutoff", FALSE, "Flags erythrocyte/RBC ambient RNA contamination without removing liver cells solely on this metric.",
  "log10 genes per UMI", "reviewed by library; no hard cutoff", FALSE, "Low complexity can indicate poor-quality cells; used as a diagnostic metric rather than a blind filter.",
  "Doublet/ambient RNA", "not removed in compact run; recommended production module", FALSE, "Mixed marker states in scar tissue can be real niches or artifacts, so production filtering should combine algorithmic scores with marker review."
)
safe_write(qc_decisions, file.path(cfg$paths$tables_dir, "qc_decision_log.csv"))

qc_plot_df <- combined@meta.data |>
  tibble::rownames_to_column("cell") |>
  select(cell, disease_state, sample_id, nFeature_RNA, nCount_RNA, percent.mt, percent.ribo, percent.hb, log10_genes_per_umi) |>
  tidyr::pivot_longer(
    cols = c(nFeature_RNA, nCount_RNA, percent.mt, percent.ribo, percent.hb, log10_genes_per_umi),
    names_to = "metric",
    values_to = "value"
  ) |>
  mutate(
    metric = factor(
      metric,
      levels = c("nFeature_RNA", "nCount_RNA", "percent.mt", "percent.ribo", "percent.hb", "log10_genes_per_umi"),
      labels = c("Detected genes", "UMIs", "Mitochondrial %", "Ribosomal %", "Hemoglobin %", "Complexity")
    )
  )
p_qc <- ggplot(qc_plot_df, aes(disease_state, value, fill = disease_state)) +
  geom_violin(scale = "width", trim = TRUE, linewidth = 0.2) +
  geom_boxplot(width = 0.12, outlier.size = 0.2, alpha = 0.7) +
  facet_wrap(~ metric, scales = "free_y", ncol = 3) +
  labs(title = "QC metric distributions before filtering", x = NULL, y = NULL) +
  theme_project() +
  theme(legend.position = "none")
save_plot(p_qc, file.path(cfg$paths$figures_dir, "qc_metric_distributions.png"), 10, 6.5)

combined <- subset(combined, subset = nFeature_RNA >= cfg$analysis$min_genes_per_cell & percent.mt <= max_mt)

combined <- NormalizeData(combined, verbose = FALSE)
combined <- FindVariableFeatures(combined, nfeatures = cfg$analysis$top_variable_genes, verbose = FALSE)
combined <- ScaleData(combined, features = VariableFeatures(combined), verbose = FALSE)
combined <- RunPCA(combined, features = VariableFeatures(combined), npcs = 30, verbose = FALSE)
combined <- FindNeighbors(combined, dims = 1:20, verbose = FALSE)
combined <- FindClusters(combined, resolution = 0.5, verbose = FALSE)
combined <- RunUMAP(combined, dims = 1:20, verbose = FALSE)

markers <- cfg$analysis$key_compartments
combined$score_mesenchymal <- marker_score(combined, markers$mesenchymal$markers)
combined$score_macrophage <- marker_score(combined, markers$macrophage$markers)
combined$score_endothelial <- marker_score(combined, markers$endothelial$markers)

score_df <- combined@meta.data |>
  tibble::rownames_to_column("cell") |>
  mutate(
    compartment_call = case_when(
      score_mesenchymal >= pmax(score_macrophage, score_endothelial, na.rm = TRUE) & score_mesenchymal > 0.25 ~ "mesenchymal_HSC_myofibroblast",
      score_macrophage >= pmax(score_mesenchymal, score_endothelial, na.rm = TRUE) & score_macrophage > 0.25 ~ "macrophage_monocyte",
      score_endothelial >= pmax(score_mesenchymal, score_macrophage, na.rm = TRUE) & score_endothelial > 0.25 ~ "endothelial",
      TRUE ~ "other_or_unresolved"
    )
  )
combined$compartment_call <- score_df$compartment_call[match(colnames(combined), score_df$cell)]

qc_filtered <- combined@meta.data |>
  tibble::rownames_to_column("cell") |>
  group_by(disease_state, donor, sample_id, fraction, compartment_call) |>
  summarise(
    cells = n(),
    median_genes = median(nFeature_RNA),
    median_umis = median(nCount_RNA),
    median_percent_mt = median(percent.mt),
    median_percent_ribo = median(percent.ribo),
    median_percent_hb = median(percent.hb),
    median_log10_genes_per_umi = median(log10_genes_per_umi),
    .groups = "drop"
  )
safe_write(qc_filtered, file.path(cfg$paths$tables_dir, "qc_filtered_by_library_compartment.csv"))

p_umap_disease <- DimPlot(combined, reduction = "umap", group.by = "disease_state", raster = TRUE) +
  ggtitle("GSE136103 human liver cells by disease state") + theme_project()
p_umap_compartment <- DimPlot(combined, reduction = "umap", group.by = "compartment_call", raster = TRUE) +
  ggtitle("Marker-supported required compartments") + theme_project()
save_plot(p_umap_disease, file.path(cfg$paths$figures_dir, "umap_disease_state.png"), 7, 5)
save_plot(p_umap_compartment, file.path(cfg$paths$figures_dir, "umap_required_compartments.png"), 8, 5)

marker_panel <- unique(unlist(lapply(markers, `[[`, "markers")))
marker_panel <- intersect(marker_panel, rownames(combined))
dot <- DotPlot(combined, features = marker_panel, group.by = "compartment_call") +
  RotatedAxis() +
  ggtitle("Marker validation for required compartments") +
  theme_project() +
  theme(axis.text.x = element_text(size = 8, angle = 45, hjust = 1))
save_plot(dot, file.path(cfg$paths$figures_dir, "required_compartment_marker_dotplot.png"), 13, 5.5)

Idents(combined) <- "compartment_call"
de_results <- list()
for (compartment in c("mesenchymal_HSC_myofibroblast", "macrophage_monocyte", "endothelial")) {
  cells <- WhichCells(combined, idents = compartment)
  if (length(cells) < 50) next
  sub <- subset(combined, cells = cells)
  if (length(unique(sub$disease_state)) < 2) next
  Idents(sub) <- "disease_state"
  res <- FindMarkers(
    sub,
    ident.1 = cfg$analysis$disease_contrast$case,
    ident.2 = cfg$analysis$disease_contrast$reference,
    test.use = "wilcox",
    logfc.threshold = 0.1,
    min.pct = 0.1
  ) |>
    tibble::rownames_to_column("gene") |>
    mutate(compartment = compartment, contrast = "cirrhotic_vs_healthy_cell_level")
  de_results[[compartment]] <- res
}
de_tbl <- bind_rows(de_results)
safe_write(de_tbl, file.path(cfg$paths$tables_dir, "compartment_de_cell_level_exploratory.csv"))

avg <- AverageExpression(combined, group.by = c("disease_state", "compartment_call"), assays = "RNA", layer = "data")$RNA
avg_tbl <- as.data.frame(as.matrix(avg)) |> tibble::rownames_to_column("gene")
safe_write(avg_tbl, file.path(cfg$paths$tables_dir, "average_expression_by_disease_compartment.csv"))

emb <- Embeddings(combined, "umap") |>
  as.data.frame() |>
  tibble::rownames_to_column("cell") |>
  left_join(combined@meta.data |> tibble::rownames_to_column("cell"), by = "cell")
safe_write(emb, file.path(cfg$paths$dashboard_data_dir, "umap_metadata.csv"))

saveRDS(combined, file.path(cfg$paths$processed_dir, "gse136103_compact_seurat.rds"))
message("Seurat compact analysis complete.")
