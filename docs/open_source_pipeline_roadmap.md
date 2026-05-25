# Open-Source Pipeline Roadmap

The long-term goal is a widely usable liver disease single-cell pipeline for academia and industry. The current repository now has a local Seurat workflow, prepared validation datasets, a Shiny dashboard, and a Nextflow/AWS scaffold.

## Intended Users

- Academic labs studying MASLD/MASH, cirrhosis, and liver fibrosis
- Translational biology teams validating disease-associated cell states
- Computational biology groups processing proprietary liver scRNA-seq or snRNA-seq
- Target discovery teams integrating single-cell, public validation, and druggability evidence

## Production Direction

The production version should:

1. Accept 10x Cell Ranger, Matrix Market, h5Seurat, h5ad, and sample metadata inputs.
2. Run QC, doublet detection, ambient RNA assessment, normalization, clustering, annotation, and marker validation.
3. Support donor-aware pseudobulk DE as the default inferential mode.
4. Include liver-specific annotation references and marker panels.
5. Validate candidates against prepared public liver datasets.
6. Enrich candidates with Open Targets, ClinicalTrials.gov, ClinVar, orthology, tissue specificity, and protein localization.
7. Emit dashboard-ready outputs, static reports, and machine-readable evidence tables.
8. Run reproducibly on local machines, HPC, and AWS Batch.

## Near-Term Engineering Priorities

- Convert the Nextflow scaffold from `make` wrappers to isolated module processes.
- Add formal samplesheet validation.
- Add h5ad and h5Seurat export modules.
- Add pseudobulk DE with edgeR or DESeq2.
- Add automated release testing on the demo dataset.
- Add documentation pages with example outputs and interpretation guidance.
- Add AWS Batch deployment documentation with IAM, ECR, S3, and CloudWatch setup.
