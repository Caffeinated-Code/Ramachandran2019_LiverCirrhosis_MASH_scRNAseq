# Interview Walkthrough

This document is for rehearsing the repo review with a senior bioinformatics reviewer. Keep the presentation direct. The goal is to walk through the analysis end to end, invite corrections, make edits, then move to the next section.

## Review Loop

For each section:

1. Present the section in 2-4 minutes.
2. Ask: "What would you challenge or clarify here?"
3. Log the feedback in `reports/review_feedback_log.md`.
4. Make the correction in the repo or report.
5. Re-present the corrected section.
6. Move on only after the reviewer is satisfied.

## Fast Review Path

Open these first:

1. `README.md`
2. `reports/executive_submission_summary.html`
3. `reports/requirement_traceability.md`
4. `reports/tables/ranked_biomarker_target_candidates_translational.csv`
5. `reports/tables/pseudobulk_priority_gene_de.csv`
6. `reports/tables/gse244832_focused_object_candidate_summary.csv`
7. `reports/tables/validation_gse207310_candidate_lm_results.csv`
8. `nextflow/fibrotarget_demo/README.md`
9. `reports/nextflow_demo/demo_run_summary.md`

## Data Sources And Download Instructions

Primary dataset:

- GSE136103 GEO record: https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE136103
- Original paper: https://www.nature.com/articles/s41586-019-1631-3
- Repo config: `config/project.yaml`
- Download through the repo:

```bash
make fetch-data
make curate
```

Validation dataset 1:

- GSE244832 GEO record: https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE244832
- Local role: MASH/MASLD HSC and myofibroblast validation
- Repo scripts:

```bash
make validation
make hsc-validation
make gse244832-focused
```

Validation dataset 2:

- GSE207310 GEO record: https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE207310
- Local role: SMOC2 and bulk NAFLD/NASH directionality validation
- Repo script:

```bash
make gse207310-validation
```

Standalone demo:

```bash
make nextflow-demo
```

Demo outputs:

- `reports/nextflow_demo/demo_qc_summary.csv`
- `reports/nextflow_demo/demo_compartment_summary.csv`
- `reports/nextflow_demo/demo_candidate_gene_presence.csv`
- `reports/nextflow_demo/demo_run_summary.md`

## Section 1: Opening Frame

What to say:

> I built this as an end-to-end liver fibrosis single-cell target discovery workflow. The analysis starts with GSE136103, identifies fibrosis-associated cell states, runs donor-aware differential expression, performs pathway analysis, ranks biomarker and target candidates, validates priority candidates in GSE244832 and GSE207310, and packages the results as tables, figures, an HTML report, a Shiny dashboard, and a local/AWS Nextflow demo.

Then show:

- `README.md`
- `reports/executive_submission_summary.html`
- `reports/requirement_traceability.md`

Key point:

> The repo is meant to be easy to review first and easy to rerun second.

Ask for feedback:

> Is the positioning clear enough, or should I state the scientific question more directly?

## Section 2: Requirement Coverage

What to say:

> Before going into the biology, I mapped the assignment outcomes to concrete repo artifacts. This keeps the review grounded. The traceability table shows where QC, annotation, DE, pathway analysis, prioritization, validation, written responses, and reproducibility are handled.

Then show:

- `reports/requirement_traceability.md`

Key point:

> This avoids making the reviewer hunt for evidence.

Expected challenge:

> Did you do everything asked, or did you mostly build infrastructure?

Answer:

> Both. The analysis outcomes are implemented and tracked. The infrastructure is there to make the work reproducible and extensible.

## Section 3: Dataset Strategy

What to say:

> The primary dataset was specified by the assignment: GSE136103. I used it for discovery because it directly profiles healthy and cirrhotic human liver at single-cell resolution. I used GSE244832 for validation because it is MASLD/MASH-focused and HSC-centered. I used GSE207310 because it gives bulk liver RNA-seq support for NAFLD/NASH directionality and SMOC2 biology.

Then show:

- `config/project.yaml`
- `docs/validation_datasets.md`

Caveat:

> Cirrhosis and MASH fibrosis overlap but are not identical. I treat GSE244832 and GSE207310 as validation and directionality checks, not as proof that every cirrhosis-derived candidate is a MASH therapeutic target.

## Section 4: Preprocessing And QC

What to say:

> The preprocessing uses Seurat locally. Each library is loaded from GEO count matrices, sample metadata is curated, cells are filtered by gene count and mitochondrial fraction, and the merged object is normalized, scaled, clustered, and embedded with UMAP.

Then show:

- `workflow/03_compact_analysis.R`
- `reports/tables/qc_by_library.csv`
- `reports/tables/qc_filtered_by_library_compartment.csv`

Caveat:

> QC in fibrotic liver should avoid removing stressed disease biology too aggressively. I used a conservative mitochondrial threshold and preserved the limitation in the report.

## Section 5: Cell Annotation

What to say:

> I first recovered the required compartments using marker programs: HSC/myofibroblast, macrophage/monocyte, and endothelial. Then I used the published Ramachandran Seurat annotation object as a reference layer for refined labels.

Then show:

- `reports/figures/required_compartment_marker_dotplot.png`
- `reports/figures/umap_refined_cell_states.png`
- `reports/tables/refined_cluster_annotations.csv`

Key point:

> The annotation is intentionally conservative. I did not overclaim portal fibroblast versus activated HSC subtype resolution where the compact run cannot support it.

## Section 6: Differential Expression

What to say:

> Cell-level DE is included as an exploratory screen. The main inference is donor-level pseudobulk by refined cell state. This matters because cells from the same donor are not independent replicates.

Then show:

- `workflow/08_pseudobulk_de.R`
- `reports/tables/pseudobulk_de_by_refined_state.csv`
- `reports/tables/pseudobulk_priority_gene_de.csv`

Key result:

> HSC/myofibroblast pseudobulk supports COL1A1, COL3A1, TIMP1, PDGFRA, PLVAP, and ACKR1 in cirrhosis. Endothelial pseudobulk strongly supports ACKR1.

Caveat:

> PLVAP and ACKR1 in HSC-like states need careful interpretation because scar tissue can create mixed niche signal, ambient RNA, or doublet remnants.

## Section 7: Prioritization

What to say:

> I used a transparent rule-based score because the dataset size and donor count do not justify treating this as a black-box prediction problem. The score considers disease association, compartment specificity, donor-aware support, pathway support, external validation, modality, mouse conservation, tractability, and safety.

Then show:

- `workflow/04_prioritize_targets.R`
- `reports/tables/ranked_biomarker_target_candidates_translational.csv`

Main interpretation:

> COL1A1 and COL3A1 are strong fibrosis endpoints. SMOC2 and TIMP1 are stronger biomarker or pharmacodynamic candidates. PDGFRA/B are more plausible therapeutic hypotheses. PLVAP/ACKR1 are vascular niche markers. Macrophage candidates need a macrophage-focused validation atlas.

## Section 8: External Validation

GSE244832:

> I used GSE244832 because it is the closest validation match for MASH/MASLD HSC biology. I first streamed candidate summaries, then added a focused Seurat object reanalysis from a candidate-gene matrix.

Show:

- `workflow/09_gse244832_hsc_validation.R`
- `workflow/12_reanalyze_gse244832_focused.R`
- `reports/tables/gse244832_focused_object_candidate_summary.csv`
- `reports/figures/gse244832_focused_object_validation_heatmap.png`

GSE207310:

> I used GSE207310 for bulk liver validation. The module parses GEO phenotype metadata, maps Ensembl IDs to symbols, and tests candidate expression against NASH status and fibrosis grade.

Show:

- `workflow/11_validate_gse207310.R`
- `reports/tables/validation_gse207310_candidate_lm_results.csv`
- `reports/figures/gse207310_candidate_validation_heatmap.png`

## Section 9: Beyond Scope

What to say:

> Beyond the assignment, I added donor-level pseudobulk, reference-informed labels, GSE244832 focused object validation, GSE207310 symbol-level validation, target evidence enrichment, a Shiny dashboard, a rendered HTML report, Docker/renv, and a standalone Nextflow demo that runs locally and maps to AWS.

Then show:

- `reports/executive_submission_summary.html`
- `dashboard/app.R`
- `nextflow/fibrotarget_demo/README.md`
- `reports/nextflow_demo/demo_run_summary.md`

## Section 10: Remaining Limitations

What to say:

> The remaining limitations are specific and actionable. Full all-gene GSE244832 object analysis should run on AWS. Macrophage candidates need a macrophage-focused atlas. Spatial or protein validation is needed for scar-niche localization. Therapeutic nomination needs perturbation assays.

Good closing:

> The current repo gets us from public discovery to a prioritized, validated, reproducible candidate list. The next step is not more ranking; it is targeted validation.
