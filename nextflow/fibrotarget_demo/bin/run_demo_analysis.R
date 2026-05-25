suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(Matrix)
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

qc <- tibble(
  sample_id = row$sample_id,
  cells = ncol(matrix),
  genes = nrow(matrix),
  total_counts = sum(matrix),
  median_counts_per_cell = median(Matrix::colSums(matrix)),
  metadata_rows = nrow(metadata),
  disease_states = paste(sort(unique(metadata$disease_state)), collapse = ";"),
  compartments = paste(sort(unique(metadata$compartment_call)), collapse = ";")
)

comp <- metadata |>
  count(disease_state, compartment_call, name = "cells") |>
  arrange(disease_state, compartment_call)

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
write_csv(qc, file.path(outdir, "demo_qc_summary.csv"))
write_csv(comp, file.path(outdir, "demo_compartment_summary.csv"))
write_csv(present, file.path(outdir, "demo_candidate_gene_presence.csv"))

summary_lines <- c(
  "# Nextflow Demo Run Summary",
  "",
  paste0("- Dataset: ", row$sample_id),
  paste0("- Cells: ", qc$cells),
  paste0("- Genes: ", qc$genes),
  paste0("- Total counts: ", qc$total_counts),
  paste0("- Disease states represented: ", qc$disease_states),
  paste0("- Compartments represented: ", qc$compartments),
  "",
  "The demo confirms that the standalone Nextflow project can read a 10x-style matrix, attach metadata, summarize disease compartments, and check candidate-gene availability."
)
writeLines(summary_lines, file.path(outdir, "demo_run_summary.md"))
