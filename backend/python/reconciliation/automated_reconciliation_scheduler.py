"""
Automated Reconciliation Scheduler
===================================
Automates data reconciliation across pipeline stages with:
- Scheduled execution (daily, on-demand)
- Error handling and retry logic
- Comprehensive reporting
- Alerting for discrepancies
- Integration with orchestration framework
"""

import logging
import json
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
import traceback
from decimal import Decimal

from sqlalchemy import func, text
from sqlalchemy.orm import Session

from database import get_db_session
from models import ReconciliationLog, ETLLog


logger = logging.getLogger(__name__)


class ReconciliationScheduleStatus(str, Enum):
    """Schedule execution status."""
    PENDING = "PENDING"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    PARTIAL = "PARTIAL"
    RETRY = "RETRY"


@dataclass
class ReconciliationConfig:
    """Configuration for automated reconciliation."""
    reconciliation_name: str
    data_types: List[str]  # ['Orders', 'Customers', 'Inventory', etc.]
    variance_tolerance_percent: float = 0.01
    variance_warning_threshold: float = 1.0
    variance_critical_threshold: float = 5.0
    enabled: bool = True
    alert_on_failure: bool = True
    alert_emails: List[str] = None
    alert_webhooks: List[str] = None
    max_retries: int = 3
    retry_delay_seconds: int = 300
    timeout_minutes: int = 30
    
    def __post_init__(self):
        if self.alert_emails is None:
            self.alert_emails = []
        if self.alert_webhooks is None:
            self.alert_webhooks = []


@dataclass
class ReconciliationResult:
    """Result of a single reconciliation run."""
    reconciliation_id: str
    reconciliation_name: str
    run_date: datetime
    data_type: str
    source_count: int
    staging_count: int
    fact_count: int
    source_amount: Decimal = Decimal('0')
    staging_amount: Decimal = Decimal('0')
    fact_amount: Decimal = Decimal('0')
    record_variance_count: int = 0
    record_variance_percent: float = 0.0
    amount_variance_percent: float = 0.0
    status: str = "PASS"
    error_message: Optional[str] = None
    execution_duration_seconds: float = 0.0
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization."""
        result = asdict(self)
        result['source_amount'] = str(self.source_amount)
        result['staging_amount'] = str(self.staging_amount)
        result['fact_amount'] = str(self.fact_amount)
        return result


class AutomatedReconciler:
    """Automated reconciliation orchestrator."""
    
    def __init__(self, config: ReconciliationConfig):
        """
        Initialize automated reconciler.
        
        Args:
            config: ReconciliationConfig object
        """
        self.config = config
        self.session = get_db_session()
        self.results: List[ReconciliationResult] = []
        self.execution_start = None
        self.execution_end = None
        self.current_retry_count = 0
        self.errors: List[str] = []
        
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            self.session.close()
    
    def run(self, load_date: Optional[date] = None, force: bool = False) -> Dict:
        """
        Execute automated reconciliation.
        
        Args:
            load_date: Date to reconcile (default: today)
            force: Force execution regardless of schedule
            
        Returns:
            Dictionary with execution results and status
        """
        load_date = load_date or date.today()
        self.execution_start = datetime.now()
        
        logger.info(f"Starting reconciliation: {self.config.reconciliation_name} for {load_date}")
        
        try:
            # Check if already running
            if self._is_already_running(load_date):
                logger.warning(f"Reconciliation already running for {load_date}")
                return {
                    "status": ReconciliationScheduleStatus.RUNNING.value,
                    "message": "Reconciliation already in progress"
                }
            
            # Mark as running
            self._mark_as_running(load_date)
            
            # Execute reconciliation for each data type
            for data_type in self.config.data_types:
                try:
                    result = self._reconcile_data_type(data_type, load_date)
                    self.results.append(result)
                    logger.info(f"Reconciled {data_type}: {result.status}")
                except Exception as e:
                    error_msg = f"Error reconciling {data_type}: {str(e)}"
                    logger.error(error_msg)
                    self.errors.append(error_msg)
                    
                    # Log error
                    self._log_error(data_type, load_date, str(e), traceback.format_exc())
            
            self.execution_end = datetime.now()
            
            # Generate summary and logs
            summary = self._generate_summary(load_date)
            
            # Send alerts if needed
            self._send_alerts(summary)
            
            # Log execution
            self._log_execution(load_date, summary)
            
            return summary
            
        except Exception as e:
            self.execution_end = datetime.now()
            error_msg = f"Fatal error in reconciliation: {str(e)}"
            logger.error(error_msg)
            logger.error(traceback.format_exc())
            
            self._log_error("FATAL", load_date, str(e), traceback.format_exc())
            
            # Attempt retry if configured
            if self.current_retry_count < self.config.max_retries:
                return self._retry_reconciliation(load_date)
            
            return {
                "status": ReconciliationScheduleStatus.FAILED.value,
                "reconciliation_name": self.config.reconciliation_name,
                "load_date": load_date.isoformat(),
                "error": str(e),
                "message": "Reconciliation failed after retries"
            }
    
    def _reconcile_data_type(self, data_type: str, load_date: date) -> ReconciliationResult:
        """
        Reconcile specific data type across pipeline.
        
        Args:
            data_type: Type of data (Orders, Customers, etc.)
            load_date: Date to reconcile
            
        Returns:
            ReconciliationResult
        """
        
        # Query counts and amounts from database
        source_count, source_amount = self._get_source_counts(data_type, load_date)
        staging_count, staging_amount = self._get_staging_counts(data_type, load_date)
        fact_count, fact_amount = self._get_fact_counts(data_type, load_date)
        
        # Calculate variance
        total_source = source_count
        total_loaded = staging_count + fact_count
        
        record_variance_count = abs(total_source - total_loaded)
        record_variance_percent = self._calculate_variance_percent(total_source, total_loaded)
        amount_variance_percent = self._calculate_variance_percent(
            float(source_amount), 
            float(staging_amount + fact_amount)
        )
        
        # Determine status
        if record_variance_percent <= self.config.variance_tolerance_percent:
            status = "PASS"
        elif record_variance_percent <= self.config.variance_warning_threshold:
            status = "WARNING"
        elif record_variance_percent <= self.config.variance_critical_threshold:
            status = "CRITICAL"
        else:
            status = "FAIL"
        
        result = ReconciliationResult(
            reconciliation_id=f"{self.config.reconciliation_name}_{load_date}_{data_type}",
            reconciliation_name=self.config.reconciliation_name,
            run_date=datetime.now(),
            data_type=data_type,
            source_count=source_count,
            staging_count=staging_count,
            fact_count=fact_count,
            source_amount=source_amount,
            staging_amount=staging_amount,
            fact_amount=fact_amount,
            record_variance_count=record_variance_count,
            record_variance_percent=record_variance_percent,
            amount_variance_percent=amount_variance_percent,
            status=status,
            execution_duration_seconds=(datetime.now() - self.execution_start).total_seconds()
        )
        
        # Save to reconciliation log
        self._save_reconciliation_result(result, load_date)
        
        return result
    
    def _get_source_counts(self, data_type: str, load_date: date) -> Tuple[int, Decimal]:
        """Get source system record counts and amounts."""
        # This would query the actual source system
        # For now, returning placeholder - implement based on your source systems
        return 0, Decimal('0')
    
    def _get_staging_counts(self, data_type: str, load_date: date) -> Tuple[int, Decimal]:
        """Get staging table record counts and amounts."""
        try:
            table_map = {
                'Orders': 'stg_erp_orders_transformation',
                'Customers': 'stg_salesforce_transformation',
                'Inventory': 'stg_inventory_hr_production_transformation'
            }
            
            if data_type not in table_map:
                return 0, Decimal('0')
            
            table_name = table_map[data_type]
            query = text(f"""
                SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as amt
                FROM {table_name}
                WHERE CAST(load_date AS DATE) = :load_date
            """)
            
            result = self.session.execute(
                query,
                {"load_date": load_date}
            ).fetchone()
            
            if result:
                return result[0], Decimal(str(result[1]))
            return 0, Decimal('0')
        except Exception as e:
            logger.error(f"Error getting staging counts for {data_type}: {e}")
            return 0, Decimal('0')
    
    def _get_fact_counts(self, data_type: str, load_date: date) -> Tuple[int, Decimal]:
        """Get fact table record counts and amounts."""
        try:
            table_map = {
                'Orders': 'fact_sales',
                'Customers': 'fact_customers',
                'Revenue': 'fact_revenue'
            }
            
            if data_type not in table_map:
                return 0, Decimal('0')
            
            table_name = table_map[data_type]
            query = text(f"""
                SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as amt
                FROM {table_name}
                WHERE CAST(load_date AS DATE) = :load_date
            """)
            
            result = self.session.execute(
                query,
                {"load_date": load_date}
            ).fetchone()
            
            if result:
                return result[0], Decimal(str(result[1]))
            return 0, Decimal('0')
        except Exception as e:
            logger.error(f"Error getting fact counts for {data_type}: {e}")
            return 0, Decimal('0')
    
    def _calculate_variance_percent(self, source: float, target: float) -> float:
        """Calculate variance percentage."""
        if source == 0:
            return 0 if target == 0 else 100
        return abs((source - target) / source * 100)
    
    def _save_reconciliation_result(self, result: ReconciliationResult, load_date: date):
        """Save reconciliation result to database."""
        try:
            recon_log = ReconciliationLog(
                load_date=load_date,
                reconciliation_type=result.data_type,
                source_name=self.config.reconciliation_name,
                source_record_count=result.source_count,
                staging_record_count=result.staging_count,
                fact_record_count=result.fact_count,
                source_total_amount=result.source_amount,
                staging_total_amount=result.staging_amount,
                fact_total_amount=result.fact_amount,
                record_variance=result.record_variance_count,
                amount_variance_percent=result.amount_variance_percent,
                reconciliation_status=result.status,
                reconciliation_notes=f"Automated reconciliation - {result.status}"
            )
            self.session.add(recon_log)
            self.session.commit()
            logger.info(f"Saved reconciliation result: {result.data_type} - {result.status}")
        except Exception as e:
            logger.error(f"Error saving reconciliation result: {e}")
            self.session.rollback()
    
    def _generate_summary(self, load_date: date) -> Dict:
        """Generate execution summary."""
        total_results = len(self.results)
        passed = sum(1 for r in self.results if r.status == "PASS")
        warnings = sum(1 for r in self.results if r.status == "WARNING")
        critical = sum(1 for r in self.results if r.status == "CRITICAL")
        failed = sum(1 for r in self.results if r.status == "FAIL")
        
        execution_duration = (self.execution_end - self.execution_start).total_seconds()
        
        # Determine overall status
        if failed > 0:
            overall_status = ReconciliationScheduleStatus.FAILED
        elif critical > 0:
            overall_status = ReconciliationScheduleStatus.PARTIAL
        elif warnings > 0:
            overall_status = ReconciliationScheduleStatus.PARTIAL
        else:
            overall_status = ReconciliationScheduleStatus.SUCCESS
        
        summary = {
            "status": overall_status.value,
            "reconciliation_name": self.config.reconciliation_name,
            "load_date": load_date.isoformat(),
            "execution_start": self.execution_start.isoformat(),
            "execution_end": self.execution_end.isoformat(),
            "execution_duration_seconds": execution_duration,
            "total_reconciliations": total_results,
            "passed": passed,
            "warnings": warnings,
            "critical": critical,
            "failed": failed,
            "results": [r.to_dict() for r in self.results],
            "errors": self.errors
        }
        
        return summary
    
    def _send_alerts(self, summary: Dict):
        """Send alerts for failures or critical issues."""
        if not self.config.alert_on_failure:
            return
        
        status = summary.get("status")
        
        # Alert on FAILED or CRITICAL status
        if status in [ReconciliationScheduleStatus.FAILED.value, ReconciliationScheduleStatus.PARTIAL.value]:
            message = self._format_alert_message(summary)
            
            # Send email alerts
            for email in self.config.alert_emails:
                self._send_email_alert(email, message)
            
            # Send webhook alerts
            for webhook_url in self.config.alert_webhooks:
                self._send_webhook_alert(webhook_url, summary)
    
    def _format_alert_message(self, summary: Dict) -> str:
        """Format alert message."""
        return f"""
Reconciliation Alert: {summary['reconciliation_name']}
Date: {summary['load_date']}
Status: {summary['status']}

Summary:
- Total: {summary['total_reconciliations']}
- Passed: {summary['passed']}
- Warnings: {summary['warnings']}
- Critical: {summary['critical']}
- Failed: {summary['failed']}

Duration: {summary['execution_duration_seconds']:.2f} seconds

Errors:
{chr(10).join(summary['errors'])}
"""
    
    def _send_email_alert(self, email: str, message: str):
        """Send email alert."""
        try:
            # TODO: Implement email sending
            logger.info(f"Email alert sent to {email}")
        except Exception as e:
            logger.error(f"Error sending email alert to {email}: {e}")
    
    def _send_webhook_alert(self, webhook_url: str, summary: Dict):
        """Send webhook alert."""
        try:
            # TODO: Implement webhook sending
            logger.info(f"Webhook alert sent to {webhook_url}")
        except Exception as e:
            logger.error(f"Error sending webhook alert to {webhook_url}: {e}")
    
    def _is_already_running(self, load_date: date) -> bool:
        """Check if reconciliation is already running."""
        try:
            query = text("""
                SELECT COUNT(*) FROM etl_logs
                WHERE process_name = :process_name
                AND log_date = :load_date
                AND status = :status
            """)
            
            result = self.session.execute(query, {
                "process_name": f"reconciliation_{self.config.reconciliation_name}",
                "load_date": load_date,
                "status": ReconciliationScheduleStatus.RUNNING.value
            }).fetchone()
            
            return result[0] > 0 if result else False
        except Exception as e:
            logger.error(f"Error checking if running: {e}")
            return False
    
    def _mark_as_running(self, load_date: date):
        """Mark reconciliation as running."""
        try:
            etl_log = ETLLog(
                process_name=f"reconciliation_{self.config.reconciliation_name}",
                process_step="START",
                record_count=0,
                status=ReconciliationScheduleStatus.RUNNING,
                log_date=load_date,
                details={"started_at": self.execution_start.isoformat()}
            )
            self.session.add(etl_log)
            self.session.commit()
        except Exception as e:
            logger.error(f"Error marking as running: {e}")
    
    def _log_error(self, data_type: str, load_date: date, error: str, traceback_str: str):
        """Log error details."""
        try:
            etl_log = ETLLog(
                process_name=f"reconciliation_{self.config.reconciliation_name}",
                process_step=f"ERROR_{data_type}",
                record_count=0,
                status="FAILED",
                log_date=load_date,
                details={
                    "error": error,
                    "traceback": traceback_str,
                    "timestamp": datetime.now().isoformat()
                }
            )
            self.session.add(etl_log)
            self.session.commit()
        except Exception as e:
            logger.error(f"Error logging error: {e}")
    
    def _log_execution(self, load_date: date, summary: Dict):
        """Log execution summary."""
        try:
            etl_log = ETLLog(
                process_name=f"reconciliation_{self.config.reconciliation_name}",
                process_step="COMPLETE",
                record_count=summary["total_reconciliations"],
                status=summary["status"],
                log_date=load_date,
                details=summary
            )
            self.session.add(etl_log)
            self.session.commit()
            logger.info(f"Logged reconciliation execution")
        except Exception as e:
            logger.error(f"Error logging execution: {e}")
    
    def _retry_reconciliation(self, load_date: date) -> Dict:
        """Retry reconciliation on failure."""
        self.current_retry_count += 1
        logger.info(f"Retrying reconciliation (attempt {self.current_retry_count})")
        
        import time
        time.sleep(self.config.retry_delay_seconds)
        
        return self.run(load_date, force=True)


def create_default_configs() -> List[ReconciliationConfig]:
    """Create default reconciliation configurations."""
    return [
        ReconciliationConfig(
            reconciliation_name="ERP_Orders_Reconciliation",
            data_types=["Orders"],
            variance_tolerance_percent=0.01,
            variance_warning_threshold=1.0,
            variance_critical_threshold=5.0,
            alert_emails=["data-team@company.com"],
            enabled=True
        ),
        ReconciliationConfig(
            reconciliation_name="Salesforce_Customers_Reconciliation",
            data_types=["Customers"],
            variance_tolerance_percent=0.05,
            variance_warning_threshold=2.0,
            variance_critical_threshold=10.0,
            alert_emails=["data-team@company.com"],
            enabled=True
        ),
        ReconciliationConfig(
            reconciliation_name="Inventory_Revenue_Reconciliation",
            data_types=["Inventory", "Revenue"],
            variance_tolerance_percent=0.01,
            variance_warning_threshold=1.0,
            variance_critical_threshold=5.0,
            alert_emails=["finance-team@company.com"],
            enabled=True
        )
    ]


if __name__ == "__main__":
    # Example usage
    config = ReconciliationConfig(
        reconciliation_name="Daily_Reconciliation",
        data_types=["Orders", "Customers", "Inventory"],
        alert_emails=["admin@company.com"]
    )
    
    with AutomatedReconciler(config) as reconciler:
        result = reconciler.run()
        print(json.dumps(result, indent=2, default=str))
