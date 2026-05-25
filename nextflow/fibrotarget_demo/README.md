# FibroTarget-Liver Nextflow Demo

This standalone Nextflow subproject tests the pipeline contract with a small GSE136103-derived 10x-style demo dataset. It is designed to run locally on a laptop and to map cleanly to AWS Batch for production execution.

## Local Run

From the repository root:

```bash
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
nextflow run nextflow/fibrotarget_demo -profile local --outdir reports/nextflow_demo
```

Equivalent Make target:

```bash
make nextflow-demo
```

## AWS Pattern

```bash
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export NXF_WORK=s3://<bucket>/fibrotarget-liver/work
export PIPELINE_IMAGE=<account>.dkr.ecr.us-west-2.amazonaws.com/fibrotarget-liver:latest

nextflow run nextflow/fibrotarget_demo -profile aws \
  --input s3://<bucket>/demo/demo_samplesheet.csv \
  --outdir s3://<bucket>/results/fibrotarget-demo
```

## Outputs

- `demo_qc_summary.csv`
- `demo_compartment_summary.csv`
- `demo_candidate_gene_presence.csv`
- `demo_run_summary.md`

The tracked outputs in `reports/nextflow_demo/` show the expected result shape.
