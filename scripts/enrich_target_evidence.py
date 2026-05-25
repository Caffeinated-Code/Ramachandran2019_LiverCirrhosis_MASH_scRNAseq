#!/usr/bin/env python3
"""Best-effort public evidence enrichment for prioritized liver fibrosis targets."""

from __future__ import annotations

import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports" / "tables"


def http_json(url: str, data: dict | None = None, headers: dict | None = None, timeout: int = 30) -> dict:
    body = None
    req_headers = headers or {}
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        req_headers = {"Content-Type": "application/json", **req_headers}
    req = urllib.request.Request(url, data=body, headers=req_headers)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def read_candidates() -> list[dict]:
    with (REPORTS / "ranked_biomarker_target_candidates.csv").open() as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def mygene_lookup(symbol: str) -> dict:
    query = urllib.parse.urlencode(
        {
            "q": f"symbol:{symbol}",
            "species": "human",
            "fields": "symbol,name,entrezgene,ensembl.gene,summary",
            "size": 1,
        }
    )
    try:
        result = http_json(f"https://mygene.info/v3/query?{query}")
        hits = result.get("hits", [])
        return hits[0] if hits else {}
    except Exception as exc:
        return {"error": str(exc)}


def clinvar_count(symbol: str) -> str:
    term = urllib.parse.quote(f"{symbol}[gene] AND human[orgn]")
    url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=clinvar&term={term}&retmode=json"
    try:
        result = http_json(url)
        return result.get("esearchresult", {}).get("count", "")
    except Exception:
        return ""


def clinical_trials(symbol: str) -> tuple[str, str, str]:
    term = urllib.parse.quote(f"{symbol} AND (MASH OR NASH OR liver fibrosis OR cirrhosis)")
    url = f"https://clinicaltrials.gov/api/v2/studies?query.term={term}&pageSize=5&format=json"
    try:
        result = http_json(url)
    except Exception:
        return "", "", ""
    rows = []
    phases = set()
    sponsors = set()
    for study in result.get("studies", []):
        protocol = study.get("protocolSection", {})
        ident = protocol.get("identificationModule", {})
        status = protocol.get("statusModule", {})
        design = protocol.get("designModule", {})
        sponsor = protocol.get("sponsorCollaboratorsModule", {}).get("leadSponsor", {}).get("name", "")
        title = ident.get("briefTitle", "")
        nct = ident.get("nctId", "")
        phase = ", ".join(design.get("phases", []))
        if phase:
            phases.add(phase)
        if sponsor:
            sponsors.add(sponsor)
        rows.append(f"{nct}: {title} ({phase}; {status.get('overallStatus', '')}; {sponsor})")
    return " | ".join(rows), "; ".join(sorted(phases)), "; ".join(sorted(sponsors))


def opentargets_target_profile(ensembl_id: str) -> tuple[str, str, str]:
    if not ensembl_id:
        return "", "", ""
    query = """
    query targetProfile($ensemblId: String!) {
      target(ensemblId: $ensemblId) {
        tractability {
          label
          modality
          value
        }
        safetyLiabilities {
          event
        }
      }
    }
    """
    try:
        result = http_json(
            "https://api.platform.opentargets.org/api/v4/graphql",
            data={"query": query, "variables": {"ensemblId": ensembl_id}},
        )
        target = result.get("data", {}).get("target", {}) or {}
        tractability = target.get("tractability", []) or []
        true_labels = [
            f"{row.get('modality')}:{row.get('label')}"
            for row in tractability
            if row.get("value") is True
        ]
        safety = target.get("safetyLiabilities", []) or []
        safety_events = sorted({row.get("event", "") for row in safety if row.get("event")})
        return str(len(true_labels)), " | ".join(true_labels[:20]), " | ".join(safety_events[:20])
    except Exception as exc:
        return "", f"Open Targets query failed: {exc}", ""


def main() -> None:
    rows = []
    for candidate in read_candidates():
        symbol = candidate["gene"]
        gene_info = mygene_lookup(symbol)
        ensembl = gene_info.get("ensembl", {})
        if isinstance(ensembl, list):
            ensembl_id = ensembl[0].get("gene", "")
        elif isinstance(ensembl, dict):
            ensembl_id = ensembl.get("gene", "")
        else:
            ensembl_id = ""
        ot_count, ot_tractability, ot_safety = opentargets_target_profile(ensembl_id)
        trials, phases, sponsors = clinical_trials(symbol)
        rows.append(
            {
                "gene": symbol,
                "ensembl_id": ensembl_id,
                "entrez_id": gene_info.get("entrezgene", ""),
                "gene_name": gene_info.get("name", ""),
                "open_targets_tractability_positive_count": ot_count,
                "open_targets_tractability_positive": ot_tractability,
                "open_targets_safety_liabilities": ot_safety,
                "clinicaltrials_liver_query_examples": trials,
                "clinicaltrials_phases_seen": phases,
                "clinicaltrials_sponsors_seen": sponsors,
                "clinvar_record_count_gene_human": clinvar_count(symbol),
                "source_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )
        time.sleep(0.2)

    write_csv(
        REPORTS / "target_public_evidence.csv",
        rows,
        [
            "gene",
            "ensembl_id",
            "entrez_id",
            "gene_name",
            "open_targets_tractability_positive_count",
            "open_targets_tractability_positive",
            "open_targets_safety_liabilities",
            "clinicaltrials_liver_query_examples",
            "clinicaltrials_phases_seen",
            "clinicaltrials_sponsors_seen",
            "clinvar_record_count_gene_human",
            "source_timestamp",
        ],
    )
    print("target_public_evidence_ready")


if __name__ == "__main__":
    main()
