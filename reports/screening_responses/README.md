# Written Screening Responses

These responses are written from the same framework I would use in a liver disease target-discovery program: start with clean metadata, protect true disease biology during preprocessing, test at the donor level, and only nominate targets after asking whether the signal is biologically coherent, assayable, conserved, and safe enough to move toward experiments.

My prior work at CAMP4 shaped that lens. CAMP4’s public platform focuses on regulatory RNA biology and ASO-based gene upregulation, with programs in CNS and metabolic disease. In that kind of target-prioritization setting, a gene is not interesting just because it changes. It has to connect to disease biology, the right cell type, a plausible modality, a measurable biomarker strategy, and a realistic translational path.

## 01. Dataset Curation And Fibrosis-Stage Harmonization

I would start with a sample manifest before touching integration. Each dataset needs donor ID, tissue source, assay type, species, disease label, fibrosis label, histology system, biopsy source, chemistry, batch, and available covariates. I would keep the original labels and add harmonized labels in separate fields, so the analysis never loses the source-study context.

For fibrosis labels, I would use two levels. The first is a practical harmonized label: no or mild fibrosis, significant fibrosis, advanced fibrosis, and cirrhosis. The second preserves the original label, such as METAVIR F0-F4, Kleiner grade, cirrhosis/non-cirrhosis, NAFL/NASH, or MASL/MASH. I would not force incomplete metadata into a false F0-F4 scale.

Then I would check whether labels match expected biology. In advanced fibrosis I expect collagen and matrix programs in stromal cells, scar-associated macrophage states, endothelial remodeling, ductular reaction, and hepatocyte stress. If the clinical label and biology disagree, I would not quietly drop the sample. I would flag it for sensitivity analysis.

This is similar to how I think about metabolic liver disease target prioritization from my CAMP4 experience. The disease label is only the starting point. The decision becomes stronger when the label, tissue biology, cell-state signal, and translational hypothesis all point in the same direction.

## 02. QC And Preprocessing For Liver scRNA-seq/snRNA-seq

QC should remove technical failures without deleting diseased cells. In liver fibrosis, stressed cells are often part of the phenotype. I would inspect nUMI, nGene, mitochondrial fraction, ribosomal fraction, ambient RNA, doublet probability, and per-sample cell yield. Thresholds should be sample-aware because cirrhotic tissue, fatty liver tissue, and nuclei data can look different from healthy scRNA-seq.

For scRNA-seq, high mitochondrial fraction can mean dying cells, but it can also track stressed hepatocytes or injured tissue. For snRNA-seq, mitochondrial fraction is less informative, and intronic read capture matters more. I would set initial thresholds, then check whether key disease populations disappear after filtering.

I would use doublet detection and ambient RNA correction where practical. The important check is biological: if activated stellate cells, scar-associated macrophages, or endothelial remodeling states vanish after QC, I would revisit the cutoff instead of assuming the filter was correct.

For a drug-discovery program, I would also keep a QC decision log. Downstream target calls are only as good as the sample and cell-state decisions that produced them.

## 03. Integration Without Erasing Fibrosis Biology

The main risk in integration is correcting away the biology we care about. I would first analyze each dataset separately and confirm the expected disease programs before integration. Then I would integrate for visualization and annotation using Seurat integration, Harmony, scVI, or a similar method.

I would not use fibrosis stage itself as a batch variable. I would check UMAPs and PCA loadings by donor, assay, chemistry, tissue source, and disease. I would also compare differential expression before and after integration. If integration removes COL1A1/COL3A1 stromal programs, TREM2/CD9 macrophage states, or PLVAP/ACKR1 endothelial remodeling, the integration is too aggressive for discovery.

My preference is to use integration for cell-state alignment and annotation, then use donor-aware testing on raw counts or appropriately normalized counts for inference. The final disease signal should not depend only on an integrated embedding.

This mirrors how I would approach a target-prioritization project in industry. Integration should make biology easier to interpret, not make every sample look artificially similar.

## 04. Cell-Type Annotation And Validation In Fibrotic Liver

A cluster expressing COL1A1, COL3A1, ACTA2, TAGLN, PDGFRB, LUM, and DCN and enriched in F3/F4 samples is clearly fibrogenic, but I would not immediately call it one pure cell type. It could contain activated hepatic stellate cells, portal fibroblasts, vascular mural cells, pericyte-like cells, or myofibroblast-like states.

I would validate it in layers:

- quiescent HSC and vitamin A-associated markers
- portal fibroblast-associated markers such as THY1 and elastin or matrix programs
- pericyte and vascular mural markers such as RGS5 and MCAM
- activated myofibroblast markers such as ACTA2, TAGLN, COL1A1, and TIMP1
- donor distribution across multiple F3/F4 samples
- spatial, histology, or protein evidence if available

My label would be conservative at first: activated mesenchymal or HSC/myofibroblast-like stromal state. I would only split it into finer labels if marker evidence, donor support, and spatial context support the separation.

For target discovery, this distinction matters. A marker of activated stromal biology can be useful, but a therapeutic hypothesis may change depending on whether the signal is mainly HSC, portal fibroblast, pericyte, or vascular-associated.

## 05. Donor-Aware Differential Expression

Simple cell-level differential expression is risky because cells are not independent biological replicates. A dataset with many cells from one donor can dominate the p-value. That creates false confidence.

I would use pseudobulk differential expression when donor or sample metadata support it. Cells are aggregated by donor, condition, and cell type or cell state. Then a bulk RNA-seq model such as edgeR, DESeq2, or limma-voom can test disease effects using donor-level replication.

If donor count is small, I would emphasize effect size, donor consistency, and confidence intervals. Cell-level DE can still help generate hypotheses, but it should not be the basis for target nomination.

This is the same reasoning I would apply in a metabolic liver disease program. If a candidate is going to drive experimental follow-up, I want to know that the signal appears across donors, not just across thousands of cells from one sample.

## 06. ML-Based Biomarker Prioritization

With 300 candidate genes and limited donors, I would start with a transparent scoring model. It is easier to explain, audit, and adjust with biology.

The score would include:

- disease effect size
- donor consistency
- cell-type specificity
- pathway support
- validation in external datasets
- secreted, surface, receptor, or enzyme status
- druggability and assayability
- mouse conservation
- safety or tissue-specificity risk

I would use ML when there are enough datasets to support it. For example, a model could classify fibrosis stage from cell-type pseudobulk signatures, then identify genes that contribute consistently across folds and external datasets. I would still biologically check the final list.

My CAMP4 experience makes me think about modality early. A candidate can be statistically strong and still be a poor target. For an ASO or regulatory RNA strategy, the direction of modulation matters. For a secreted biomarker, assayability and disease specificity matter. For a receptor target, cell specificity and safety matter. The prioritization model should reflect those differences.

## 07. Cell-Cell Communication And Mechanism Discovery

I would analyze ligand-receptor communication among scar-associated macrophages, activated mesenchymal cells, endothelial cells, cholangiocytes, and injured hepatocytes. Tools such as CellPhoneDB, NicheNet, LIANA, or CellChat can generate useful hypotheses.

The pitfall is overinterpretation. Ligand-receptor tools infer possible communication from expression. They do not prove contact, directionality, protein abundance, secretion, receptor activation, or functional effect.

I would prioritize interactions only when:

- the sender and receiver cell states are disease-enriched
- ligand and receptor are expressed across enough donors
- the interaction fits pathway evidence
- receiver target genes support the proposed mechanism
- spatial, perturbation, or literature evidence supports the interaction

In liver fibrosis, macrophage-to-stellate and endothelial-to-immune trafficking hypotheses are high value. I would treat them as experiment-generating mechanisms, not final proof.

## 08. Reproducible Pipeline And Delivery Plan

For a 12-16 week project, I would structure the work as a production-style analysis program.

1. Weeks 1-2: dataset inventory, metadata harmonization, access checks, and pipeline skeleton.
2. Weeks 3-4: QC, preprocessing, doublet and ambient RNA handling, and sample-level reports.
3. Weeks 5-6: annotation, reference mapping, marker validation, and disease compartment evaluation.
4. Weeks 7-8: donor-aware DE, pathway analysis, and mechanism analysis.
5. Weeks 9-10: external validation across MASH, fibrosis, and macrophage datasets.
6. Weeks 11-12: target scoring, druggability, conservation, and safety triage.
7. Weeks 13-14: dashboard, reproducible reports, and stakeholder discussion.
8. Weeks 15-16: final documentation, handoff, and next-experiment plan.

The repository should include Docker, `renv`, config files, modular scripts, compact outputs, dashboard-ready files, and clear run instructions. Large data and derived single-cell objects should live in object storage, not Git. In AWS, I would map the same steps to S3, ECR, AWS Batch or ECS, Step Functions, and CloudWatch logs.

I would also build in fast test paths from the beginning: a tiny demo dataset, schema checks, CI-style structure checks, and one local Nextflow run. That way the pipeline is not just scientifically useful, it is also maintainable by the next person who inherits it.
