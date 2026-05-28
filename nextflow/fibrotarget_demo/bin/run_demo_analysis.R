suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(Matrix)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1]]
}

samplesheet_path <- get_arg("--samplesheet")
outdir <- get_arg("--outdir", ".")
repo_root <- normalizePath(get_arg("--repo-root", file.path(dirname(samplesheet_path), "..", "..", "..")), mustWork = TRUE)
samplesheet <- read_csv(samplesheet_path, show_col_types = FALSE)
row <- samplesheet[1, ]

resolve_path <- function(path) normalizePath(file.path(repo_root, path), mustWork = TRUE)
matrix <- Matrix::readMM(resolve_path(row$matrix))
features <- read_tsv(resolve_path(row$features), col_names = FALSE, show_col_types = FALSE)
barcodes <- read_tsv(resolve_path(row$barcodes), col_names = FALSE, show_col_types = FALSE)
metadata <- read_csv(resolve_path(row$metadata), show_col_types = FALSE)
metadata <- metadata |>
  mutate(
    disease_state = factor(disease_state, levels = c("healthy", "cirrhotic")),
    cell = barcode
  )

gene_names <- if (ncol(features) >= 2) features[[2]] else features[[1]]
rownames(matrix) <- make.unique(as.character(gene_names))
colnames(matrix) <- as.character(barcodes[[1]])

candidate_genes <- c("SMOC2", "TIMP1", "PLVAP", "ACKR1", "COL1A1", "COL3A1", "PDGFRA", "PDGFRB", "TREM2", "CD9", "SPP1", "GPNMB")
present <- tibble(
  gene = candidate_genes,
  present_in_demo = candidate_genes %in% rownames(matrix),
  total_counts = vapply(candidate_genes, function(gene) {
    if (!gene %in% rownames(matrix)) return(0)
    sum(matrix[gene, ])
  }, numeric(1))
)

qc_cell <- metadata |>
  transmute(
    cell,
    sample_id,
    donor,
    disease_state,
    compartment_call,
    nCount_RNA,
    nFeature_RNA,
    percent.mt,
    qc_flag = case_when(
      nFeature_RNA < 200 ~ "low_genes",
      percent.mt > 25 ~ "high_mito",
      TRUE ~ "pass"
    )
  )

qc <- tibble(
  sample_id = row$sample_id,
  cells = ncol(matrix),
  genes = nrow(matrix),
  total_counts = sum(matrix),
  median_counts_per_cell = median(Matrix::colSums(matrix)),
  median_genes_per_cell = median(metadata$nFeature_RNA, na.rm = TRUE),
  median_mito_percent = median(metadata$percent.mt, na.rm = TRUE),
  qc_pass_cells = sum(qc_cell$qc_flag == "pass"),
  metadata_rows = nrow(metadata),
  disease_states = paste(sort(unique(metadata$disease_state)), collapse = ";"),
  compartments = paste(sort(unique(metadata$compartment_call)), collapse = ";")
)

comp <- metadata |>
  count(disease_state, compartment_call, name = "cells") |>
  arrange(disease_state, compartment_call)

log_cpm <- log2(t(t(matrix + 0.5) / (Matrix::colSums(matrix) + 1)) * 1e4)
candidate_de <- lapply(candidate_genes[candidate_genes %in% rownames(log_cpm)], function(gene) {
  x <- as.numeric(log_cpm[gene, ])
  group <- metadata$disease_state
  healthy <- x[group == "healthy"]
  cirrhotic <- x[group == "cirrhotic"]
  p <- if (length(healthy) > 1 && length(cirrhotic) > 1) wilcox.test(cirrhotic, healthy)$p.value else NA_real_
  tibble(
    gene = gene,
    mean_healthy = mean(healthy, na.rm = TRUE),
    mean_cirrhotic = mean(cirrhotic, na.rm = TRUE),
    log2FC_cirrhotic_vs_healthy = mean(cirrhotic, na.rm = TRUE) - mean(healthy, na.rm = TRUE),
    p_value = p
  )
}) |>
  bind_rows() |>
  mutate(
    p_adj = p.adjust(p_value, method = "BH"),
    direction = case_when(
      log2FC_cirrhotic_vs_healthy > 0 ~ "higher_in_cirrhosis",
      log2FC_cirrhotic_vs_healthy < 0 ~ "lower_in_cirrhosis",
      TRUE ~ "no_change"
    )
  ) |>
  arrange(p_adj, desc(abs(log2FC_cirrhotic_vs_healthy)))

pathway_sets <- list(
  matrix_stromal = c("COL1A1", "COL3A1", "TIMP1", "SMOC2", "PDGFRA", "PDGFRB"),
  vascular_remodeling = c("PLVAP", "ACKR1"),
  macrophage_injury = c("TREM2", "CD9", "SPP1", "GPNMB")
)
pathway_summary <- bind_rows(lapply(names(pathway_sets), function(name) {
  genes <- intersect(pathway_sets[[name]], candidate_de$gene)
  sub <- candidate_de |> filter(gene %in% genes)
  tibble(
    pathway_theme = name,
    genes_tested = length(genes),
    genes_higher_in_cirrhosis = sum(sub$log2FC_cirrhotic_vs_healthy > 0, na.rm = TRUE),
    best_gene = if (nrow(sub) > 0) sub$gene[which.min(sub$p_adj)] else NA_character_,
    best_fdr = if (nrow(sub) > 0) min(sub$p_adj, na.rm = TRUE) else NA_real_
  )
}))

candidate_rank <- candidate_de |>
  left_join(present, by = "gene") |>
  mutate(
    demo_score = present_in_demo * 10 +
      pmax(log2FC_cirrhotic_vs_healthy, 0) * 5 +
      if_else(log2FC_cirrhotic_vs_healthy > 0, -log10(pmax(p_adj, 1e-300)), 0),
    demo_score = if_else(is.finite(demo_score), demo_score, 0)
  ) |>
  arrange(desc(demo_score)) |>
  mutate(rank = row_number()) |>
  select(rank, gene, demo_score, direction, log2FC_cirrhotic_vs_healthy, p_adj, present_in_demo, total_counts)

gene_var <- apply(as.matrix(log_cpm), 1, var)
top_var <- order(gene_var, decreasing = TRUE)[seq_len(min(500, nrow(log_cpm)))]
pcs <- prcomp(t(as.matrix(log_cpm[top_var, , drop = FALSE])), center = TRUE, scale. = FALSE)$x[, 1:2, drop = FALSE]
embedding <- metadata |>
  transmute(cell, disease_state, compartment_call) |>
  mutate(embedding_1 = pcs[, 1], embedding_2 = pcs[, 2], embedding_method = "PCA")
if (requireNamespace("uwot", quietly = TRUE) && ncol(log_cpm) >= 20) {
  set.seed(7)
  umap <- uwot::umap(t(as.matrix(log_cpm[top_var, , drop = FALSE])), n_neighbors = 15, min_dist = 0.25, verbose = FALSE)
  embedding$embedding_1 <- umap[, 1]
  embedding$embedding_2 <- umap[, 2]
  embedding$embedding_method <- "UMAP"
}

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
write_csv(qc, file.path(outdir, "demo_qc_summary.csv"))
write_csv(qc_cell, file.path(outdir, "demo_cell_qc_flags.csv"))
write_csv(comp, file.path(outdir, "demo_compartment_summary.csv"))
write_csv(present, file.path(outdir, "demo_candidate_gene_presence.csv"))
write_csv(candidate_de, file.path(outdir, "demo_candidate_de.csv"))
write_csv(pathway_summary, file.path(outdir, "demo_pathway_summary.csv"))
write_csv(candidate_rank, file.path(outdir, "demo_ranked_candidates.csv"))
write_csv(embedding, file.path(outdir, "demo_embedding.csv"))

ggsave(
  file.path(outdir, "demo_qc_plot.png"),
  qc_cell |>
    ggplot(aes(nFeature_RNA, percent.mt, color = qc_flag)) +
    geom_point(alpha = 0.7, size = 1.8) +
    theme_minimal(base_size = 11) +
    labs(title = "Demo QC review", x = "Detected genes", y = "Mitochondrial percent", color = "QC flag"),
  width = 7,
  height = 4.5,
  dpi = 180
)

ggsave(
  file.path(outdir, "demo_embedding_plot.png"),
  embedding |>
    ggplot(aes(embedding_1, embedding_2, color = compartment_call, shape = disease_state)) +
    geom_point(alpha = 0.8, size = 1.9) +
    theme_minimal(base_size = 11) +
    labs(title = paste(unique(embedding$embedding_method), "review embedding"), x = "Dimension 1", y = "Dimension 2", color = "Compartment", shape = "Disease"),
  width = 7,
  height = 4.8,
  dpi = 180
)

ggsave(
  file.path(outdir, "demo_candidate_de_plot.png"),
  candidate_rank |>
    slice_head(n = 12) |>
    mutate(gene = reorder(gene, log2FC_cirrhotic_vs_healthy)) |>
    ggplot(aes(log2FC_cirrhotic_vs_healthy, gene, fill = direction)) +
    geom_col() +
    theme_minimal(base_size = 11) +
    labs(title = "Demo candidate direction screen", x = "log2 fold change, cirrhotic vs healthy", y = NULL, fill = "Direction"),
  width = 7,
  height = 4.8,
  dpi = 180
)

summary_lines <- c(
  "# Nextflow Demo Run Summary",
  "",
  paste0("- Dataset: ", row$sample_id),
  paste0("- Cells: ", qc$cells),
  paste0("- Genes: ", qc$genes),
  paste0("- Total counts: ", qc$total_counts),
  paste0("- QC pass cells: ", qc$qc_pass_cells),
  paste0("- Disease states represented: ", qc$disease_states),
  paste0("- Compartments represented: ", qc$compartments),
  paste0("- Embedding generated: ", unique(embedding$embedding_method)),
  paste0("- Top demo-ranked candidate: ", candidate_rank$gene[[1]]),
  "",
  "## What The Demo Covers",
  "",
  "- Data ingest from a 10x-style matrix and samplesheet.",
  "- Metadata attachment and basic label checks.",
  "- Cell-level QC flags for detected genes and mitochondrial percentage.",
  "- PCA or UMAP-style embedding, depending on installed R packages.",
  "- Candidate-level disease direction screen using a Wilcoxon test.",
  "- Small pathway-theme summary for stromal, vascular, and macrophage candidates.",
  "- Ranked demo candidate table.",
  "",
  "This is a compact contract test, not a replacement for the full Seurat workflow. Its purpose is to show that the analysis stages can be represented in a dataset-independent Nextflow pipeline and scaled later to full datasets on AWS Batch.",
  "",
  "## Output Files",
  "",
  "- `demo_qc_summary.csv`",
  "- `demo_cell_qc_flags.csv`",
  "- `demo_compartment_summary.csv`",
  "- `demo_embedding.csv` and `demo_embedding_plot.png`",
  "- `demo_candidate_de.csv` and `demo_candidate_de_plot.png`",
  "- `demo_pathway_summary.csv`",
  "- `demo_ranked_candidates.csv`"
)
writeLines(summary_lines, file.path(outdir, "demo_run_summary.md"))
