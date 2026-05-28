# Nextflow Demo Run Summary

- Dataset: gse136103_demo
- Cells: 480
- Genes: 14718
- Total counts: 2390617
- QC pass cells: 480
- Disease states represented: healthy;cirrhotic
- Compartments represented: endothelial;macrophage_monocyte;mesenchymal_HSC_myofibroblast;other_or_unresolved
- Embedding generated: UMAP
- Top demo-ranked candidate: TIMP1

## What The Demo Covers

- Data ingest from a 10x-style matrix and samplesheet.
- Metadata attachment and basic label checks.
- Cell-level QC flags for detected genes and mitochondrial percentage.
- PCA or UMAP-style embedding, depending on installed R packages.
- Candidate-level disease direction screen using a Wilcoxon test.
- Small pathway-theme summary for stromal, vascular, and macrophage candidates.
- Ranked demo candidate table.

This is a compact contract test, not a replacement for the full Seurat workflow. Its purpose is to show that the analysis stages can be represented in a dataset-independent Nextflow pipeline and scaled later to full datasets on AWS Batch.

## Output Files

- `demo_qc_summary.csv`
- `demo_cell_qc_flags.csv`
- `demo_compartment_summary.csv`
- `demo_embedding.csv` and `demo_embedding_plot.png`
- `demo_candidate_de.csv` and `demo_candidate_de_plot.png`
- `demo_pathway_summary.csv`
- `demo_ranked_candidates.csv`
