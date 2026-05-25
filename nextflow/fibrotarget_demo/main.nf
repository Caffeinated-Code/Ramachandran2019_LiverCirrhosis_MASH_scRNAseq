nextflow.enable.dsl = 2

process RUN_DEMO_ANALYSIS {
  tag "gse136103-demo"
  publishDir params.outdir, mode: 'copy', overwrite: true

  input:
  path samplesheet

  output:
  path "demo_qc_summary.csv"
  path "demo_compartment_summary.csv"
  path "demo_candidate_gene_presence.csv"
  path "demo_run_summary.md"

  script:
  """
  Rscript ${projectDir}/bin/run_demo_analysis.R \
    --samplesheet ${samplesheet} \
    --repo-root ${projectDir}/../.. \
    --outdir .
  """
}

workflow {
  samplesheet = Channel.fromPath(params.input, checkIfExists: true)
  RUN_DEMO_ANALYSIS(samplesheet)
}
