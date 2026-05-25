nextflow.enable.dsl = 2

params.input = "${projectDir}/assets/demo_samplesheet.csv"
params.outdir = "${projectDir}/../nf-results"
params.config_yaml = "${projectDir}/../config/project.yaml"
params.validation_gse244832 = "${projectDir}/../data/validation/GSE244832"
params.validation_gse207310 = "${projectDir}/../data/validation/GSE207310"

process CHECK_INPUTS {
  tag "inputs"
  publishDir params.outdir, mode: 'copy'

  input:
  path samplesheet

  output:
  path "input_check.txt"

  script:
  """
  test -s "${samplesheet}"
  echo "Samplesheet present: ${samplesheet}" > input_check.txt
  """
}

process RUN_SEURAT_DISCOVERY {
  tag "seurat"
  publishDir "${params.outdir}/analysis", mode: 'copy'
  cpus 4
  memory '16 GB'

  input:
  path input_check

  output:
  path "reports"
  path "dashboard"

  script:
  """
  cd ${projectDir}/..
  make check
  make curate
  make analyze
  make prioritize
  make dashboard
  cp -R reports ${task.workDir}/reports
  cp -R dashboard ${task.workDir}/dashboard
  """
}

process PREPARE_VALIDATION {
  tag "validation"
  publishDir "${params.outdir}/validation", mode: 'copy'
  cpus 2
  memory '8 GB'

  input:
  path input_check

  output:
  path "validation_tables"

  script:
  """
  cd ${projectDir}/..
  python3 scripts/prepare_validation_datasets.py
  mkdir -p ${task.workDir}/validation_tables
  cp reports/tables/validation_gse244832_candidate_expression_by_condition.csv ${task.workDir}/validation_tables/
  cp reports/tables/validation_gse244832_candidate_expression_by_cluster.csv ${task.workDir}/validation_tables/
  cp reports/tables/validation_gse244832_candidate_expression_by_sample.csv ${task.workDir}/validation_tables/
  cp reports/tables/validation_gse207310_readiness.csv ${task.workDir}/validation_tables/
  """
}

process ENRICH_TARGET_EVIDENCE {
  tag "public-evidence"
  publishDir "${params.outdir}/target_evidence", mode: 'copy'
  cpus 1
  memory '2 GB'

  input:
  path input_check

  output:
  path "target_public_evidence.csv"
  path "ranked_biomarker_target_candidates_enriched.csv"

  script:
  """
  cd ${projectDir}/..
  python3 scripts/enrich_target_evidence.py
  Rscript -e "library(readr); library(dplyr); c <- read_csv('reports/tables/ranked_biomarker_target_candidates.csv', show_col_types=FALSE); e <- read_csv('reports/tables/target_public_evidence.csv', show_col_types=FALSE); write_csv(left_join(c, e, by='gene'), 'reports/tables/ranked_biomarker_target_candidates_enriched.csv')"
  cp reports/tables/target_public_evidence.csv ${task.workDir}/
  cp reports/tables/ranked_biomarker_target_candidates_enriched.csv ${task.workDir}/
  """
}

workflow {
  samplesheet = Channel.fromPath(params.input)
  checked = CHECK_INPUTS(samplesheet)
  RUN_SEURAT_DISCOVERY(checked)
  PREPARE_VALIDATION(checked)
  ENRICH_TARGET_EVIDENCE(checked)
}
