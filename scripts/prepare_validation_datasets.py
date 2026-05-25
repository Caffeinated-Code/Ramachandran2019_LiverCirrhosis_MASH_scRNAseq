#!/usr/bin/env python3
"""Prepare compact validation summaries without loading full validation objects."""

from __future__ import annotations

import csv
import gzip
import json
import math
import tarfile
from collections import defaultdict
from contextlib import contextmanager
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports" / "tables"
METADATA = ROOT / "data" / "metadata"
GSE244 = ROOT / "data" / "validation" / "GSE244832"
GSE207 = ROOT / "data" / "validation" / "GSE207310"


@contextmanager
def open_text_maybe_gzip(path: Path):
    with path.open("rb") as raw:
        magic = raw.read(2)
    if magic == b"\x1f\x8b":
        handle = gzip.open(path, "rt")
    else:
        handle = path.open("rt")
    try:
        yield handle
    finally:
        handle.close()


def read_candidates() -> list[str]:
    path = REPORTS / "ranked_biomarker_target_candidates.csv"
    with path.open() as handle:
        reader = csv.DictReader(handle)
        return [row["gene"] for row in reader]


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def summarize_gse244832(candidates: list[str]) -> None:
    genes = []
    with (GSE244 / "hLIVER_genes.csv").open() as handle:
        for line in handle:
            genes.append(line.strip().strip('"'))

    candidate_rows = {i + 1: gene for i, gene in enumerate(genes) if gene in set(candidates)}
    if not candidate_rows:
        raise RuntimeError("No candidate genes found in GSE244832 gene list")

    cells = []
    with (GSE244 / "hLIVER_metadata.csv").open() as handle:
        reader = csv.DictReader(handle)
        first = reader.fieldnames[0]
        for row in reader:
            cells.append(
                {
                    "cell": row[first],
                    "sample": row["orig.ident"],
                    "condition": row["condition"],
                    "cluster": row["seurat_clusters"],
                    "n_count": float(row["nCount_RNA"]) if row["nCount_RNA"] else math.nan,
                }
            )

    group_totals = defaultdict(int)
    cluster_totals = defaultdict(int)
    sample_totals = defaultdict(int)
    for cell in cells:
        group_totals[cell["condition"]] += 1
        cluster_totals[(cell["condition"], cell["cluster"])] += 1
        sample_totals[(cell["condition"], cell["sample"])] += 1

    group_stats = defaultdict(lambda: {"sum_counts": 0.0, "sum_norm": 0.0, "detected": 0})
    cluster_stats = defaultdict(lambda: {"sum_counts": 0.0, "sum_norm": 0.0, "detected": 0})
    sample_stats = defaultdict(lambda: {"sum_counts": 0.0, "sum_norm": 0.0, "detected": 0})

    with open_text_maybe_gzip(GSE244 / "hLIVER_counts.mtx.gz") as handle:
        for line in handle:
            if line.startswith("%"):
                continue
            parts = line.strip().split()
            if len(parts) != 3:
                continue
            row_i, col_i, value = int(parts[0]), int(parts[1]), float(parts[2])
            if row_i not in candidate_rows:
                continue
            gene = candidate_rows[row_i]
            cell = cells[col_i - 1]
            norm = value / max(cell["n_count"], 1.0) * 10000.0
            gkey = (gene, cell["condition"])
            ckey = (gene, cell["condition"], cell["cluster"])
            skey = (gene, cell["condition"], cell["sample"])
            for stats, key in [(group_stats, gkey), (cluster_stats, ckey), (sample_stats, skey)]:
                stats[key]["sum_counts"] += value
                stats[key]["sum_norm"] += norm
                stats[key]["detected"] += 1

    condition_rows = []
    for gene in candidates:
        for condition in sorted(group_totals):
            total = group_totals[condition]
            stat = group_stats[(gene, condition)]
            condition_rows.append(
                {
                    "dataset": "GSE244832",
                    "gene": gene,
                    "condition": condition,
                    "cells": total,
                    "detected_cells": stat["detected"],
                    "pct_detected": round(stat["detected"] / total * 100, 3) if total else 0,
                    "mean_counts_per_cell": round(stat["sum_counts"] / total, 6) if total else 0,
                    "mean_norm_per_cell": round(stat["sum_norm"] / total, 6) if total else 0,
                }
            )

    cluster_rows = []
    for (gene, condition, cluster), stat in sorted(cluster_stats.items()):
        total = cluster_totals[(condition, cluster)]
        cluster_rows.append(
            {
                "dataset": "GSE244832",
                "gene": gene,
                "condition": condition,
                "cluster": cluster,
                "cells": total,
                "detected_cells": stat["detected"],
                "pct_detected": round(stat["detected"] / total * 100, 3) if total else 0,
                "mean_norm_per_cell": round(stat["sum_norm"] / total, 6) if total else 0,
            }
        )

    sample_rows = []
    for (gene, condition, sample), stat in sorted(sample_stats.items()):
        total = sample_totals[(condition, sample)]
        sample_rows.append(
            {
                "dataset": "GSE244832",
                "gene": gene,
                "condition": condition,
                "sample": sample,
                "cells": total,
                "detected_cells": stat["detected"],
                "pct_detected": round(stat["detected"] / total * 100, 3) if total else 0,
                "mean_norm_per_cell": round(stat["sum_norm"] / total, 6) if total else 0,
            }
        )

    write_csv(
        REPORTS / "validation_gse244832_candidate_expression_by_condition.csv",
        condition_rows,
        ["dataset", "gene", "condition", "cells", "detected_cells", "pct_detected", "mean_counts_per_cell", "mean_norm_per_cell"],
    )
    write_csv(
        REPORTS / "validation_gse244832_candidate_expression_by_cluster.csv",
        cluster_rows,
        ["dataset", "gene", "condition", "cluster", "cells", "detected_cells", "pct_detected", "mean_norm_per_cell"],
    )
    write_csv(
        REPORTS / "validation_gse244832_candidate_expression_by_sample.csv",
        sample_rows,
        ["dataset", "gene", "condition", "sample", "cells", "detected_cells", "pct_detected", "mean_norm_per_cell"],
    )

    manifest = {
        "dataset": "GSE244832",
        "format": "Matrix Market counts plus genes, cells, metadata CSV",
        "local_dir": str(GSE244.relative_to(ROOT)),
        "files": {
            "counts": "hLIVER_counts.mtx.gz",
            "genes": "hLIVER_genes.csv",
            "cells": "hLIVER_cells.csv",
            "metadata": "hLIVER_metadata.csv",
        },
        "n_genes": len(genes),
        "n_cells": len(cells),
        "conditions": sorted(group_totals),
        "notes": "Large validation files are intentionally excluded from Git; compact candidate summaries are tracked.",
    }
    (METADATA / "gse244832_validation_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def summarize_gse207310(candidates: list[str]) -> None:
    files = sorted(GSE207.glob("*.txt.gz"))
    rows = []
    for file in files:
        sample = file.stem.replace(".txt", "")
        with gzip.open(file, "rt") as handle:
            reader = csv.reader(handle)
            header = next(reader)
            sample_col = header[1].strip('"') if len(header) > 1 else sample
            total_counts = 0.0
            gene_counts = {}
            for row in reader:
                if len(row) < 2:
                    continue
                gene_id = row[0].strip('"')
                count = float(row[1])
                total_counts += count
                gene_counts[gene_id] = count
        for gene in candidates:
            # Files are Ensembl IDs, so symbol-level validation needs an annotation module.
            rows.append(
                {
                    "dataset": "GSE207310",
                    "sample": sample_col,
                    "gene_symbol": gene,
                    "status": "requires Ensembl-to-symbol annotation before computed validation",
                    "total_counts": round(total_counts, 3),
                }
            )

    write_csv(
        REPORTS / "validation_gse207310_readiness.csv",
        rows,
        ["dataset", "sample", "gene_symbol", "status", "total_counts"],
    )
    manifest = {
        "dataset": "GSE207310",
        "format": "per-sample gzipped gene count text files using Ensembl IDs",
        "local_dir": str(GSE207.relative_to(ROOT)),
        "n_files": len(files),
        "notes": "Ready for biomarker validation after Ensembl-to-symbol annotation and phenotype mapping.",
    }
    (METADATA / "gse207310_validation_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> None:
    candidates = read_candidates()
    summarize_gse244832(candidates)
    summarize_gse207310(candidates)
    print("validation_summaries_ready")


if __name__ == "__main__":
    main()
