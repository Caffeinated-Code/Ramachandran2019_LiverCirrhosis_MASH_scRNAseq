suppressPackageStartupMessages({
  library(Seurat)
  library(Matrix)
  library(readr)
  library(dplyr)
})

set.seed(20260524)
obj <- readRDS("data/processed/gse136103_compact_seurat.rds")
cells <- obj@meta.data |>
  tibble::rownames_to_column("cell") |>
  group_by(disease_state, compartment_call) |>
  mutate(.sample_rank = sample.int(n())) |>
  filter(.sample_rank <= 60) |>
  ungroup() |>
  pull(cell)

demo <- subset(obj, cells = cells)
counts <- GetAssayData(demo, assay = "RNA", layer = "counts")
keep_genes <- Matrix::rowSums(counts > 0) >= 3
counts <- counts[keep_genes, ]

out_dir <- "data/demo/gse136103_demo_10x"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
Matrix::writeMM(counts, file.path(out_dir, "matrix.mtx"))
write_tsv(tibble(gene_id = rownames(counts), gene_name = rownames(counts)), file.path(out_dir, "features.tsv"), col_names = FALSE)
write_lines(colnames(counts), file.path(out_dir, "barcodes.tsv"))
write_csv(
  demo@meta.data |>
    tibble::rownames_to_column("barcode") |>
    filter(barcode %in% colnames(counts)) |>
    select(barcode, sample_id, donor, disease_state, fraction, compartment_call, nCount_RNA, nFeature_RNA, percent.mt),
  "data/demo/gse136103_demo_metadata.csv"
)
message("Wrote demo dataset with ", ncol(counts), " cells and ", nrow(counts), " genes.")
