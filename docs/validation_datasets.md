# Validation Dataset Preparation

Two validation datasets are prepared locally and summarized into compact review tables.

## GSE244832

Primary use: therapeutic target validation, especially HSC/myofibroblast candidates in MASLD/MASH.

Prepared local format:

```text
data/validation/GSE244832/
  hLIVER_counts.mtx.gz
  hLIVER_genes.csv
  hLIVER_cells.csv
  hLIVER_metadata.csv
```

Although the count file is named `.mtx.gz`, the extracted file is plain Matrix Market text. The validation prep script handles this mismatch.

Tracked summaries:

- `reports/tables/validation_gse244832_candidate_expression_by_condition.csv`
- `reports/tables/validation_gse244832_candidate_expression_by_cluster.csv`
- `reports/tables/validation_gse244832_candidate_expression_by_sample.csv`
- `reports/tables/gse244832_hsc_like_cluster_scores.csv`
- `reports/tables/gse244832_hsc_candidate_validation.csv`
- `reports/tables/gse244832_focused_object_candidate_summary.csv`
- `reports/tables/gse244832_focused_object_compartment_scores.csv`

These tables aggregate the ranked candidate genes across NORMAL, NAFL, and NASH cells. The focused HSC module identifies HSC-like clusters from collagen, stromal, and PDGFR marker expression, then evaluates SMOC2, TIMP1, COL1A1, COL3A1, PDGFRA, and PDGFRB in that compartment. A focused Seurat object module now extracts a candidate-gene matrix from the large source matrix and runs object-level validation locally.

## GSE207310

Primary use: biomarker directionality and SMOC2-related translational support.

Prepared local format:

```text
data/validation/GSE207310/
  GSM*.txt.gz
```

These files are per-sample bulk count tables using Ensembl IDs. The validation module parses GEO phenotype metadata, maps Ensembl IDs to gene symbols with `org.Hs.eg.db`, and tests candidate expression against NASH status and fibrosis grade.

Tracked summaries:

- `reports/tables/validation_gse207310_readiness.csv`
- `reports/tables/validation_gse207310_sample_metadata.csv`
- `reports/tables/validation_gse207310_candidate_expression_by_disease.csv`
- `reports/tables/validation_gse207310_candidate_lm_results.csv`

## Recreate Summaries

```bash
make validation
make hsc-validation
make gse244832-focused
make gse207310-validation
```

Large validation data are excluded from Git. The compact summaries and manifests are tracked.
