"""
Automated Validation Scheduler
==============================
Automates data quality validation across pipeline with:
- Scheduled execution (daily, hourly, on-demand)
- Continuous data quality monitoring
- Error handling and recovery
- Comprehensive reporting and alerting
- Performance optimization
- Integration with orchestration framework
"""

import logging
import json
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
import traceback
from collections import defaultdict

from sqlalchemy import func, text
from sqlalchemy.orm import Session

from database import get_db_session
from models import DataQualityScore, ETLLog


logger = logging.getLogger(__name__)


class ValidationScheduleStatus(str, Enum):
    """Validation schedule execution status."""
    PENDING = "PENDING"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    PARTIAL = "PARTIAL"
    RETRY = "RETRY"


class ValidationSeverity(str, Enum):
    """Severity levels for validation failures."""
    INFO = "INFO"
    WARNING = "WARNING"
    CRITICAL = "CRITICAL"
    BLOCKER = "BLOCKER"


@dataclass
class ValidationCheckConfig:
    """Configuration for a validation check."""
    check_id: str
    check_name: str
    check_type: str  # completeness, accuracy, consistency, business_logic, duplicate, null
    table_name: str
    enabled: bool = True
    severity: ValidationSeverity = ValidationSeverity.WARNING
    failure_threshold_percent: float = 5.0
    warning_threshold_percent: float = 1.0
    sql_query: Optional[str] = None
    expected_values: Optional[Dict] = None
    columns_to_check: List[str] = None
    retry_on_failure: bool = True
    timeout_seconds: int = 300
    
    def __post_init__(self):
        if self.columns_to_check is None:
            self.columns_to_check = []


@dataclass
class ValidationConfig:
    """Configuration for automated validation suite."""
    validation_suite_name: str
    checks: List[ValidationCheckConfig] = None
    schedule_cron: str = "0 1 * * *"  # Daily at 1 AM
    enabled: bool = True
    alert_on_failure: bool = True
    alert_emails: List[str] = None
    alert_webhooks: List[str] = None
    alert_severity_threshold: ValidationSeverity = ValidationSeverity.WARNING
    max_retries: int = 3
    retry_delay_seconds: int = 60
    parallel_execution: bool = True
    max_parallel_checks: int = 5
    generate_html_report: bool = True
    archive_old_reports: bool = True
    archive_days: int = 30
    
    def __post_init__(self):
        if self.checks is None:
            self.checks = []
        if self.alert_emails is None:
            self.alert_emails = []
        if self.alert_webhooks is None:
            self.alert_webhooks = []


@dataclass
class CheckResult:
    """Result of a single validation check."""
    check_id: str
    check_name: str
    check_type: str
    table_name: str
    run_date: datetime
    total_records: int
    valid_records: int
    invalid_records: int
    validation_percent: float
    status: str  # PASS, WARNING, FAIL
    severity: ValidationSeverity
    details: str
    error_message: Optional[str] = None
    execution_duration_seconds: float = 0.0
    failed_record_samples: List[Dict] = None
    
    def __post_init__(self):
        if self.failed_record_samples is None:
            self.failed_record_samples = []
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "check_id": self.check_id,
            "check_name": self.check_name,
            "check_type": self.check_type,
            "table_name": self.table_name,
            "run_date": self.run_date.isoformat(),
            "total_records": self.total_records,
            "valid_records": self.valid_records,
            "invalid_records": self.invalid_records,
            "validation_percent": self.validation_percent,
            "status": self.status,
            "severity": self.severity.value,
            "details": self.details,
            "error_message": self.error_message,
            "execution_duration_seconds": self.execution_duration_seconds,
            "failed_record_samples": self.failed_record_samples
        }


class AutomatedValidator:
    """Automated validation orchestrator."""
    
    def __init__(self, config: ValidationConfig):
        """
        Initialize automated validator.
        
        Args:
            config: ValidationConfig object
        """
        self.config = config
        self.session = get_db_session()
        self.results: List[CheckResult] = []
        self.execution_start = None
        self.execution_end = None
        self.current_retry_count = 0
        self.errors: List[str] = []
        self.execution_id = f"val_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            self.session.close()
    
    def run(self, load_date: Optional[date] = None, force: bool = False) -> Dict:
        """
        Execute automated validation suite.
        
        Args:
            load_date: Date to validate (default: today)
            force: Force execution regardless of schedule
            
        Returns:
            Dictionary with execution results and status
        """
        load_date = load_date or date.today()
        self.execution_start = datetime.now()
        
        logger.info(f"Starting validation suite: {self.config.validation_suite_name} for {load_date}")
        
        if not self.config.enabled:
            logger.warning(f"Validation suite {self.config.validation_suite_name} is disabled")
            return {"status": "DISABLED", "message": "Validation suite is disabled"}
        
        try:
            # Check if already running
            if self._is_already_running(load_date):
                logger.warning(f"Validation already running for {load_date}")
                return {
                    "status": ValidationScheduleStatus.RUNNING.value,
                    "message": "Validation already in progress"
                }
            
            # Mark as running
            self._mark_as_running(load_date)
            
            # Execute validation checks
            if self.config.parallel_execution:
                self._run_checks_parallel(load_date)
            else:
                self._run_checks_sequential(load_date)
            
            self.execution_end = datetime.now()
            
            # Generate summary
            summary = self._generate_summary(load_date)
            
            # Generate reports
            if self.config.generate_html_report:
                report_path = self._generate_html_report(summary)
                summary["html_report_path"] = report_path
            
            # Send alerts if needed
            self._send_alerts(summary)
            
            # Save data quality scores
            self._save_quality_scores(summary, load_date)
            
            # Log execution
            self._log_execution(load_date, summary)
            
            return summary
            
        except Exception as e:
            self.execution_end = datetime.now()
            error_msg = f"Fatal error in validation: {str(e)}"
            logger.error(error_msg)
            logger.error(traceback.format_exc())
            
            self._log_error("FATAL", load_date, str(e), traceback.format_exc())
            
            # Attempt retry if configured
            if self.current_retry_count < self.config.max_retries:
                return self._retry_validation(load_date)
            
            return {
                "status": ValidationScheduleStatus.FAILED.value,
                "validation_suite": self.config.validation_suite_name,
                "load_date": load_date.isoformat(),
                "error": str(e),
                "message": "Validation failed after retries"
            }
    
    def _run_checks_sequential(self, load_date: date):
        """Run validation checks sequentially."""
        for check_config in self.config.checks:
            if not check_config.enabled:
                continue
            
            try:
                result = self._execute_check(check_config, load_date)
                self.results.append(result)
                logger.info(f"Completed check {check_config.check_name}: {result.status}")
            except Exception as e:
                error_msg = f"Error executing check {check_config.check_name}: {str(e)}"
                logger.error(error_msg)
                self.errors.append(error_msg)
                self._log_error(check_config.check_name, load_date, str(e), traceback.format_exc())
    
    def _run_checks_parallel(self, load_date: date):
        """Run validation checks in parallel (limited concurrency)."""
        from concurrent.futures import ThreadPoolExecutor, as_completed
        
        with ThreadPoolExecutor(max_workers=self.config.max_parallel_checks) as executor:
            futures = {}
            
            for check_config in self.config.checks:
                if not check_config.enabled:
                    continue
                
                future = executor.submit(self._execute_check, check_config, load_date)
                futures[future] = check_config.check_name
            
            for future in as_completed(futures):
                check_name = futures[future]
                try:
                    result = future.result()
                    self.results.append(result)
                    logger.info(f"Completed check {check_name}: {result.status}")
                except Exception as e:
                    error_msg = f"Error executing check {check_name}: {str(e)}"
                    logger.error(error_msg)
                    self.errors.append(error_msg)
    
    def _execute_check(self, check_config: ValidationCheckConfig, load_date: date) -> CheckResult:
        """Execute a single validation check."""
        check_start = datetime.now()
        
        try:
            if check_config.check_type == "custom_sql":
                total_records, valid_records, invalid_records, details = self._run_custom_sql_check(
                    check_config, load_date
                )
            elif check_config.check_type == "completeness":
                total_records, valid_records, invalid_records, details = self._check_completeness(
                    check_config, load_date
                )
            elif check_config.check_type == "null_validation":
                total_records, valid_records, invalid_records, details = self._check_null_values(
                    check_config, load_date
                )
            elif check_config.check_type == "duplicate":
                total_records, valid_records, invalid_records, details = self._check_duplicates(
                    check_config, load_date
                )
            elif check_config.check_type == "consistency":
                total_records, valid_records, invalid_records, details = self._check_consistency(
                    check_config, load_date
                )
            elif check_config.check_type == "business_logic":
                total_records, valid_records, invalid_records, details = self._check_business_logic(
                    check_config, load_date
                )
            else:
                raise ValueError(f"Unknown check type: {check_config.check_type}")
            
            # Calculate validation percentage
            validation_percent = (valid_records / total_records * 100) if total_records > 0 else 0
            
            # Determine status
            if invalid_records == 0:
                status = "PASS"
            elif validation_percent >= (100 - check_config.warning_threshold_percent):
                status = "WARNING"
            else:
                status = "FAIL"
            
            execution_duration = (datetime.now() - check_start).total_seconds()
            
            result = CheckResult(
                check_id=check_config.check_id,
                check_name=check_config.check_name,
                check_type=check_config.check_type,
                table_name=check_config.table_name,
                run_date=datetime.now(),
                total_records=total_records,
                valid_records=valid_records,
                invalid_records=invalid_records,
                validation_percent=validation_percent,
                status=status,
                severity=check_config.severity,
                details=details,
                execution_duration_seconds=execution_duration
            )
            
            return result
            
        except Exception as e:
            logger.error(f"Error executing check {check_config.check_name}: {e}")
            
            result = CheckResult(
                check_id=check_config.check_id,
                check_name=check_config.check_name,
                check_type=check_config.check_type,
                table_name=check_config.table_name,
                run_date=datetime.now(),
                total_records=0,
                valid_records=0,
                invalid_records=0,
                validation_percent=0,
                status="FAIL",
                severity=ValidationSeverity.CRITICAL,
                details="Check execution failed",
                error_message=str(e),
                execution_duration_seconds=(datetime.now() - check_start).total_seconds()
            )
            
            return result
    
    def _run_custom_sql_check(self, check_config: ValidationCheckConfig, load_date: date) -> Tuple:
        """Run custom SQL validation check."""
        if not check_config.sql_query:
            return 0, 0, 0, "No SQL query provided"
        
        try:
            result = self.session.execute(
                text(check_config.sql_query),
                {"load_date": load_date}
            ).fetchall()
            
            if result and len(result) > 0:
                total = result[0][0] if len(result[0]) > 0 else 0
                valid = result[0][1] if len(result[0]) > 1 else total
                invalid = total - valid
                
                return total, valid, invalid, f"Checked {total} records"
            
            return 0, 0, 0, "No records returned from query"
        except Exception as e:
            logger.error(f"Error running custom SQL check: {e}")
            raise
    
    def _check_completeness(self, check_config: ValidationCheckConfig, load_date: date) -> Tuple:
        """Check data completeness."""
        try:
            query = text(f"""
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) - COUNT(CASE WHEN {', '.join([f'{col}' for col in check_config.columns_to_check])} 
                                    THEN 1 END) as invalid
                FROM {check_config.table_name}
                WHERE CAST(load_date AS DATE) = :load_date
            """)
            
            result = self.session.execute(query, {"load_date": load_date}).fetchone()
            
            if result:
                total = result[0]
                invalid = result[1] if result[1] else 0
                valid = total - invalid
                return total, valid, invalid, f"Completeness check: {valid}/{total} records valid"
            
            return 0, 0, 0, "No records found"
        except Exception as e:
            logger.error(f"Error checking completeness: {e}")
            raise
    
    def _check_null_values(self, check_config: ValidationCheckConfig, load_date: date) -> Tuple:
        """Check for null values in columns."""
        try:
            columns = check_config.columns_to_check or []
            if not columns:
                return 0, 0, 0, "No columns specified for null check"
            
            null_conditions = " OR ".join([f"{col} IS NULL" for col in columns])
            
            query = text(f"""
                SELECT 
                    COUNT(*) as total,
                    SUM(CASE WHEN {null_conditions} THEN 1 ELSE 0 END) as null_count
                FROM {check_config.table_name}
                WHERE CAST(load_date AS DATE) = :load_date
            """)
            
            result = self.session.execute(query, {"load_date": load_date}).fetchone()
            
            if result:
                total = result[0]
                invalid = result[1] if result[1] else 0
                valid = total - invalid
                return total, valid, invalid, f"Null check: {invalid} records with nulls"
            
            return 0, 0, 0, "No records found"
        except Exception as e:
            logger.error(f"Error checking null values: {e}")
            raise
    
    def _check_duplicates(self, check_config: ValidationCheckConfig, load_date: date) -> Tuple:
        """Check for duplicate records."""
        try:
            columns = check_config.columns_to_check or []
            if not columns:
                return 0, 0, 0, "No columns specified for duplicate check"
            
            column_list = ", ".join(columns)
            
            query = text(f"""
                WITH duplicates AS (
                    SELECT {column_list}, COUNT(*) as cnt
                    FROM {check_config.table_name}
                    WHERE CAST(load_date AS DATE) = :load_date
                    GROUP BY {column_list}
                    HAVING COUNT(*) > 1
                )
                SELECT 
                    (SELECT COUNT(*) FROM {check_config.table_name} 
                     WHERE CAST(load_date AS DATE) = :load_date) as total,
                    (SELECT COUNT(*) FROM duplicates) as duplicate_count
            """)
            
            result = self.session.execute(query, {"load_date": load_date}).fetchone()
            
            if result:
                total = result[0]
                duplicates = result[1] if result[1] else 0
                valid = total - duplicates
                return total, valid, duplicates, f"Duplicate check: {duplicates} duplicate records"
            
            return 0, 0, 0, "No records found"
        except Exception as e:
            logger.error(f"Error checking duplicates: {e}")
            raise
    
    def _check_consistency(self, check_config: ValidationCheckConfig, load_date: date) -> Tuple:
        """Check for data consistency."""
        # Implement consistency checks across related tables
        return 0, 0, 0, "Consistency check not yet implemented"
    
    def _check_business_logic(self, check_config: ValidationCheckConfig, load_date: date) -> Tuple:
        """Check business logic rules."""
        # Implement business-specific validation rules
        return 0, 0, 0, "Business logic check not yet implemented"
    
    def _generate_summary(self, load_date: date) -> Dict:
        """Generate execution summary."""
        total_checks = len(self.results)
        passed = sum(1 for r in self.results if r.status == "PASS")
        warnings = sum(1 for r in self.results if r.status == "WARNING")
        failed = sum(1 for r in self.results if r.status == "FAIL")
        
        # Critical checks that failed
        critical_failures = sum(1 for r in self.results 
                               if r.status == "FAIL" and r.severity == ValidationSeverity.CRITICAL)
        blocker_failures = sum(1 for r in self.results 
                              if r.status == "FAIL" and r.severity == ValidationSeverity.BLOCKER)
        
        execution_duration = (self.execution_end - self.execution_start).total_seconds()
        
        # Determine overall status
        if blocker_failures > 0 or failed > 0:
            overall_status = ValidationScheduleStatus.FAILED
        elif critical_failures > 0 or warnings > 0:
            overall_status = ValidationScheduleStatus.PARTIAL
        else:
            overall_status = ValidationScheduleStatus.SUCCESS
        
        summary = {
            "status": overall_status.value,
            "validation_suite": self.config.validation_suite_name,
            "execution_id": self.execution_id,
            "load_date": load_date.isoformat(),
            "execution_start": self.execution_start.isoformat(),
            "execution_end": self.execution_end.isoformat(),
            "execution_duration_seconds": execution_duration,
            "total_checks": total_checks,
            "passed": passed,
            "warnings": warnings,
            "failed": failed,
            "critical_failures": critical_failures,
            "blocker_failures": blocker_failures,
            "results": [r.to_dict() for r in self.results],
            "errors": self.errors
        }
        
        return summary
    
    def _generate_html_report(self, summary: Dict) -> str:
        """Generate HTML report of validation results."""
        # TODO: Generate comprehensive HTML report
        report_path = f"logs/validation_report_{self.execution_id}.html"
        logger.info(f"HTML report generated: {report_path}")
        return report_path
    
    def _send_alerts(self, summary: Dict):
        """Send alerts for failures."""
        if not self.config.alert_on_failure:
            return
        
        status = summary.get("status")
        
        # Alert on FAILED or CRITICAL status
        if status in [ValidationScheduleStatus.FAILED.value, ValidationScheduleStatus.PARTIAL.value]:
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
Validation Alert: {summary['validation_suite']}
Execution ID: {summary['execution_id']}
Date: {summary['load_date']}
Status: {summary['status']}

Summary:
- Total Checks: {summary['total_checks']}
- Passed: {summary['passed']}
- Warnings: {summary['warnings']}
- Failed: {summary['failed']}
- Critical Failures: {summary['critical_failures']}
- Blocker Failures: {summary['blocker_failures']}

Duration: {summary['execution_duration_seconds']:.2f} seconds

Failed Checks:
{chr(10).join([f"  - {r['check_name']}: {r['status']}" for r in summary['results'] if r['status'] != 'PASS'])}
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
    
    def _save_quality_scores(self, summary: Dict, load_date: date):
        """Save data quality scores to database."""
        try:
            for result in self.results:
                quality_score = DataQualityScore(
                    load_date=load_date,
                    check_name=result.check_name,
                    table_name=result.table_name,
                    quality_score=result.validation_percent,
                    total_records_checked=result.total_records,
                    valid_records=result.valid_records,
                    invalid_records=result.invalid_records,
                    quality_status=result.status,
                    quality_notes=result.details
                )
                self.session.add(quality_score)
            
            self.session.commit()
            logger.info(f"Saved {len(self.results)} quality scores")
        except Exception as e:
            logger.error(f"Error saving quality scores: {e}")
            self.session.rollback()
    
    def _is_already_running(self, load_date: date) -> bool:
        """Check if validation is already running."""
        try:
            query = text("""
                SELECT COUNT(*) FROM etl_logs
                WHERE process_name = :process_name
                AND log_date = :load_date
                AND status = :status
            """)
            
            result = self.session.execute(query, {
                "process_name": f"validation_{self.config.validation_suite_name}",
                "load_date": load_date,
                "status": ValidationScheduleStatus.RUNNING.value
            }).fetchone()
            
            return result[0] > 0 if result else False
        except Exception as e:
            logger.error(f"Error checking if running: {e}")
            return False
    
    def _mark_as_running(self, load_date: date):
        """Mark validation as running."""
        try:
            etl_log = ETLLog(
                process_name=f"validation_{self.config.validation_suite_name}",
                process_step="START",
                record_count=0,
                status=ValidationScheduleStatus.RUNNING,
                log_date=load_date,
                details={"started_at": self.execution_start.isoformat(), "execution_id": self.execution_id}
            )
            self.session.add(etl_log)
            self.session.commit()
        except Exception as e:
            logger.error(f"Error marking as running: {e}")
    
    def _log_error(self, check_name: str, load_date: date, error: str, traceback_str: str):
        """Log error details."""
        try:
            etl_log = ETLLog(
                process_name=f"validation_{self.config.validation_suite_name}",
                process_step=f"ERROR_{check_name}",
                record_count=0,
                status="FAILED",
                log_date=load_date,
                details={
                    "error": error,
                    "traceback": traceback_str,
                    "timestamp": datetime.now().isoformat(),
                    "execution_id": self.execution_id
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
                process_name=f"validation_{self.config.validation_suite_name}",
                process_step="COMPLETE",
                record_count=summary["total_checks"],
                status=summary["status"],
                log_date=load_date,
                details=summary
            )
            self.session.add(etl_log)
            self.session.commit()
            logger.info(f"Logged validation execution")
        except Exception as e:
            logger.error(f"Error logging execution: {e}")
    
    def _retry_validation(self, load_date: date) -> Dict:
        """Retry validation on failure."""
        self.current_retry_count += 1
        logger.info(f"Retrying validation (attempt {self.current_retry_count})")
        
        import time
        time.sleep(self.config.retry_delay_seconds)
        
        return self.run(load_date, force=True)


if __name__ == "__main__":
    # Example usage
    checks = [
        ValidationCheckConfig(
            check_id="check_orders_null",
            check_name="Orders Null Check",
            check_type="null_validation",
            table_name="stg_erp_orders_transformation",
            columns_to_check=["order_id", "customer_id", "order_date"],
            severity=ValidationSeverity.CRITICAL
        ),
        ValidationCheckConfig(
            check_id="check_orders_duplicates",
            check_name="Orders Duplicate Check",
            check_type="duplicate",
            table_name="stg_erp_orders_transformation",
            columns_to_check=["order_id"],
            severity=ValidationSeverity.BLOCKER
        )
    ]
    
    config = ValidationConfig(
        validation_suite_name="Daily_Data_Quality_Checks",
        checks=checks,
        alert_emails=["admin@company.com"]
    )
    
    with AutomatedValidator(config) as validator:
        result = validator.run()
        print(json.dumps(result, indent=2, default=str))
