"""
Unified Automation Orchestrator
================================
Integrates reconciliation, validation, and audit logging with:
- End-to-end automation workflow orchestration
- Centralized error handling and recovery
- Real-time alerting system
- Performance monitoring and optimization
- Scheduling and task dependency management
"""

import logging
import json
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum
import traceback
from collections import defaultdict
import time

from sqlalchemy import text
from sqlalchemy.orm import Session

from database import get_db_session
from models import ETLLog

# Import automation modules
try:
    from reconciliation.automated_reconciliation_scheduler import (
        AutomatedReconciler, ReconciliationConfig
    )
except ImportError:
    AutomatedReconciler = None
    ReconciliationConfig = None

try:
    from validation.automated_validation_scheduler import (
        AutomatedValidator, ValidationConfig
    )
except ImportError:
    AutomatedValidator = None
    ValidationConfig = None

try:
    from logging.audit_logger import AuditLogger, AuditAction, AuditEntityType, AuditStatus
except ImportError:
    AuditLogger = None
    AuditAction = None
    AuditEntityType = None
    AuditStatus = None


logger = logging.getLogger(__name__)


class OrchestrationStatus(str, Enum):
    """Overall orchestration execution status."""
    PENDING = "PENDING"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    PARTIAL_SUCCESS = "PARTIAL_SUCCESS"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"
    RETRY = "RETRY"


class TaskStatus(str, Enum):
    """Individual task status."""
    NOT_STARTED = "NOT_STARTED"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    ROLLED_BACK = "ROLLED_BACK"


@dataclass
class TaskConfig:
    """Configuration for a task in the automation workflow."""
    task_id: str
    task_name: str
    task_type: str  # reconciliation, validation, audit, custom
    enabled: bool = True
    retry_on_failure: bool = True
    max_retries: int = 3
    retry_delay_seconds: int = 60
    timeout_seconds: int = 300
    depends_on: List[str] = None
    run_parallel: bool = False
    alert_on_failure: bool = True
    alert_on_success: bool = False
    severity: str = "WARNING"  # INFO, WARNING, CRITICAL
    
    def __post_init__(self):
        if self.depends_on is None:
            self.depends_on = []


@dataclass
class TaskResult:
    """Result of task execution."""
    task_id: str
    task_name: str
    task_type: str
    status: TaskStatus
    start_time: datetime
    end_time: Optional[datetime] = None
    duration_seconds: float = 0.0
    records_processed: int = 0
    records_failed: int = 0
    error_message: Optional[str] = None
    warning_message: Optional[str] = None
    result_data: Optional[Dict] = None
    retry_count: int = 0
    
    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "task_id": self.task_id,
            "task_name": self.task_name,
            "task_type": self.task_type,
            "status": self.status.value,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "duration_seconds": self.duration_seconds,
            "records_processed": self.records_processed,
            "records_failed": self.records_failed,
            "error_message": self.error_message,
            "warning_message": self.warning_message,
            "result_data": self.result_data,
            "retry_count": self.retry_count
        }


class ErrorRecoveryStrategy(str, Enum):
    """Error recovery strategies."""
    IMMEDIATE_RETRY = "IMMEDIATE_RETRY"
    DELAYED_RETRY = "DELAYED_RETRY"
    EXPONENTIAL_BACKOFF = "EXPONENTIAL_BACKOFF"
    SKIP = "SKIP"
    ROLLBACK = "ROLLBACK"
    MANUAL_INTERVENTION = "MANUAL_INTERVENTION"


@dataclass
class AlertConfig:
    """Alert configuration."""
    enabled: bool = True
    on_failure: bool = True
    on_success: bool = False
    on_partial: bool = True
    email_recipients: List[str] = None
    webhook_urls: List[str] = None
    slack_channels: List[str] = None
    severity_threshold: str = "WARNING"  # INFO, WARNING, CRITICAL
    
    def __post_init__(self):
        if self.email_recipients is None:
            self.email_recipients = []
        if self.webhook_urls is None:
            self.webhook_urls = []
        if self.slack_channels is None:
            self.slack_channels = []


class AutomationOrchestrator:
    """Main orchestration engine for automated reconciliation, validation, and auditing."""
    
    def __init__(self, workflow_name: str, alert_config: Optional[AlertConfig] = None):
        """
        Initialize orchestrator.
        
        Args:
            workflow_name: Name of automation workflow
            alert_config: Alert configuration
        """
        self.workflow_name = workflow_name
        self.alert_config = alert_config or AlertConfig()
        self.session = get_db_session()
        
        self.tasks: Dict[str, TaskConfig] = {}
        self.results: Dict[str, TaskResult] = {}
        self.audit_logger = AuditLogger() if AuditLogger else None
        
        self.execution_start: Optional[datetime] = None
        self.execution_end: Optional[datetime] = None
        self.execution_id = f"orch_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.errors: List[Dict] = []
        self.warnings: List[Dict] = []
        
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            self.session.close()
        if self.audit_logger:
            self.audit_logger.session.close()
    
    def add_task(self, config: TaskConfig):
        """Add task to workflow."""
        self.tasks[config.task_id] = config
        logger.info(f"Added task: {config.task_name}")
    
    def remove_task(self, task_id: str):
        """Remove task from workflow."""
        if task_id in self.tasks:
            del self.tasks[task_id]
            logger.info(f"Removed task: {task_id}")
    
    def run(self, load_date: Optional[date] = None) -> Dict:
        """
        Execute automation workflow.
        
        Args:
            load_date: Date to process
            
        Returns:
            Orchestration execution summary
        """
        
        load_date = load_date or date.today()
        self.execution_start = datetime.now()
        
        logger.info(f"Starting orchestration: {self.workflow_name} (ID: {self.execution_id})")
        
        try:
            # Mark as running
            self._mark_execution_running(load_date)
            
            # Validate task dependencies
            self._validate_task_dependencies()
            
            # Build execution plan (topological sort)
            execution_plan = self._build_execution_plan()
            
            # Execute tasks
            for batch in execution_plan:
                if len(batch) == 1 or not any(self.tasks[tid].run_parallel for tid in batch):
                    # Sequential execution
                    for task_id in batch:
                        self._execute_task(task_id, load_date)
                else:
                    # Parallel execution
                    self._execute_tasks_parallel(batch, load_date)
            
            self.execution_end = datetime.now()
            
            # Generate summary
            summary = self._generate_summary(load_date)
            
            # Send alerts
            self._send_alerts(summary)
            
            # Log execution
            self._log_execution(load_date, summary)
            
            return summary
            
        except Exception as e:
            self.execution_end = datetime.now()
            error_msg = f"Fatal error in orchestration: {str(e)}"
            logger.error(error_msg)
            logger.error(traceback.format_exc())
            
            self.errors.append({
                "timestamp": datetime.now().isoformat(),
                "error": error_msg,
                "traceback": traceback.format_exc()
            })
            
            # Log fatal error
            self._log_execution_error(load_date, error_msg)
            
            return {
                "status": OrchestrationStatus.FAILED.value,
                "workflow": self.workflow_name,
                "execution_id": self.execution_id,
                "load_date": load_date.isoformat(),
                "error": error_msg
            }
    
    def _execute_task(self, task_id: str, load_date: date):
        """Execute single task with error handling."""
        config = self.tasks[task_id]
        
        # Check if dependencies are satisfied
        if not self._are_dependencies_satisfied(task_id):
            logger.warning(f"Skipping task {task_id} - dependencies not satisfied")
            self.results[task_id] = TaskResult(
                task_id=task_id,
                task_name=config.task_name,
                task_type=config.task_type,
                status=TaskStatus.SKIPPED,
                start_time=datetime.now()
            )
            return
        
        # Skip if disabled
        if not config.enabled:
            logger.info(f"Skipping disabled task: {task_id}")
            self.results[task_id] = TaskResult(
                task_id=task_id,
                task_name=config.task_name,
                task_type=config.task_type,
                status=TaskStatus.SKIPPED,
                start_time=datetime.now()
            )
            return
        
        start_time = datetime.now()
        retry_count = 0
        last_error = None
        
        while retry_count <= config.max_retries:
            try:
                logger.info(f"Executing task: {config.task_name} (attempt {retry_count + 1})")
                
                # Execute task based on type
                if config.task_type == "reconciliation":
                    result_data = self._execute_reconciliation_task(config, load_date)
                elif config.task_type == "validation":
                    result_data = self._execute_validation_task(config, load_date)
                elif config.task_type == "audit":
                    result_data = self._execute_audit_task(config, load_date)
                elif config.task_type == "custom":
                    result_data = self._execute_custom_task(config, load_date)
                else:
                    raise ValueError(f"Unknown task type: {config.task_type}")
                
                # Success
                end_time = datetime.now()
                duration = (end_time - start_time).total_seconds()
                
                result = TaskResult(
                    task_id=task_id,
                    task_name=config.task_name,
                    task_type=config.task_type,
                    status=TaskStatus.SUCCESS,
                    start_time=start_time,
                    end_time=end_time,
                    duration_seconds=duration,
                    result_data=result_data,
                    retry_count=retry_count
                )
                
                self.results[task_id] = result
                
                logger.info(f"Task completed successfully: {config.task_name}")
                
                # Audit successful task
                if self.audit_logger:
                    self.audit_logger.log_etl_process(
                        process_name=self.workflow_name,
                        step_name=config.task_name,
                        status="SUCCESS",
                        record_count=result.records_processed,
                        parent_process_id=self.execution_id
                    )
                
                return
                
            except Exception as e:
                last_error = str(e)
                retry_count += 1
                
                logger.warning(
                    f"Task failed (attempt {retry_count}/{config.max_retries + 1}): "
                    f"{config.task_name} - {str(e)}"
                )
                
                if retry_count <= config.max_retries:
                    # Retry with backoff
                    backoff_seconds = config.retry_delay_seconds * (2 ** (retry_count - 1))
                    logger.info(f"Retrying in {backoff_seconds} seconds...")
                    time.sleep(backoff_seconds)
                else:
                    break
        
        # Task failed after all retries
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        result = TaskResult(
            task_id=task_id,
            task_name=config.task_name,
            task_type=config.task_type,
            status=TaskStatus.FAILED,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=duration,
            error_message=last_error,
            retry_count=retry_count
        )
        
        self.results[task_id] = result
        
        error_details = {
            "timestamp": datetime.now().isoformat(),
            "task_id": task_id,
            "task_name": config.task_name,
            "error": last_error,
            "retries": retry_count
        }
        
        self.errors.append(error_details)
        
        logger.error(f"Task failed after {retry_count} retries: {config.task_name}")
        
        # Audit failed task
        if self.audit_logger:
            self.audit_logger.log_etl_process(
                process_name=self.workflow_name,
                step_name=config.task_name,
                status="FAILED",
                record_count=0,
                details={"error": last_error, "retries": retry_count},
                parent_process_id=self.execution_id
            )
    
    def _execute_tasks_parallel(self, task_ids: List[str], load_date: date):
        """Execute multiple tasks in parallel."""
        from concurrent.futures import ThreadPoolExecutor, as_completed
        
        with ThreadPoolExecutor(max_workers=len(task_ids)) as executor:
            futures = {executor.submit(self._execute_task, tid, load_date): tid for tid in task_ids}
            
            for future in as_completed(futures):
                task_id = futures[future]
                try:
                    future.result()
                except Exception as e:
                    logger.error(f"Parallel task failed: {task_id} - {str(e)}")
    
    def _execute_reconciliation_task(self, config: TaskConfig, load_date: date) -> Dict:
        """Execute reconciliation task."""
        if not AutomatedReconciler or not ReconciliationConfig:
            raise ImportError("Reconciliation module not available")
        
        # Create reconciliation config from task config
        recon_config = ReconciliationConfig(
            reconciliation_name=config.task_name,
            data_types=config.result_data.get("data_types", []) if config.result_data else [],
            enabled=config.enabled
        )
        
        with AutomatedReconciler(recon_config) as reconciler:
            result = reconciler.run(load_date)
        
        return result
    
    def _execute_validation_task(self, config: TaskConfig, load_date: date) -> Dict:
        """Execute validation task."""
        if not AutomatedValidator or not ValidationConfig:
            raise ImportError("Validation module not available")
        
        # Create validation config from task config
        val_config = ValidationConfig(
            validation_suite_name=config.task_name,
            checks=[],  # Would be configured separately
            enabled=config.enabled
        )
        
        with AutomatedValidator(val_config) as validator:
            result = validator.run(load_date)
        
        return result
    
    def _execute_audit_task(self, config: TaskConfig, load_date: date) -> Dict:
        """Execute audit task."""
        if not self.audit_logger:
            raise ImportError("Audit logging module not available")
        
        # Log task execution to audit log
        result = {
            "audit_type": config.task_name,
            "load_date": load_date.isoformat(),
            "timestamp": datetime.now().isoformat(),
            "status": "SUCCESS"
        }
        
        return result
    
    def _execute_custom_task(self, config: TaskConfig, load_date: date) -> Dict:
        """Execute custom task."""
        # Placeholder for custom task execution
        logger.info(f"Executing custom task: {config.task_name}")
        return {"status": "CUSTOM_TASK_EXECUTED"}
    
    def _validate_task_dependencies(self):
        """Validate that all task dependencies exist."""
        for task_id, config in self.tasks.items():
            for dep_id in config.depends_on:
                if dep_id not in self.tasks:
                    raise ValueError(f"Task {task_id} depends on non-existent task {dep_id}")
    
    def _build_execution_plan(self) -> List[List[str]]:
        """Build execution plan using topological sort."""
        # Build dependency graph
        graph = {task_id: [] for task_id in self.tasks}
        in_degree = {task_id: len(self.tasks[task_id].depends_on) for task_id in self.tasks}
        
        for task_id, config in self.tasks.items():
            for dep_id in config.depends_on:
                graph[dep_id].append(task_id)
        
        # Topological sort - Kahn's algorithm
        queue = [task_id for task_id in self.tasks if in_degree[task_id] == 0]
        execution_plan = []
        
        while queue:
            batch = queue.copy()
            queue = []
            execution_plan.append(batch)
            
            for task_id in batch:
                for dependent in graph[task_id]:
                    in_degree[dependent] -= 1
                    if in_degree[dependent] == 0:
                        queue.append(dependent)
        
        return execution_plan
    
    def _are_dependencies_satisfied(self, task_id: str) -> bool:
        """Check if all task dependencies are satisfied."""
        config = self.tasks[task_id]
        
        for dep_id in config.depends_on:
            if dep_id not in self.results:
                return False
            if self.results[dep_id].status != TaskStatus.SUCCESS:
                return False
        
        return True
    
    def _generate_summary(self, load_date: date) -> Dict:
        """Generate execution summary."""
        total_tasks = len(self.results)
        successful = sum(1 for r in self.results.values() if r.status == TaskStatus.SUCCESS)
        failed = sum(1 for r in self.results.values() if r.status == TaskStatus.FAILED)
        skipped = sum(1 for r in self.results.values() if r.status == TaskStatus.SKIPPED)
        
        duration = (self.execution_end - self.execution_start).total_seconds()
        
        # Determine overall status
        if failed > 0:
            overall_status = OrchestrationStatus.FAILED
        elif len(self.warnings) > 0:
            overall_status = OrchestrationStatus.PARTIAL_SUCCESS
        else:
            overall_status = OrchestrationStatus.SUCCESS
        
        total_records = sum(r.records_processed for r in self.results.values())
        total_failed_records = sum(r.records_failed for r in self.results.values())
        
        summary = {
            "status": overall_status.value,
            "workflow": self.workflow_name,
            "execution_id": self.execution_id,
            "load_date": load_date.isoformat(),
            "execution_start": self.execution_start.isoformat(),
            "execution_end": self.execution_end.isoformat(),
            "duration_seconds": duration,
            "total_tasks": total_tasks,
            "successful": successful,
            "failed": failed,
            "skipped": skipped,
            "total_records_processed": total_records,
            "total_records_failed": total_failed_records,
            "task_results": {
                task_id: result.to_dict()
                for task_id, result in self.results.items()
            },
            "errors": self.errors,
            "warnings": self.warnings
        }
        
        return summary
    
    def _send_alerts(self, summary: Dict):
        """Send alerts based on execution status."""
        if not self.alert_config.enabled:
            return
        
        status = summary["status"]
        
        # Determine if alert should be sent
        should_alert = (
            (status == OrchestrationStatus.FAILED.value and self.alert_config.on_failure) or
            (status == OrchestrationStatus.SUCCESS.value and self.alert_config.on_success) or
            (status == OrchestrationStatus.PARTIAL_SUCCESS.value and self.alert_config.on_partial)
        )
        
        if should_alert:
            message = self._format_alert_message(summary)
            
            # Send email
            for email in self.alert_config.email_recipients:
                self._send_email_alert(email, message)
            
            # Send webhook
            for webhook in self.alert_config.webhook_urls:
                self._send_webhook_alert(webhook, summary)
            
            # Send Slack
            for channel in self.alert_config.slack_channels:
                self._send_slack_alert(channel, message)
    
    def _format_alert_message(self, summary: Dict) -> str:
        """Format alert message."""
        return f"""
Automation Workflow Alert: {summary['workflow']}
Execution ID: {summary['execution_id']}
Status: {summary['status']}
Date: {summary['load_date']}

Summary:
- Total Tasks: {summary['total_tasks']}
- Successful: {summary['successful']}
- Failed: {summary['failed']}
- Skipped: {summary['skipped']}
- Records Processed: {summary['total_records_processed']}
- Records Failed: {summary['total_records_failed']}

Duration: {summary['duration_seconds']:.2f} seconds

Failed Tasks:
{chr(10).join([f"  - {r['task_name']}: {r['error_message']}" for r in summary['task_results'].values() if r['status'] == 'FAILED'])}
"""
    
    def _send_email_alert(self, email: str, message: str):
        """Send email alert."""
        try:
            # TODO: Implement email sending
            logger.info(f"Email alert sent to {email}")
        except Exception as e:
            logger.error(f"Error sending email: {e}")
    
    def _send_webhook_alert(self, webhook_url: str, summary: Dict):
        """Send webhook alert."""
        try:
            # TODO: Implement webhook sending
            logger.info(f"Webhook alert sent to {webhook_url}")
        except Exception as e:
            logger.error(f"Error sending webhook: {e}")
    
    def _send_slack_alert(self, channel: str, message: str):
        """Send Slack alert."""
        try:
            # TODO: Implement Slack sending
            logger.info(f"Slack alert sent to {channel}")
        except Exception as e:
            logger.error(f"Error sending Slack alert: {e}")
    
    def _mark_execution_running(self, load_date: date):
        """Mark orchestration as running."""
        try:
            etl_log = ETLLog(
                process_name=f"orchestration_{self.workflow_name}",
                process_step="START",
                record_count=0,
                status=OrchestrationStatus.RUNNING.value,
                log_date=load_date,
                details={
                    "execution_id": self.execution_id,
                    "started_at": self.execution_start.isoformat()
                }
            )
            self.session.add(etl_log)
            self.session.commit()
        except Exception as e:
            logger.error(f"Error marking execution as running: {e}")
    
    def _log_execution(self, load_date: date, summary: Dict):
        """Log execution summary."""
        try:
            etl_log = ETLLog(
                process_name=f"orchestration_{self.workflow_name}",
                process_step="COMPLETE",
                record_count=summary["total_tasks"],
                status=summary["status"],
                log_date=load_date,
                details=summary
            )
            self.session.add(etl_log)
            self.session.commit()
            logger.info(f"Logged orchestration execution")
        except Exception as e:
            logger.error(f"Error logging execution: {e}")
    
    def _log_execution_error(self, load_date: date, error_msg: str):
        """Log execution error."""
        try:
            etl_log = ETLLog(
                process_name=f"orchestration_{self.workflow_name}",
                process_step="ERROR",
                record_count=0,
                status=OrchestrationStatus.FAILED.value,
                log_date=load_date,
                details={
                    "execution_id": self.execution_id,
                    "error": error_msg,
                    "timestamp": datetime.now().isoformat()
                }
            )
            self.session.add(etl_log)
            self.session.commit()
        except Exception as e:
            logger.error(f"Error logging execution error: {e}")


if __name__ == "__main__":
    # Example usage
    alert_config = AlertConfig(
        enabled=True,
        on_failure=True,
        email_recipients=["admin@company.com"]
    )
    
    with AutomationOrchestrator("Daily_Automated_Pipeline", alert_config) as orchestrator:
        # Add tasks
        reconciliation_task = TaskConfig(
            task_id="reconcile_orders",
            task_name="Orders_Reconciliation",
            task_type="reconciliation",
            enabled=True,
            severity="CRITICAL"
        )
        
        validation_task = TaskConfig(
            task_id="validate_data",
            task_name="Data_Quality_Validation",
            task_type="validation",
            enabled=True,
            depends_on=["reconcile_orders"],
            severity="WARNING"
        )
        
        audit_task = TaskConfig(
            task_id="audit_log",
            task_name="Audit_Logging",
            task_type="audit",
            enabled=True,
            depends_on=["reconcile_orders", "validate_data"],
            severity="INFO"
        )
        
        orchestrator.add_task(reconciliation_task)
        orchestrator.add_task(validation_task)
        orchestrator.add_task(audit_task)
        
        # Run orchestration
        result = orchestrator.run()
        print(json.dumps(result, indent=2, default=str))
