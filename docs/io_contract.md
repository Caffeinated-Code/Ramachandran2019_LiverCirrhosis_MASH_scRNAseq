# Input And Output Contract

This document defines the expected inputs and outputs so the repository can be reused beyond the original public dataset.

## Primary Input

The primary public analysis uses GSE136103 processed count matrices from GEO:

```text
GSM*_barcodes.tsv.gz
GSM*_genes.tsv.gz
GSM*_matrix.mtx.gz
```

The pipeline builds sample metadata from file names and writes:

```text
data/metadata/gse136103_sample_manifest.csv
data/metadata/gse136103_dataset_summary.csv
data/metadata/gse136103_archive_files.csv
```

## Proprietary Input Pattern

For proprietary liver disease datasets, provide:

- Matrix Market or 10x-style counts
- barcodes/cell IDs
- features/genes
- sample metadata with donor, disease state, tissue, assay type, and batch fields

The demo samplesheet in `nextflow/assets/demo_samplesheet.csv` shows the expected shape.

## Required Metadata Fields

Minimum fields:

- `sample_id`
- `donor`
- `disease_state`
- `tissue`
- `species`
- `assay_type`

Recommended fields:

- fibrosis stage
- MASLD/MASH category
- biopsy source
- sequencing chemistry
- sex
- age
- batch
- clinical covariates

## Main Outputs

Small, inspectable outputs:

- `reports/tables/qc_by_library.csv`
- `reports/tables/qc_filtered_by_library_compartment.csv`
- `reports/tables/compartment_de_cell_level_exploratory.csv`
- `reports/tables/pseudobulk_de_by_refined_state.csv`
- `reports/tables/pseudobulk_priority_gene_de.csv`
- `reports/tables/hallmark_pathway_enrichment.csv`
- `reports/tables/ranked_biomarker_target_candidates_translational.csv`
- `reports/tables/validation_gse244832_candidate_expression_by_condition.csv`
- `reports/tables/gse244832_hsc_candidate_validation.csv`
- `reports/tables/target_translational_evidence.csv`
- `reports/tables/target_mouse_orthology.csv`

Figures:

- `reports/figures/umap_disease_state.png`
- `reports/figures/umap_required_compartments.png`
- `reports/figures/umap_refined_cell_states.png`
- `reports/figures/required_compartment_marker_dotplot.png`
- `reports/figures/pseudobulk_priority_gene_de.png`
- `reports/figures/gse244832_hsc_validation_heatmap.png`
- `reports/figures/ranked_candidate_scores.png`

Dashboard:

- `dashboard/app.R`
- `dashboard/data/*.csv`

## Large Derived Outputs

Large analysis objects are local-only:

- `data/processed/gse136103_compact_seurat.rds`
- extracted validation matrices
- raw GEO archives

In AWS, these should live in S3 or EFS, not Git.
