"""
Reconciliation Scripts
======================
ETL reconciliation to verify data integrity across pipeline stages.
Compares record counts and totals: Source → Staging → Facts
"""

import logging
from datetime import date, datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
from decimal import Decimal

from sqlalchemy import func, text
from sqlalchemy.orm import Session

from database import get_db_session
from models import (
    StagingOrdersConformed, StagingCustomersConformed,
    FactSales, FactRevenue, ReconciliationLog, ETLLog
)

logger = logging.getLogger(__name__)


class ReconciliationStatus(str, Enum):
    """Reconciliation status."""
    PASS = "PASS"
    FAIL = "FAIL"
    WARNING = "WARNING"


@dataclass
class ReconciliationSummary:
    """Reconciliation results for a data stream."""
    data_type: str  # Orders, Customers, etc.
    source_name: str
    load_date: date
    
    # Record counts
    source_count: int
    staging_count: int
    fact_count: int
    
    # Amounts (if applicable)
    source_amount: Decimal = Decimal('0')
    staging_amount: Decimal = Decimal('0')
    fact_amount: Decimal = Decimal('0')
    
    # Variance metrics
    record_variance_percent: float = 0.0
    amount_variance_percent: float = 0.0
    
    # Status
    status: ReconciliationStatus = ReconciliationStatus.PASS
    notes: str = ""
    
    def __repr__(self) -> str:
        return (
            f"<Reconciliation {self.data_type}: "
            f"Source={self.source_count}, Staging={self.staging_count}, Fact={self.fact_count} | "
            f"Status={self.status}>"
        )


class BaseReconciler:
    """Base class for reconciliation."""
    
    def __init__(self, load_date: Optional[date] = None, variance_tolerance: float = 0.01):
        """
        Initialize reconciler.
        
        Args:
            load_date: Date to reconcile (default: today)
            variance_tolerance: Acceptable variance percent (default: 0.01%)
        """
        self.load_date = load_date or date.today()
        self.session = get_db_session()
        self.variance_tolerance = variance_tolerance
        self.reconciliations: List[ReconciliationSummary] = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            self.session.close()

    def calculate_variance(self, source_value: float, target_value: float) -> float:
        """Calculate variance percentage."""
        if source_value == 0:
            return 0 if target_value == 0 else 100
        return abs((source_value - target_value) / source_value * 100)

    def add_reconciliation(self, summary: ReconciliationSummary):
        """Add reconciliation result."""
        self.reconciliations.append(summary)
        
        # Determine status
        record_variance = self.calculate_variance(
            summary.source_count, 
            summary.staging_count + summary.fact_count
        )
        
        if record_variance <= self.variance_tolerance:
            summary.status = ReconciliationStatus.PASS
        elif record_variance <= 1.0:
            summary.status = ReconciliationStatus.WARNING
        else:
            summary.status = ReconciliationStatus.FAIL
        
        # Log reconciliation
        self._log_reconciliation(summary)

    def _log_reconciliation(self, summary: ReconciliationSummary):
        """Log reconciliation to database."""
        try:
            recon_log = ReconciliationLog(
                load_date=summary.load_date,
                reconciliation_type=summary.data_type,
                source_name=summary.source_name,
                source_record_count=summary.source_count,
                staging_record_count=summary.staging_count,
                fact_record_count=summary.fact_count,
                source_total_amount=summary.source_amount,
                staging_total_amount=summary.staging_amount,
                fact_total_amount=summary.fact_amount,
                record_variance=abs(summary.source_count - (summary.staging_count + summary.fact_count)),
                amount_variance_percent=summary.amount_variance_percent,
                reconciliation_status=summary.status,
                reconciliation_notes=summary.notes
            )
            self.session.add(recon_log)
            self.session.commit()
            logger.info(f"Logged reconciliation: {summary}")
        except Exception as e:
            logger.error(f"Error logging reconciliation: {e}")
            self.session.rollback()

    def get_summary(self) -> Dict:
        """Get overall reconciliation summary."""
        passed = sum(1 for r in self.reconciliations if r.status == ReconciliationStatus.PASS)
        failed = sum(1 for r in self.reconciliations if r.status == ReconciliationStatus.FAIL)
        warned = sum(1 for r in self.reconciliations if r.status == ReconciliationStatus.WARNING)
        
        return {
            "total_reconciliations": len(self.reconciliations),
            "passed": passed,
            "failed": failed,
            "warned": warned,
            "overall_status": ReconciliationStatus.FAIL if failed > 0 else (
                ReconciliationStatus.WARNING if warned > 0 else ReconciliationStatus.PASS
            )
        }


class OrderReconciler(BaseReconciler):
    """Reconcile order data through ETL pipeline."""
    
    def reconcile_from_staging(self) -> None:
        """Reconcile orders from staging table."""
        logger.info(f"Reconciling orders for {self.load_date}")
        
        # Source query - from raw staging
        source_query = text("""
            SELECT COUNT(*) as cnt, SUM(CAST(GROSS_AMOUNT AS DECIMAL(14,2))) as total
            FROM stg_raw_erp_orders 
            WHERE CAST(LOAD_DATE AS DATE) = :load_date
        """)
        
        source_result = self.session.execute(source_query, {"load_date": self.load_date}).fetchone()
        source_count = source_result[0] or 0
        source_amount = source_result[1] or Decimal('0')
        
        # Staging counts
        staging_count = self.session.query(func.count()).filter(
            StagingOrdersConformed.source_load_date == self.load_date
        ).scalar() or 0
        
        staging_amount = self.session.query(
            func.sum(StagingOrdersConformed.net_amount)
        ).filter(
            StagingOrdersConformed.source_load_date == self.load_date
        ).scalar() or Decimal('0')
        
        # Fact counts (via staging)
        fact_count = self.session.query(func.count()).filter(
            StagingOrdersConformed.source_load_date == self.load_date,
            StagingOrdersConformed.dq_validation_status == 'VALID'
        ).scalar() or 0
        
        fact_amount = self.session.query(
            func.sum(StagingOrdersConformed.net_amount)
        ).filter(
            StagingOrdersConformed.source_load_date == self.load_date,
            StagingOrdersConformed.dq_validation_status == 'VALID'
        ).scalar() or Decimal('0')
        
        # Calculate variance
        record_variance = self.calculate_variance(source_count, staging_count + fact_count)
        amount_variance = self.calculate_variance(
            float(source_amount), 
            float(staging_amount + fact_amount)
        )
        
        summary = ReconciliationSummary(
            data_type="Orders",
            source_name="ERP",
            load_date=self.load_date,
            source_count=source_count,
            staging_count=staging_count,
            fact_count=fact_count,
            source_amount=source_amount,
            staging_amount=staging_amount,
            fact_amount=fact_amount,
            record_variance_percent=record_variance,
            amount_variance_percent=amount_variance,
            notes=f"Source: {source_count} | Staging: {staging_count} | Fact: {fact_count} | "
                  f"Record Var: {record_variance:.2f}% | Amount Var: {amount_variance:.2f}%"
        )
        
        self.add_reconciliation(summary)

    def reconcile_to_facts(self) -> None:
        """Reconcile orders from staging to fact table."""
        logger.info(f"Reconciling orders to facts for {self.load_date}")
        
        # Staging totals
        staging_count = self.session.query(func.count()).filter(
            StagingOrdersConformed.source_load_date == self.load_date,
            StagingOrdersConformed.dq_validation_status == 'VALID'
        ).scalar() or 0
        
        staging_amount = self.session.query(
            func.sum(StagingOrdersConformed.net_amount)
        ).filter(
            StagingOrdersConformed.source_load_date == self.load_date,
            StagingOrdersConformed.dq_validation_status == 'VALID'
        ).scalar() or Decimal('0')
        
        # Fact totals
        fact_count = self.session.query(func.count()).filter(
            FactSales.load_date == self.load_date
        ).scalar() or 0
        
        fact_amount = self.session.query(
            func.sum(FactSales.net_amount)
        ).filter(
            FactSales.load_date == self.load_date
        ).scalar() or Decimal('0')
        
        # Calculate variance
        record_variance = self.calculate_variance(staging_count, fact_count)
        amount_variance = self.calculate_variance(float(staging_amount), float(fact_amount))
        
        summary = ReconciliationSummary(
            data_type="Orders to Facts",
            source_name="ERP",
            load_date=self.load_date,
            source_count=staging_count,
            staging_count=0,
            fact_count=fact_count,
            source_amount=staging_amount,
            staging_amount=Decimal('0'),
            fact_amount=fact_amount,
            record_variance_percent=record_variance,
            amount_variance_percent=amount_variance,
            notes=f"Staging: {staging_count} (${staging_amount}) | Fact: {fact_count} (${fact_amount}) | "
                  f"Variance: {amount_variance:.2f}%"
        )
        
        self.add_reconciliation(summary)


class CustomerReconciler(BaseReconciler):
    """Reconcile customer data through ETL pipeline."""
    
    def reconcile_from_staging(self) -> None:
        """Reconcile customers from staging."""
        logger.info(f"Reconciling customers for {self.load_date}")
        
        # Source query
        source_query = text("""
            SELECT COUNT(*) as cnt
            FROM stg_raw_salesforce_customers 
            WHERE CAST(LOAD_DATE AS DATE) = :load_date
        """)
        
        source_result = self.session.execute(source_query, {"load_date": self.load_date}).fetchone()
        source_count = source_result[0] or 0
        
        # Staging counts
        staging_count = self.session.query(func.count()).filter(
            StagingCustomersConformed.source_load_date == self.load_date
        ).scalar() or 0
        
        # Calculate variance
        record_variance = self.calculate_variance(source_count, staging_count)
        
        summary = ReconciliationSummary(
            data_type="Customers",
            source_name="SALESFORCE",
            load_date=self.load_date,
            source_count=source_count,
            staging_count=staging_count,
            fact_count=0,
            record_variance_percent=record_variance,
            notes=f"Source: {source_count} | Staging: {staging_count} | Variance: {record_variance:.2f}%"
        )
        
        self.add_reconciliation(summary)


class RevenueReconciler(BaseReconciler):
    """Reconcile revenue aggregations."""
    
    def reconcile_revenue_to_sales(self) -> None:
        """Verify revenue facts match sales facts."""
        logger.info(f"Reconciling revenue aggregations for {self.load_date}")
        
        # Get sales totals
        sales_amount = self.session.query(
            func.sum(FactSales.net_amount)
        ).filter(
            FactSales.load_date == self.load_date
        ).scalar() or Decimal('0')
        
        sales_count = self.session.query(func.count()).filter(
            FactSales.load_date == self.load_date
        ).scalar() or 0
        
        # Get revenue totals
        revenue_amount = self.session.query(
            func.sum(FactRevenue.total_net_revenue)
        ).filter(
            FactRevenue.load_date == self.load_date
        ).scalar() or Decimal('0')
        
        revenue_count = self.session.query(func.count()).filter(
            FactRevenue.load_date == self.load_date
        ).scalar() or 0
        
        # Calculate variance
        amount_variance = self.calculate_variance(float(sales_amount), float(revenue_amount))
        
        summary = ReconciliationSummary(
            data_type="Revenue Aggregations",
            source_name="FACT_SALES",
            load_date=self.load_date,
            source_count=sales_count,
            staging_count=0,
            fact_count=revenue_count,
            source_amount=sales_amount,
            fact_amount=revenue_amount,
            amount_variance_percent=amount_variance,
            notes=f"Sales Total: ${sales_amount} | Revenue Total: ${revenue_amount} | "
                  f"Variance: {amount_variance:.2f}%"
        )
        
        self.add_reconciliation(summary)


class MasterReconciler:
    """Orchestrate all reconciliation tasks."""
    
    def __init__(self, load_date: Optional[date] = None, variance_tolerance: float = 0.01):
        self.load_date = load_date or date.today()
        self.variance_tolerance = variance_tolerance
        self.logger = logging.getLogger(__name__)

    def reconcile_all(self) -> Dict:
        """Execute all reconciliation tasks."""
        self.logger.info(f"Starting master reconciliation for {self.load_date}")
        
        all_summaries = []
        
        # Reconcile orders
        try:
            with OrderReconciler(self.load_date, self.variance_tolerance) as reconciler:
                reconciler.reconcile_from_staging()
                reconciler.reconcile_to_facts()
                all_summaries.extend(reconciler.reconciliations)
        except Exception as e:
            self.logger.error(f"Error reconciling orders: {e}")
        
        # Reconcile customers
        try:
            with CustomerReconciler(self.load_date, self.variance_tolerance) as reconciler:
                reconciler.reconcile_from_staging()
                all_summaries.extend(reconciler.reconciliations)
        except Exception as e:
            self.logger.error(f"Error reconciling customers: {e}")
        
        # Reconcile revenue
        try:
            with RevenueReconciler(self.load_date, self.variance_tolerance) as reconciler:
                reconciler.reconcile_revenue_to_sales()
                all_summaries.extend(reconciler.reconciliations)
        except Exception as e:
            self.logger.error(f"Error reconciling revenue: {e}")
        
        # Generate summary
        total_recons = len(all_summaries)
        passed = sum(1 for s in all_summaries if s.status == ReconciliationStatus.PASS)
        failed = sum(1 for s in all_summaries if s.status == ReconciliationStatus.FAIL)
        warned = sum(1 for s in all_summaries if s.status == ReconciliationStatus.WARNING)
        
        overall_status = (
            ReconciliationStatus.FAIL if failed > 0 else
            (ReconciliationStatus.WARNING if warned > 0 else ReconciliationStatus.PASS)
        )
        
        summary = {
            "load_date": self.load_date,
            "total_reconciliations": total_recons,
            "passed": passed,
            "failed": failed,
            "warned": warned,
            "overall_status": overall_status,
            "details": [
                {
                    "data_type": s.data_type,
                    "status": s.status,
                    "source_count": s.source_count,
                    "staging_count": s.staging_count,
                    "fact_count": s.fact_count,
                    "variance_percent": s.record_variance_percent,
                    "notes": s.notes
                }
                for s in all_summaries
            ]
        }
        
        # Log overall result
        session = get_db_session()
        try:
            etl_log = ETLLog(
                process_name="sp_reconcile_etl_totals",
                process_step="Master Reconciliation",
                record_count=total_recons,
                status=overall_status,
                log_date=self.load_date,
                details=f"Passed: {passed}/{total_recons} | Failed: {failed}"
            )
            session.add(etl_log)
            session.commit()
        finally:
            session.close()
        
        self.logger.info(f"Master reconciliation complete: {overall_status} ({passed}/{total_recons} passed)")
        return summary


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    reconciler = MasterReconciler()
    results = reconciler.reconcile_all()
    
    print("\n" + "="*60)
    print(f"RECONCILIATION SUMMARY - {results['load_date']}")
    print("="*60)
    print(f"Total: {results['total_reconciliations']} | "
          f"Passed: {results['passed']} | "
          f"Failed: {results['failed']} | "
          f"Warned: {results['warned']}")
    print(f"Overall Status: {results['overall_status']}")
    print("="*60)
    
    for detail in results['details']:
        print(f"\n{detail['data_type']}: {detail['status']}")
        print(f"  Source: {detail['source_count']} | Staging: {detail['staging_count']} | Fact: {detail['fact_count']}")
        print(f"  Variance: {detail['variance_percent']:.2f}%")
        print(f"  Notes: {detail['notes']}")
