"""
KPI Report Generator
=====================
Generates automated business performance reports showing KPI trends,
operational bottlenecks, and department-level analytics.

Produces:
  - CSV / JSON exports of KPI snapshots
  - Department-level summary reports
  - Executive scorecard data packages
  - Trend analysis datasets for Power BI refresh
"""

import csv
import json
import logging
import os
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional

from sqlalchemy import text

logger = logging.getLogger(__name__)

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).resolve().parents[2]
REPORT_OUTPUT_DIR = BASE_DIR / "logs" / "reports"
REPORT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ── SQL Templates ─────────────────────────────────────────────────────────────

_KPI_TREND_QUERY = """
SELECT
    kpi_date,
    kpi_category,
    kpi_name,
    actual_value,
    target_value,
    CASE
        WHEN target_value = 0 THEN NULL
        ELSE ROUND((actual_value / target_value) * 100.0, 2)
    END AS achievement_pct,
    CASE
        WHEN target_value = 0 THEN 'N/A'
        WHEN actual_value >= target_value THEN 'ON_TARGET'
        WHEN actual_value >= target_value * 0.9 THEN 'AT_RISK'
        ELSE 'BELOW_TARGET'
    END AS status
FROM dbo.fact_kpi_metrics
WHERE kpi_date BETWEEN :start_date AND :end_date
ORDER BY kpi_date, kpi_category, kpi_name
"""

_DEPARTMENT_SUMMARY_QUERY = """
SELECT
    d.department_name,
    d.department_code,
    COUNT(DISTINCT f.order_key) AS total_orders,
    SUM(f.revenue_amount) AS total_revenue,
    SUM(f.cost_amount) AS total_cost,
    SUM(f.revenue_amount) - SUM(f.cost_amount) AS gross_profit,
    CASE
        WHEN SUM(f.revenue_amount) = 0 THEN NULL
        ELSE ROUND(
            (SUM(f.revenue_amount) - SUM(f.cost_amount)) / SUM(f.revenue_amount) * 100.0, 2
        )
    END AS margin_pct,
    AVG(f.order_fill_rate) AS avg_fill_rate,
    AVG(f.on_time_delivery_flag) * 100.0 AS on_time_delivery_pct
FROM dbo.fact_financial_metrics f
JOIN dbo.dim_department d ON f.department_key = d.department_key
WHERE f.transaction_date BETWEEN :start_date AND :end_date
GROUP BY d.department_name, d.department_code
ORDER BY total_revenue DESC
"""

_OPERATIONAL_BOTTLENECK_QUERY = """
SELECT
    bottleneck_category,
    bottleneck_description,
    affected_department,
    severity,
    occurrence_count,
    avg_delay_minutes,
    estimated_revenue_impact,
    first_occurrence_date,
    last_occurrence_date
FROM dbo.vw_operational_bottlenecks
WHERE detection_date BETWEEN :start_date AND :end_date
  AND severity IN ('HIGH', 'CRITICAL')
ORDER BY severity DESC, estimated_revenue_impact DESC
"""


# ── Report Functions ───────────────────────────────────────────────────────────

def generate_kpi_trend_report(
    session,
    start_date: date,
    end_date: date,
    output_format: str = "json"
) -> Path:
    """
    Generate KPI trend report for the given date range.
    Returns the path of the written output file.
    """
    logger.info("Generating KPI trend report: %s to %s", start_date, end_date)

    rows = session.execute(
        text(_KPI_TREND_QUERY),
        {"start_date": start_date, "end_date": end_date}
    ).fetchall()

    data = [dict(row._mapping) for row in rows]
    for record in data:
        if isinstance(record.get("kpi_date"), date):
            record["kpi_date"] = record["kpi_date"].isoformat()

    filename = f"kpi_trend_{start_date}_{end_date}.{output_format}"
    output_path = REPORT_OUTPUT_DIR / filename

    _write_output(data, output_path, output_format)
    logger.info("KPI trend report written: %s (%d rows)", output_path, len(data))
    return output_path


def generate_department_summary_report(
    session,
    start_date: date,
    end_date: date,
    output_format: str = "json"
) -> Path:
    """
    Generate department-level performance summary.
    Returns the path of the written output file.
    """
    logger.info("Generating department summary report: %s to %s", start_date, end_date)

    rows = session.execute(
        text(_DEPARTMENT_SUMMARY_QUERY),
        {"start_date": start_date, "end_date": end_date}
    ).fetchall()

    data = [dict(row._mapping) for row in rows]
    filename = f"department_summary_{start_date}_{end_date}.{output_format}"
    output_path = REPORT_OUTPUT_DIR / filename

    _write_output(data, output_path, output_format)
    logger.info("Department summary written: %s (%d rows)", output_path, len(data))
    return output_path


def generate_operational_bottleneck_report(
    session,
    start_date: date,
    end_date: date,
    output_format: str = "json"
) -> Path:
    """
    Generate operational bottleneck report highlighting high/critical issues.
    Returns the path of the written output file.
    """
    logger.info("Generating operational bottleneck report: %s to %s", start_date, end_date)

    rows = session.execute(
        text(_OPERATIONAL_BOTTLENECK_QUERY),
        {"start_date": start_date, "end_date": end_date}
    ).fetchall()

    data = [dict(row._mapping) for row in rows]
    for record in data:
        for key in ("first_occurrence_date", "last_occurrence_date"):
            if isinstance(record.get(key), date):
                record[key] = record[key].isoformat()

    filename = f"operational_bottlenecks_{start_date}_{end_date}.{output_format}"
    output_path = REPORT_OUTPUT_DIR / filename

    _write_output(data, output_path, output_format)
    logger.info("Bottleneck report written: %s (%d rows)", output_path, len(data))
    return output_path


def generate_executive_scorecard(
    session,
    report_date: date,
    output_format: str = "json"
) -> Path:
    """
    Generate an executive scorecard data package combining KPIs, revenue,
    SLA metrics, and customer health for the given month.
    Returns the path of the written output file.
    """
    start_date = report_date.replace(day=1)
    end_date = report_date

    logger.info("Generating executive scorecard for %s", report_date)

    scorecard: Dict = {
        "report_date": report_date.isoformat(),
        "period": {"start": start_date.isoformat(), "end": end_date.isoformat()},
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "sections": {}
    }

    # KPI summary counts by status
    kpi_rows = session.execute(
        text(_KPI_TREND_QUERY),
        {"start_date": start_date, "end_date": end_date}
    ).fetchall()

    status_counts: Dict[str, int] = {}
    for row in kpi_rows:
        s = row._mapping.get("status", "UNKNOWN")
        status_counts[s] = status_counts.get(s, 0) + 1

    scorecard["sections"]["kpi_health"] = {
        "total_kpis": len(kpi_rows),
        "by_status": status_counts
    }

    # Department performance
    dept_rows = session.execute(
        text(_DEPARTMENT_SUMMARY_QUERY),
        {"start_date": start_date, "end_date": end_date}
    ).fetchall()

    scorecard["sections"]["department_performance"] = [
        dict(row._mapping) for row in dept_rows
    ]

    filename = f"executive_scorecard_{report_date.strftime('%Y_%m')}.{output_format}"
    output_path = REPORT_OUTPUT_DIR / filename

    _write_output(scorecard, output_path, output_format)
    logger.info("Executive scorecard written: %s", output_path)
    return output_path


def run_all_reports(session, report_date: Optional[date] = None) -> List[Path]:
    """
    Run all standard reports for the given date (defaults to yesterday).
    Returns list of generated file paths.
    """
    if report_date is None:
        report_date = date.today() - timedelta(days=1)

    start_date = report_date.replace(day=1)
    end_date = report_date

    generated: List[Path] = []

    try:
        generated.append(generate_kpi_trend_report(session, start_date, end_date))
    except Exception:
        logger.exception("KPI trend report failed")

    try:
        generated.append(generate_department_summary_report(session, start_date, end_date))
    except Exception:
        logger.exception("Department summary report failed")

    try:
        generated.append(generate_operational_bottleneck_report(session, start_date, end_date))
    except Exception:
        logger.exception("Operational bottleneck report failed")

    try:
        generated.append(generate_executive_scorecard(session, report_date))
    except Exception:
        logger.exception("Executive scorecard failed")

    logger.info("Completed %d reports for %s", len(generated), report_date)
    return generated


# ── Helpers ───────────────────────────────────────────────────────────────────

def _write_output(data, path: Path, fmt: str) -> None:
    """Write data dict/list to JSON or CSV file."""
    if fmt == "json":
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, default=str)
    elif fmt == "csv":
        if not data:
            path.write_text("")
            return
        rows = data if isinstance(data, list) else [data]
        fieldnames = list(rows[0].keys()) if rows else []
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
    else:
        raise ValueError(f"Unsupported output format: {fmt}")


# ── CLI Entry Point ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys
    import argparse

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    parser = argparse.ArgumentParser(description="Generate KPI business performance reports")
    parser.add_argument("--date", default=None, help="Report date YYYY-MM-DD (default: yesterday)")
    parser.add_argument("--format", choices=["json", "csv"], default="json", help="Output format")
    args = parser.parse_args()

    report_date = date.fromisoformat(args.date) if args.date else date.today() - timedelta(days=1)

    # Import here to avoid circular imports at module load time
    sys.path.insert(0, str(BASE_DIR / "backend" / "python"))
    from database import get_db_session  # noqa: E402

    with get_db_session() as session:
        files = run_all_reports(session, report_date)

    print(f"\nGenerated {len(files)} reports:")
    for f in files:
        print(f"  {f}")
