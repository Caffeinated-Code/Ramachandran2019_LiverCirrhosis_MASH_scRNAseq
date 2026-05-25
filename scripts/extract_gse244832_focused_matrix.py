#!/usr/bin/env python3
"""Extract a focused GSE244832 matrix for Seurat object-level validation."""

from __future__ import annotations

import gzip
import json
from pathlib import Path

import pandas as pd
from scipy import sparse
from scipy.io import mmwrite


ROOT = Path(__file__).resolve().parents[1]
GSE244 = ROOT / "data" / "validation" / "GSE244832"
OUT = ROOT / "data" / "processed" / "gse244832_focused"

FOCUSED_GENES = [
    "SMOC2",
    "TIMP1",
    "COL1A1",
    "COL3A1",
    "PDGFRA",
    "PDGFRB",
    "ACTA2",
    "TAGLN",
    "LUM",
    "DCN",
    "RGS5",
    "THY1",
    "PLVAP",
    "ACKR1",
    "VWF",
    "PECAM1",
    "TREM2",
    "CD9",
    "SPP1",
    "GPNMB",
    "LST1",
    "C1QA",
    "C1QB",
    "C1QC",
]


def open_text_maybe_gzip(path: Path):
    with path.open("rb") as raw:
        magic = raw.read(2)
    return gzip.open(path, "rt") if magic == b"\x1f\x8b" else path.open("rt")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    genes = [line.strip().strip('"') for line in (GSE244 / "hLIVER_genes.csv").open()]
    gene_to_rows = {}
    for index, gene in enumerate(genes, start=1):
        if gene in FOCUSED_GENES:
            gene_to_rows.setdefault(gene, []).append(index)
    selected = [gene for gene in FOCUSED_GENES if gene in gene_to_rows]
    selected_row_lookup = {row: selected.index(gene) for gene in selected for row in gene_to_rows[gene]}

    metadata = pd.read_csv(GSE244 / "hLIVER_metadata.csv")
    n_cells = metadata.shape[0]
    rows: list[int] = []
    cols: list[int] = []
    data: list[float] = []

    with open_text_maybe_gzip(GSE244 / "hLIVER_counts.mtx.gz") as handle:
        for line in handle:
            if line.startswith("%"):
                continue
            parts = line.strip().split()
            if len(parts) != 3:
                continue
            row_i = int(parts[0])
            if row_i not in selected_row_lookup:
                continue
            rows.append(selected_row_lookup[row_i])
            cols.append(int(parts[1]) - 1)
            data.append(float(parts[2]))

    matrix = sparse.coo_matrix((data, (rows, cols)), shape=(len(selected), n_cells)).tocsr()
    mmwrite(OUT / "matrix.mtx", matrix)
    pd.Series(selected).to_csv(OUT / "features.tsv", sep="\t", index=False, header=False)
    metadata.iloc[:, 0].to_csv(OUT / "barcodes.tsv", sep="\t", index=False, header=False)
    metadata.to_csv(OUT / "metadata.csv", index=False)
    manifest = {
        "dataset": "GSE244832",
        "purpose": "Focused object-level Seurat validation for fibrosis candidate genes",
        "genes": selected,
        "cells": int(n_cells),
        "matrix": str((OUT / "matrix.mtx").relative_to(ROOT)),
        "metadata": str((OUT / "metadata.csv").relative_to(ROOT)),
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("gse244832_focused_matrix_ready")


if __name__ == "__main__":
    main()
