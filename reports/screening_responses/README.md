# Written Responses

My working style is simple: protect the metadata, test biology at the donor level, and nominate targets only when the signal is coherent, assayable, conserved, and realistic to validate. Prior work in regulatory RNA and target prioritization made me careful about directionality, modality, and translational path, not just differential expression.

## 01. Dataset Curation And Fibrosis-Stage Harmonization

**Original question:** You are given five publicly available human liver scRNA-seq/snRNA-seq datasets from different studies. Each dataset uses different fibrosis labels: some use METAVIR F0-F4, some use cirrhosis/non-cirrhosis, some use NASH/MASH categories, and some have incomplete clinical metadata. How would you curate, harmonize, and validate these datasets before downstream biomarker discovery?

I would start with a sample-level manifest before doing any integration. Each donor gets fields for dataset accession, donor ID, assay type, single-cell versus single-nucleus, tissue source, disease label, fibrosis system, original fibrosis label, harmonized fibrosis bin, etiology, biopsy type, chemistry, sex, age, BMI, diabetes status, and medication history if available.

I would keep scRNA-seq and snRNA-seq as explicit labels. They are not interchangeable. scRNA-seq can overrepresent dissociation-resistant or viable cells and has stronger mitochondrial/ribosomal signatures. snRNA-seq captures frozen tissue and nuclear transcripts better, but can change apparent hepatocyte and stromal signal. A harmonized atlas can include both, but the assay label must remain available for QC, integration, and sensitivity analysis.

I would preserve the original fibrosis labels and add harmonized labels rather than overwriting them:

| Original label type | Keep as | Harmonized analysis label |
|---|---|---|
| METAVIR or similar F0-F4 | `fibrosis_stage_original` | F0-F1, F2-F3, F4 |
| cirrhosis/non-cirrhosis | `clinical_label_original` | non-cirrhotic, cirrhotic |
| MASL/MASH or NAFL/NASH | `disease_activity_original` | metabolic liver disease activity |
| missing stage | `fibrosis_stage_missing_reason` | unknown, excluded from stage-specific DE |

F1-F4 remains valuable because fibrosis is clinically staged and therapeutic development often focuses on F2-F3 or compensated F4. I would not collapse everything into disease versus control unless the dataset forces that. F2+ is especially important because it usually represents clinically meaningful fibrosis and is the population targeted by many MASH trials.

Major multi-dataset liver and single-cell studies generally do three things: keep source labels, add harmonized labels, and validate the harmonization biologically. For example, liver scRNA/snRNA comparisons show assay-specific capture differences, and integration studies use labels such as donor, assay, and batch to avoid confusing technology with disease. I would follow that logic.

Validation checks before biomarker discovery:

```text
clinical metadata
  -> original label preserved
  -> harmonized label added
  -> assay and batch retained
  -> marker biology checked by stage
  -> sensitivity analysis by dataset and assay
```

I would expect advanced fibrosis samples to show stromal collagen programs, activated HSC/myofibroblast states, scar-associated macrophages, endothelial remodeling, ductular reaction, and hepatocyte stress. If a sample labeled F4 looks biologically healthy, I would flag it rather than silently trust or discard it.

## 02. QC And Preprocessing For Liver scRNA-seq/snRNA-seq

**Original question:** For human liver fibrosis scRNA-seq and snRNA-seq datasets, what QC steps would you apply, and how would you avoid removing biologically meaningful stressed or diseased cells while still removing poor-quality cells, doublets, ambient RNA, and batch artifacts?

I would treat QC as a decision log, not a one-line filter. Liver disease samples are fragile, fatty, fibrotic, and inflammatory. Aggressive QC can remove exactly the stressed hepatocytes, activated stromal cells, and injury-associated macrophages we want to study.

Initial QC fields:

- detected genes per cell or nucleus
- UMI counts
- mitochondrial percentage
- ribosomal percentage
- hemoglobin genes
- dissociation stress genes
- ambient RNA score
- doublet score
- sample-level cell yield
- fraction or enrichment strategy, such as CD45 positive or CD45 negative

Typical starting thresholds for scRNA-seq:

- keep cells with at least 200 genes
- remove extreme high-gene or high-UMI outliers after inspecting sample distributions
- start mitochondrial review around 15-25 percent, not as a blind universal cutoff
- require marker sanity checks after filtering

Typical starting thresholds for snRNA-seq:

- mitochondrial percentage is less informative
- intronic/nuclear capture and ambient RNA matter more
- gene-count thresholds may be lower or shifted by chemistry
- hepatocyte nuclei can dominate, so cell-type balance must be checked

Primary dataset example:

In this repo, the compact Seurat workflow uses `min.features = 200` and a default mitochondrial cutoff of 25 percent. That is intentionally conservative. The goal is to remove obvious failures while avoiding deletion of diseased cells that carry stress biology. The result is tracked in:

- `reports/tables/qc_by_library.csv`
- `reports/tables/qc_filtered_by_library_compartment.csv`
- `workflow/03_compact_analysis.R`

How I avoid over-filtering:

```text
apply initial QC
  -> check cell-state recovery
  -> check disease marker retention
  -> check donor/sample balance
  -> adjust only if a filter removes biology or keeps obvious artifacts
```

Doublets and ambient RNA:

- Use tools such as DoubletFinder, scDblFinder, Scrublet, or Solo depending on framework.
- Use SoupX, CellBender, or DecontX when ambient RNA is visible.
- Do not remove every cell with mixed markers automatically in fibrotic tissue. Scar niches can contain doublets, but they can also contain tightly apposed vascular, stromal, and immune cells. I would inspect UMI burden, doublet score, and marker co-expression before removing them.

## 03. Integration Without Erasing Fibrosis Biology

**Original question:** How would you integrate multiple liver fibrosis single-cell datasets while making sure batch correction does not remove real fibrosis-stage biology?

I would first analyze each dataset separately. If a fibrosis program is not visible before integration, integration will not magically make it trustworthy.

Then I would integrate for annotation and visualization, not for final DE. Good options include Seurat RPCA/CCA, Harmony, scVI/scANVI, FastMNN, or LIGER. The choice depends on data scale, assay mix, metadata completeness, and whether labels are available.

Main risk:

```text
dataset A = mostly healthy
dataset B = mostly F3/F4

If we correct "dataset" too strongly,
we may remove real fibrosis biology because dataset and disease are confounded.
```

How I would protect disease signal:

- Keep original counts for DE.
- Integrate in a reduced space for annotation.
- Do not regress out fibrosis stage.
- Include assay type and donor where appropriate.
- Compare marker and pathway signals before and after integration.
- Test whether known fibrosis programs survive: COL1A1/COL3A1 stromal signal, TREM2/CD9 macrophage states, PLVAP/ACKR1 endothelial remodeling.
- Run sensitivity analysis per dataset and per assay type.

Normalization issues:

- LogNormalize is transparent and works for compact Seurat analysis.
- SCTransform can be useful, but if sequencing depth correlates with disease or cell type, it needs careful review.
- For cross-study atlases, I would use integration for embeddings and labels, then use pseudobulk counts for DE.

The final rule:

> Integration should help align equivalent cell types. It should not make F4 liver look healthy.

## 04. Cell-Type Annotation And Validation In Fibrotic Liver

**Original question:** Suppose automated annotation labels a cluster as fibroblast, but the cluster expresses COL1A1, COL3A1, ACTA2, TAGLN, PDGFRB, LUM, DCN, and is strongly enriched in F3/F4 samples. How would you validate whether this represents activated hepatic stellate cells, portal fibroblasts, myofibroblasts, or a mixed stromal state?

I would not accept the automated label as final. That marker set says the cluster is fibrogenic and activated, but it does not prove a pure fibroblast subtype.

I would break the question into layers:

```text
Is it stromal?
  COL1A1, COL3A1, LUM, DCN

Is it activated / myofibroblast-like?
  ACTA2, TAGLN, TIMP1, contractile and matrix-remodeling genes

Is it HSC-like?
  PDGFRB, RGS5, LRAT, RBP1, vitamin A or retinoid-associated programs

Is it portal fibroblast-like?
  THY1, ELN, PI16, COL15A1, portal matrix programs

Is it pericyte or vascular mural-like?
  RGS5, MCAM, CSPG4, NOTCH3

Is it mixed or transitional?
  multiple programs, broad donor distribution, possible doublet or spatial niche signal
```

I would also check whether the cluster appears across several F3/F4 donors. A cluster driven by one donor may be real, but it is weaker for biomarker discovery.

Validation tools:

- marker dot plots and heatmaps
- donor and disease composition
- reference mapping to published liver atlases
- trajectory or activation score within stromal cells
- spatial transcriptomics or RNAscope/IHC if available
- protein validation for PDGFRB, ACTA2, COL1A1, THY1, or other candidate markers

My label would be conservative unless evidence is strong:

> activated mesenchymal or HSC/myofibroblast-like state

That label is honest. It tells the biology without pretending the compact analysis can cleanly separate HSCs, portal fibroblasts, pericytes, and myofibroblasts.

## 05. Donor-Aware Differential Expression And Biomarker Discovery

**Original question:** You want to find genes associated with F2+ fibrosis in macrophages and endothelial cells. Why is simple cell-level differential expression dangerous here, and what statistical strategy would you use instead?

F2+ matters because it is clinically meaningful fibrosis. It is often the point where patients move from early disease into a risk group relevant for drug development, trial enrichment, and longitudinal monitoring. F2-F3 is also the noncirrhotic fibrosis range targeted by approved and late-stage MASH therapies.

Simple cell-level DE is dangerous because cells are not independent patients.

Example:

```text
F2+ macrophages:
  Donor 1: 9,000 cells
  Donor 2: 600 cells
  Donor 3: 400 cells

F0-F1 macrophages:
  Donor 4: 700 cells
  Donor 5: 500 cells
  Donor 6: 450 cells
```

A cell-level test behaves as if it has thousands of replicates. But biologically, it has six donors. If Donor 1 has a strong inflammatory program, the p-value can become extremely small because the same donor is counted thousands of times.

Better strategy:

```text
macrophage cells
  -> aggregate raw counts by donor and fibrosis bin
  -> one pseudobulk profile per donor
  -> model expression ~ F2+ status + covariates
  -> test genes at donor level
```

I would use edgeR, DESeq2, limma-voom, muscat, or dreamlet depending on dataset size and design. For multiple studies, dreamlet is attractive because it supports pseudobulk modeling with random effects and large-scale single-cell data.

Cell-level DE still has a role. It is useful for screening and marker discovery. It should not be the final basis for target nomination.

## 06. AI/ML-Based Biomarker Prioritization

**Original question:** After differential expression and pathway analysis, you have 300 candidate fibrosis-associated genes across hepatic stellate cells, macrophages, endothelial cells, and cholangiocytes. How would you use machine learning or AI to prioritize a short list of biomarkers and therapeutic targets?

I would start with a transparent scoring model, then add ML only when the data can support it.

For a small donor dataset, a rule-based score is stronger than pretending a black-box model has learned biology. The score should include:

- donor-level disease association
- cell-type specificity
- pathway coherence
- external validation
- protein modality
- assayability
- mouse conservation
- blood/tissue specificity
- safety penalties
- clinical and perturbation evidence

If enough datasets are available, I would test supervised models on donor-level features:

- random forest or elastic net for F0-F1 versus F2-F4 classification
- ordinal models for F0-F4 when labels are reliable
- survival or progression models if longitudinal outcomes exist
- cross-study validation, never only random cell-level splits

Random forest can be useful for nonlinear marker panels, but I would train it on donor-level pseudobulk or sample-level module scores, not individual cells. Otherwise the model learns donor identity and cell-capture artifacts.

How AI could help:

- summarize literature and trial evidence
- retrieve perturbation evidence
- generate candidate rationales
- score regulatory plausibility using Enformer or DNABERT-style models when the hypothesis is about gene regulation or variant effects

Where AI should not be overused:

- Enformer and DNABERT do not tell us that perturbing a gene will reverse fibrosis in HSCs.
- Sequence models may add a regulatory-evidence column if we have relevant enhancers, ATAC peaks, variants, or promoter hypotheses.
- They are not substitutes for donor-aware transcriptomics, protein localization, and perturbation assays.

My final shortlist would come from the intersection of statistics, biology, modality, validation, and safety, not from one model score.

## 07. Cell-Cell Interaction And Pathway Mechanism Discovery

**Original question:** This project wants to understand fibrosis progression mechanisms, including scar-associated macrophages, activated stellate cells, and endothelial remodeling. How would you analyze cell-cell communication, and how would you prevent overinterpreting ligand-receptor predictions?

I would use ligand-receptor tools as hypothesis generators. Good tools include LIANA, CellChat, CellPhoneDB, and NicheNet. NicheNet is especially useful when we want to connect a ligand in one cell type to target-gene responses in another cell type.

Sequential plan:

```text
1. Define robust sender and receiver states
2. Run ligand-receptor inference within disease-enriched states
3. Require donor-level expression support
4. Check receiver target genes and pathway activation
5. Add spatial proximity if available
6. Prioritize perturbable interactions
7. Validate in co-culture, organoid, slice culture, or animal model
```

High-value liver fibrosis hypotheses:

- scar-associated macrophage to activated HSC signaling
- endothelial remodeling and immune-cell recruitment
- cholangiocyte or injured hepatocyte signals that activate stromal cells
- matrix-remodeling feedback between stromal cells and macrophages

How I avoid overinterpretation:

- Ligand and receptor mRNA do not prove protein expression.
- Expression does not prove physical contact.
- Physical proximity does not prove signaling.
- A predicted interaction does not prove fibrosis causality.

I would promote only interactions with disease enrichment, donor consistency, receiver-response evidence, pathway support, and a testable experimental plan.

## 08. Reproducible Pipeline And Delivery Plan

**Original question:** If you were asked to deliver this project end-to-end in 12-16 weeks, what would your reproducible analysis pipeline look like? Describe the repository structure, tools, milestones, quality checks, and final deliverables.

I would deliver it as a reproducible, parameterized workflow with one local command and a cloud execution path.

Repository structure:

```text
config/        dataset paths, marker panels, thresholds, scoring weights
workflow/      ordered R analysis modules
scripts/       data prep, validation, evidence enrichment
src/           shared helper functions
nextflow/      local and AWS workflow execution
dashboard/     Shiny app and dashboard-ready data
reports/       HTML summary, tables, figures, written responses
docs/          methods, architecture, reproducibility, AWS notes
data/demo/     tiny tracked demo dataset
```

One-command local run:

```bash
make all
```

Nextflow demo:

```bash
make nextflow-demo
```

Direct Nextflow local run:

```bash
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
nextflow run nextflow/fibrotarget_demo -profile local --outdir reports/nextflow_demo
```

AWS pattern:

```bash
export NXF_WORK=s3://<bucket>/fibrotarget-liver/work
export PIPELINE_IMAGE=<account>.dkr.ecr.us-west-2.amazonaws.com/fibrotarget-liver:latest

nextflow run nextflow/fibrotarget_demo -profile aws \
  --input s3://<bucket>/demo/demo_samplesheet.csv \
  --outdir s3://<bucket>/results/fibrotarget-demo
```

Milestones:

1. Weeks 1-2: dataset inventory, metadata harmonization, pipeline skeleton.
2. Weeks 3-4: QC, preprocessing, doublet and ambient RNA handling.
3. Weeks 5-6: annotation, reference mapping, marker validation.
4. Weeks 7-8: donor-aware DE and pathway analysis.
5. Weeks 9-10: external validation across MASH, fibrosis, and macrophage datasets.
6. Weeks 11-12: target scoring, druggability, conservation, safety triage.
7. Weeks 13-14: dashboard, report, and internal review.
8. Weeks 15-16: final documentation, reproducibility check, handoff.

Quality checks:

- schema validation for metadata
- expected output checks
- no raw data or private files in Git
- toy dataset CI run
- container and `renv` lockfile
- reproducible HTML report
- dashboard smoke test
- Nextflow local demo results tracked

Final deliverables:

- reproducible GitHub repo
- Docker and `renv`
- Nextflow local/AWS demo
- executive HTML report
- ranked candidate table
- validation tables and figures
- Shiny dashboard
- methods walkthrough
- next-experiment plan

## References

- Ramachandran et al. Resolving the fibrotic niche of human liver cirrhosis at single-cell level. Nature, 2019. https://www.nature.com/articles/s41586-019-1631-3
- Ramachandran Seurat object, Edinburgh DataShare. https://datashare.ed.ac.uk/handle/10283/3433
- Andrews et al. Single-cell, single-nucleus, and spatial RNA sequencing of human liver. https://pmc.ncbi.nlm.nih.gov/articles/PMC8948611/
- Single-cell best practices, data integration. https://www.sc-best-practices.org/cellular_structure/integration
- Hoffman et al. dreamlet pseudobulk differential expression. https://pmc.ncbi.nlm.nih.gov/articles/PMC10187426/
- pathfindR active-subnetwork enrichment. https://egeulgen.github.io/pathfindR/
- FDA Rezdiffra snapshot. https://www.fda.gov/drugs/drug-approvals-and-databases/drug-trials-snapshots-rezdiffra
- FDA Wegovy MASH approval. https://www.fda.gov/drugs/news-events-human-drugs/fda-approves-treatment-serious-liver-disease-known-mash
- Avsec et al. Enformer. https://www.nature.com/articles/s41592-021-01252-x
- Ji et al. DNABERT. https://academic.oup.com/bioinformatics/article/37/15/2112/6128680
