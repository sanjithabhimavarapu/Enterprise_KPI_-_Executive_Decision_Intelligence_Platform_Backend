"""
Comprehensive Audit Logging System
===================================
Automated audit trail management for:
- ETL process tracking
- Data lineage tracking
- Change data capture (CDC)
- Compliance and regulatory reporting
- Access and modification auditing
- Data recovery and rollback support
"""

import logging
import json
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum
from decimal import Decimal
import hashlib
import socket
import getpass

from sqlalchemy import func, text
from sqlalchemy.orm import Session

from database import get_db_session
from models import ETLLog


logger = logging.getLogger(__name__)


class AuditAction(str, Enum):
    """Audit action types."""
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"
    READ = "READ"
    EXECUTE = "EXECUTE"
    VALIDATE = "VALIDATE"
    RECONCILE = "RECONCILE"
    ROLLBACK = "ROLLBACK"
    ARCHIVE = "ARCHIVE"
    EXPORT = "EXPORT"


class AuditEntityType(str, Enum):
    """Types of entities being audited."""
    TABLE = "TABLE"
    RECORD = "RECORD"
    PROCESS = "PROCESS"
    JOB = "JOB"
    PIPELINE = "PIPELINE"
    SCHEDULE = "SCHEDULE"


class AuditStatus(str, Enum):
    """Status of audited action."""
    SUCCESS = "SUCCESS"
    FAILURE = "FAILURE"
    PARTIAL = "PARTIAL"
    PENDING = "PENDING"
    ROLLED_BACK = "ROLLED_BACK"


@dataclass
class AuditContext:
    """Context information for audit entry."""
    user_id: str
    session_id: str
    ip_address: str
    hostname: str
    application: str = "ETL_Pipeline"
    module: str = "Unknown"
    request_id: Optional[str] = None
    
    @staticmethod
    def create_current() -> 'AuditContext':
        """Create audit context from current environment."""
        return AuditContext(
            user_id=getpass.getuser(),
            session_id=f"{datetime.now().timestamp()}",
            ip_address=socket.gethostbyname(socket.gethostname()),
            hostname=socket.gethostname(),
            application="ETL_Pipeline"
        )


@dataclass
class AuditEntry:
    """Single audit log entry."""
    audit_id: str
    action: AuditAction
    entity_type: AuditEntityType
    entity_name: str
    entity_id: Optional[str]
    timestamp: datetime
    status: AuditStatus
    record_count: int
    
    # Context information
    user_id: str
    session_id: str
    ip_address: str
    hostname: str
    
    # Data change details
    change_summary: Dict[str, Any]
    before_values: Optional[Dict[str, Any]] = None
    after_values: Optional[Dict[str, Any]] = None
    changed_fields: List[str] = None
    
    # Error/status information
    error_message: Optional[str] = None
    warning_message: Optional[str] = None
    
    # Performance metrics
    duration_seconds: float = 0.0
    affected_rows: int = 0
    
    # Lineage and traceability
    parent_process_id: Optional[str] = None
    parent_job_id: Optional[str] = None
    source_system: Optional[str] = None
    target_system: Optional[str] = None
    
    def __post_init__(self):
        if self.changed_fields is None:
            self.changed_fields = []
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for storage."""
        return {
            "audit_id": self.audit_id,
            "action": self.action.value,
            "entity_type": self.entity_type.value,
            "entity_name": self.entity_name,
            "entity_id": self.entity_id,
            "timestamp": self.timestamp.isoformat(),
            "status": self.status.value,
            "record_count": self.record_count,
            "user_id": self.user_id,
            "session_id": self.session_id,
            "ip_address": self.ip_address,
            "hostname": self.hostname,
            "change_summary": self.change_summary,
            "before_values": self.before_values,
            "after_values": self.after_values,
            "changed_fields": self.changed_fields,
            "error_message": self.error_message,
            "warning_message": self.warning_message,
            "duration_seconds": self.duration_seconds,
            "affected_rows": self.affected_rows,
            "parent_process_id": self.parent_process_id,
            "parent_job_id": self.parent_job_id,
            "source_system": self.source_system,
            "target_system": self.target_system
        }


class AuditLogger:
    """Comprehensive audit logging system."""
    
    def __init__(self, context: Optional[AuditContext] = None):
        """
        Initialize audit logger.
        
        Args:
            context: Audit context (user, session, etc.)
        """
        self.context = context or AuditContext.create_current()
        self.session = get_db_session()
        self.audit_entries: List[AuditEntry] = []
        self.enable_local_journal = True
        
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            self.session.close()
    
    def log_action(
        self,
        action: AuditAction,
        entity_type: AuditEntityType,
        entity_name: str,
        entity_id: Optional[str] = None,
        status: AuditStatus = AuditStatus.SUCCESS,
        record_count: int = 0,
        change_summary: Optional[Dict] = None,
        before_values: Optional[Dict] = None,
        after_values: Optional[Dict] = None,
        error_message: Optional[str] = None,
        duration_seconds: float = 0.0,
        affected_rows: int = 0,
        parent_process_id: Optional[str] = None,
        parent_job_id: Optional[str] = None,
        source_system: Optional[str] = None,
        target_system: Optional[str] = None
    ) -> AuditEntry:
        """
        Log an audit action.
        
        Args:
            action: Type of action performed
            entity_type: Type of entity affected
            entity_name: Name of entity
            entity_id: Unique identifier of entity
            status: Status of action
            record_count: Number of records involved
            change_summary: Summary of changes
            before_values: Values before change
            after_values: Values after change
            error_message: Error details if failed
            duration_seconds: Execution time
            affected_rows: Number of rows affected
            parent_process_id: Parent process ID for lineage
            parent_job_id: Parent job ID for lineage
            source_system: Source system for data
            target_system: Target system for data
            
        Returns:
            AuditEntry
        """
        
        audit_id = self._generate_audit_id(entity_name, entity_id)
        
        # Determine changed fields
        changed_fields = []
        if before_values and after_values:
            changed_fields = self._identify_changed_fields(before_values, after_values)
        
        entry = AuditEntry(
            audit_id=audit_id,
            action=action,
            entity_type=entity_type,
            entity_name=entity_name,
            entity_id=entity_id,
            timestamp=datetime.now(),
            status=status,
            record_count=record_count,
            user_id=self.context.user_id,
            session_id=self.context.session_id,
            ip_address=self.context.ip_address,
            hostname=self.context.hostname,
            change_summary=change_summary or {},
            before_values=before_values,
            after_values=after_values,
            changed_fields=changed_fields,
            error_message=error_message,
            duration_seconds=duration_seconds,
            affected_rows=affected_rows,
            parent_process_id=parent_process_id,
            parent_job_id=parent_job_id,
            source_system=source_system,
            target_system=target_system
        )
        
        self.audit_entries.append(entry)
        self._persist_audit_entry(entry)
        
        log_level = logging.ERROR if status == AuditStatus.FAILURE else logging.INFO
        logger.log(
            log_level,
            f"Audit: {action.value} {entity_type.value} {entity_name} - {status.value}"
        )
        
        return entry
    
    def log_etl_process(
        self,
        process_name: str,
        step_name: str,
        status: str,
        record_count: int,
        details: Optional[Dict] = None,
        parent_process_id: Optional[str] = None,
        source_system: Optional[str] = None,
        target_system: Optional[str] = None
    ) -> AuditEntry:
        """
        Log ETL process execution.
        
        Args:
            process_name: Name of ETL process
            step_name: Step within process
            status: Process status
            record_count: Records processed
            details: Additional details
            parent_process_id: Parent process ID
            source_system: Source system
            target_system: Target system
            
        Returns:
            AuditEntry
        """
        
        entry = self.log_action(
            action=AuditAction.EXECUTE,
            entity_type=AuditEntityType.PROCESS,
            entity_name=process_name,
            entity_id=f"{process_name}_{step_name}",
            status=AuditStatus.SUCCESS if status == "SUCCESS" else AuditStatus.FAILURE,
            record_count=record_count,
            change_summary=details or {},
            parent_process_id=parent_process_id,
            source_system=source_system,
            target_system=target_system
        )
        
        return entry
    
    def log_data_change(
        self,
        table_name: str,
        record_id: str,
        action: AuditAction,
        before: Optional[Dict] = None,
        after: Optional[Dict] = None,
        change_reason: Optional[str] = None
    ) -> AuditEntry:
        """
        Log data modification for change data capture.
        
        Args:
            table_name: Name of table
            record_id: ID of record changed
            action: Type of change
            before: Record values before change
            after: Record values after change
            change_reason: Reason for change
            
        Returns:
            AuditEntry
        """
        
        change_summary = {
            "table": table_name,
            "record_id": record_id,
            "reason": change_reason,
            "timestamp": datetime.now().isoformat()
        }
        
        entry = self.log_action(
            action=action,
            entity_type=AuditEntityType.RECORD,
            entity_name=table_name,
            entity_id=record_id,
            status=AuditStatus.SUCCESS,
            record_count=1,
            change_summary=change_summary,
            before_values=before,
            after_values=after
        )
        
        return entry
    
    def log_validation(
        self,
        validation_name: str,
        table_name: str,
        total_records: int,
        passed_records: int,
        failed_records: int,
        details: Optional[Dict] = None
    ) -> AuditEntry:
        """
        Log validation execution.
        
        Args:
            validation_name: Name of validation
            table_name: Table being validated
            total_records: Total records checked
            passed_records: Records that passed
            failed_records: Records that failed
            details: Validation details
            
        Returns:
            AuditEntry
        """
        
        status = AuditStatus.SUCCESS if failed_records == 0 else AuditStatus.PARTIAL
        
        change_summary = {
            "validation": validation_name,
            "table": table_name,
            "total_records": total_records,
            "passed_records": passed_records,
            "failed_records": failed_records,
            "pass_rate": (passed_records / total_records * 100) if total_records > 0 else 0,
            "details": details
        }
        
        entry = self.log_action(
            action=AuditAction.VALIDATE,
            entity_type=AuditEntityType.PROCESS,
            entity_name=f"validation_{validation_name}",
            entity_id=validation_name,
            status=status,
            record_count=total_records,
            change_summary=change_summary
        )
        
        return entry
    
    def log_reconciliation(
        self,
        reconciliation_name: str,
        data_type: str,
        source_count: int,
        target_count: int,
        variance_percent: float,
        status: str,
        details: Optional[Dict] = None
    ) -> AuditEntry:
        """
        Log reconciliation execution.
        
        Args:
            reconciliation_name: Name of reconciliation
            data_type: Type of data reconciled
            source_count: Source record count
            target_count: Target record count
            variance_percent: Variance percentage
            status: Reconciliation status
            details: Reconciliation details
            
        Returns:
            AuditEntry
        """
        
        change_summary = {
            "reconciliation": reconciliation_name,
            "data_type": data_type,
            "source_count": source_count,
            "target_count": target_count,
            "variance_percent": variance_percent,
            "status": status,
            "details": details
        }
        
        entry = self.log_action(
            action=AuditAction.RECONCILE,
            entity_type=AuditEntityType.PROCESS,
            entity_name=f"reconciliation_{reconciliation_name}",
            entity_id=reconciliation_name,
            status=AuditStatus.SUCCESS if status == "PASS" else AuditStatus.FAILURE,
            record_count=source_count,
            change_summary=change_summary
        )
        
        return entry
    
    def log_batch_operation(
        self,
        operation_name: str,
        table_name: str,
        total_records: int,
        successful_records: int,
        failed_records: int,
        error_details: Optional[List[str]] = None
    ) -> AuditEntry:
        """
        Log batch operation.
        
        Args:
            operation_name: Name of batch operation
            table_name: Target table
            total_records: Total records in batch
            successful_records: Records successfully processed
            failed_records: Records that failed
            error_details: List of errors
            
        Returns:
            AuditEntry
        """
        
        status = AuditStatus.SUCCESS if failed_records == 0 else AuditStatus.PARTIAL
        
        change_summary = {
            "operation": operation_name,
            "table": table_name,
            "total_records": total_records,
            "successful_records": successful_records,
            "failed_records": failed_records,
            "success_rate": (successful_records / total_records * 100) if total_records > 0 else 0,
            "error_details": error_details or []
        }
        
        entry = self.log_action(
            action=AuditAction.EXECUTE,
            entity_type=AuditEntityType.JOB,
            entity_name=operation_name,
            entity_id=f"{operation_name}_{datetime.now().timestamp()}",
            status=status,
            record_count=total_records,
            change_summary=change_summary,
            affected_rows=successful_records
        )
        
        return entry
    
    def _persist_audit_entry(self, entry: AuditEntry):
        """Persist audit entry to database."""
        try:
            etl_log = ETLLog(
                process_name=f"audit_{entry.entity_type.value}",
                process_step=entry.action.value,
                record_count=entry.record_count,
                status=entry.status.value,
                log_date=entry.timestamp.date(),
                details=entry.to_dict()
            )
            self.session.add(etl_log)
            self.session.commit()
        except Exception as e:
            logger.error(f"Error persisting audit entry: {e}")
            self.session.rollback()
    
    def _generate_audit_id(self, entity_name: str, entity_id: Optional[str]) -> str:
        """Generate unique audit ID."""
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S%f")
        entity_str = f"{entity_name}_{entity_id}" if entity_id else entity_name
        hash_input = f"{entity_str}_{timestamp}"
        hash_value = hashlib.sha256(hash_input.encode()).hexdigest()[:8]
        return f"AUD_{timestamp}_{hash_value}"
    
    def _identify_changed_fields(self, before: Dict, after: Dict) -> List[str]:
        """Identify which fields changed between before and after."""
        changed = []
        
        # Check for changed fields
        for key in set(list(before.keys()) + list(after.keys())):
            before_val = before.get(key)
            after_val = after.get(key)
            
            if before_val != after_val:
                changed.append(key)
        
        return changed
    
    def get_audit_trail(
        self,
        entity_name: Optional[str] = None,
        entity_id: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        action_filter: Optional[List[AuditAction]] = None,
        limit: int = 1000
    ) -> List[AuditEntry]:
        """
        Retrieve audit trail for compliance reporting.
        
        Args:
            entity_name: Filter by entity name
            entity_id: Filter by entity ID
            start_date: Filter by start date
            end_date: Filter by end date
            action_filter: Filter by actions
            limit: Maximum records to return
            
        Returns:
            List of audit entries
        """
        
        query = text("""
            SELECT details FROM etl_logs
            WHERE process_name LIKE 'audit_%'
        """)
        
        where_clauses = ["process_name LIKE 'audit_%'"]
        params = {}
        
        if entity_name:
            where_clauses.append("details->'$.entity_name' = :entity_name")
            params['entity_name'] = entity_name
        
        if entity_id:
            where_clauses.append("details->'$.entity_id' = :entity_id")
            params['entity_id'] = entity_id
        
        if start_date:
            where_clauses.append("log_date >= :start_date")
            params['start_date'] = start_date.date()
        
        if end_date:
            where_clauses.append("log_date <= :end_date")
            params['end_date'] = end_date.date()
        
        query_str = "SELECT details FROM etl_logs WHERE " + " AND ".join(where_clauses)
        query_str += f" ORDER BY log_date DESC LIMIT {limit}"
        
        try:
            results = self.session.execute(text(query_str), params).fetchall()
            
            entries = []
            for result in results:
                if result[0]:
                    entry_dict = json.loads(result[0]) if isinstance(result[0], str) else result[0]
                    # Convert back to AuditEntry (simplified)
                    entries.append(entry_dict)
            
            return entries
        except Exception as e:
            logger.error(f"Error retrieving audit trail: {e}")
            return []
    
    def generate_compliance_report(
        self,
        start_date: date,
        end_date: date,
        include_details: bool = False
    ) -> Dict:
        """
        Generate compliance audit report.
        
        Args:
            start_date: Report start date
            end_date: Report end date
            include_details: Include detailed entries
            
        Returns:
            Compliance report dictionary
        """
        
        try:
            # Aggregate audit data
            query = text("""
                SELECT 
                    JSON_EXTRACT(details, '$.action') as action,
                    JSON_EXTRACT(details, '$.entity_type') as entity_type,
                    COUNT(*) as count,
                    SUM(JSON_EXTRACT(details, '$.affected_rows')) as total_rows
                FROM etl_logs
                WHERE process_name LIKE 'audit_%'
                AND log_date BETWEEN :start_date AND :end_date
                GROUP BY action, entity_type
            """)
            
            results = self.session.execute(query, {
                'start_date': start_date,
                'end_date': end_date
            }).fetchall()
            
            report = {
                "report_type": "Compliance Audit Report",
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "generated_at": datetime.now().isoformat(),
                "generated_by": self.context.user_id,
                "summary": {
                    "total_audit_entries": sum(r[2] for r in results),
                    "total_records_affected": sum(r[3] or 0 for r in results),
                    "actions": {}
                }
            }
            
            # Build action summary
            for action, entity_type, count, total_rows in results:
                if action not in report["summary"]["actions"]:
                    report["summary"]["actions"][action] = {
                        "count": 0,
                        "total_rows": 0,
                        "entity_types": {}
                    }
                
                report["summary"]["actions"][action]["count"] += count
                report["summary"]["actions"][action]["total_rows"] += (total_rows or 0)
                
                if entity_type not in report["summary"]["actions"][action]["entity_types"]:
                    report["summary"]["actions"][action]["entity_types"][entity_type] = 0
                
                report["summary"]["actions"][action]["entity_types"][entity_type] += count
            
            return report
        except Exception as e:
            logger.error(f"Error generating compliance report: {e}")
            return {"error": str(e)}


if __name__ == "__main__":
    # Example usage
    with AuditLogger() as audit:
        # Log an ETL process
        audit.log_etl_process(
            process_name="Orders_Load",
            step_name="Staging_Transform",
            status="SUCCESS",
            record_count=5000,
            source_system="ERP",
            target_system="Staging"
        )
        
        # Log a data change
        audit.log_data_change(
            table_name="orders",
            record_id="ORD-12345",
            action=AuditAction.UPDATE,
            before={"status": "pending", "amount": 1000},
            after={"status": "completed", "amount": 1000},
            change_reason="Order completed"
        )
        
        # Log validation
        audit.log_validation(
            validation_name="Null_Check",
            table_name="staging_orders",
            total_records=5000,
            passed_records=4950,
            failed_records=50
        )
        
        # Log reconciliation
        audit.log_reconciliation(
            reconciliation_name="ERP_Orders",
            data_type="Orders",
            source_count=5000,
            target_count=4995,
            variance_percent=0.1,
            status="PASS"
        )
