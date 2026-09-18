#!/usr/bin/env python3
"""Aggregate SWE-bench evaluation reports into an empirical pass@K score."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("reports", nargs="+", type=Path, help="Evaluator JSON reports")
    args = parser.parse_args()

    reports = [json.loads(path.read_text()) for path in args.reports]
    totals = {report["total_instances"] for report in reports}
    if len(totals) != 1:
        raise SystemExit(f"Reports do not use the same instance count: {sorted(totals)}")

    resolved = set()
    for report in reports:
        resolved.update(report.get("resolved_ids", []))

    total = reports[0]["total_instances"]
    score = 100.0 * len(resolved) / total if total else 0.0
    print(f"Empirical pass@{len(reports)}: {len(resolved)}/{total} = {score:.2f}%")
    print("Resolved by at least one attempt:", len(resolved))


if __name__ == "__main__":
    main()
