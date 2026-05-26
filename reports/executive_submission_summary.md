# Executive Submission Summary

## Project

**FibroTarget-Liver** is a reproducible single-cell workflow for human liver fibrosis, MASH, and cirrhosis target discovery. The primary analysis uses GSE136103 human liver count matrices, not a precomputed object. The published Ramachandran Seurat object is used only as a reference for annotation refinement.

The workflow moves from metadata curation to QC, Seurat preprocessing, marker-supported compartment annotation, donor-level pseudobulk differential expression, pathway analysis, target scoring, external validation, and translational interpretation.

## What Was Done

Primary discovery uses human liver tissue only. Blood and mouse libraries are excluded from the main contrast to avoid tissue and species confounding, then analyzed separately as secondary validation checks.

The three required compartments were recovered:

- HSC/mesenchymal/myofibroblast-like cells: COL1A1, COL3A1, ACTA2, TAGLN, PDGFRA, PDGFRB, LUM, DCN, RGS5
- Macrophage/monocyte cells: TREM2, CD9, SPP1, GPNMB, LST1, C1QA, C1QB, C1QC
- Endothelial cells: ACKR1, PLVAP, VWF, PECAM1, KDR, RAMP2, ENG

Cell-level DE is retained as an exploratory screen. Donor-level pseudobulk DE is the main inferential layer because donor, not cell, is the biological replicate.

## Main Interpretation

Fibrosis signal is strongest in a connected scar niche:

- activated stromal and HSC/myofibroblast-like cells
- scar-associated endothelial programs
- macrophage injury and repair states

The candidate list is intentionally split by use case:

- Diagnostic and pharmacodynamic biomarkers: SMOC2, TIMP1, COL1A1, COL3A1, PLVAP, ACKR1
- Therapeutic hypotheses: PDGFRA, PDGFRB
- Future validation markers: TREM2, SPP1, GPNMB, CD9

The key point is that a strong fibrosis marker is not automatically a strong therapeutic target. Collagens are excellent burden readouts but poor direct targets. PDGFRA/B are more druggable, but safety and tissue selectivity are central. Macrophage candidates are biologically compelling but need macrophage-focused validation before nomination.

## Prioritization

The scoring model now uses component-level evidence:

- disease association
- donor-level pseudobulk support
- compartment specificity
- pathway coherence
- external validation
- modality and assayability
- mouse conservation
- safety and specificity penalties
- blood specificity penalty
- therapeutic risk penalty

Scoring tables:

- `reports/tables/ranked_biomarker_target_candidates_translational.csv`
- `reports/tables/target_prioritization_scoring_components.csv`
- `reports/tables/target_prioritization_scoring_method.csv`

## Validation

Validation layers:

- GSE244832: MASH/MASLD HSC-focused validation
- GSE207310: bulk NAFLD/NASH directionality
- GSE136103 blood: circulating marker specificity
- GSE136103 mouse liver: ortholog conservation and preclinical directionality

Blood supports tissue-niche specificity for most stromal, endothelial, and collagen candidates. Mouse fibrotic liver shows the strongest directionality for macrophage-state orthologs, with weaker stromal support in the small two-sample screen.

## What Went Beyond The Assignment

Kept modest:

- Interactive Shiny dashboard
- Standalone Nextflow demo that runs locally
- AWS-ready Nextflow pattern using the same demo contract

## What To Open

- `docs/analysis_walkthrough.md`
- `reports/executive_submission_summary.html`
- `reports/screening_responses/README.md`
- `reports/requirement_traceability.md`
- `reports/tables/ranked_biomarker_target_candidates_translational.csv`
- `dashboard/app.R`
- `nextflow/fibrotarget_demo/README.md`

## Next Steps

The next decisive work is not more ranking. It is validation:

- spatial localization for SMOC2, TIMP1, PLVAP, ACKR1, PDGFRA/B, and macrophage-state markers
- full GSE244832 all-gene object reanalysis on AWS
- macrophage-focused external atlas validation
- pathfindR or ReactomePA active mechanism module
- LIANA/NicheNet/CellChat communication analysis with spatial and perturbation support
- HSC perturbation assays for PDGFRA/B
