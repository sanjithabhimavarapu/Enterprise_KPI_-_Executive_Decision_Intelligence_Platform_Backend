"""
Data Validation Scripts
=======================
Comprehensive data quality validation for staging tables and fact tables.
Includes completeness, accuracy, consistency, business logic checks,
duplicate detection, null validation, and audit logging.
"""

import logging
from datetime import date, datetime, timedelta
from typing import List, Dict, Optional, Tuple, Any, Set
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict

from sqlalchemy import func, text
from sqlalchemy.orm import Session

from database import get_db_session
from models import (
    StagingOrdersConformed, StagingCustomersConformed,
    StagingOpportunitiesConformed, StagingInventoryConformed,
    StagingCustomerInteractionsConformed, FactSales, FactRevenue,
    DataQualityScore, ETLLog
)

logger = logging.getLogger(__name__)


class ValidationStatus(str, Enum):
    """Validation result status."""
    PASS = "PASS"
    WARNING = "WARNING"
    FAIL = "FAIL"


@dataclass
class ValidationAudit:
    """Audit log for validation activities."""
    check_id: str
    check_name: str
    table_name: str
    status: ValidationStatus
    executed_at: datetime
    total_records_checked: int
    records_failed: int
    records_passed: int
    failure_details: str
    user_id: str = "system"
    execution_duration_seconds: float = 0.0
    error_message: Optional[str] = None
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for logging."""
        return {
            "check_id": self.check_id,
            "check_name": self.check_name,
            "table_name": self.table_name,
            "status": self.status.value,
            "executed_at": self.executed_at.isoformat(),
            "total_records_checked": self.total_records_checked,
            "records_failed": self.records_failed,
            "records_passed": self.records_passed,
            "failure_details": self.failure_details,
            "user_id": self.user_id,
            "execution_duration_seconds": self.execution_duration_seconds,
            "error_message": self.error_message
        }


@dataclass
class ValidationResult:
    """Result of a validation check."""
    check_name: str
    table_name: str
    status: ValidationStatus
    total_records: int
    valid_records: int
    invalid_records: int
    validation_percent: float
    details: str
    failed_records: List[Any] = None
    audit_log: Optional[ValidationAudit] = None
    duplicate_ids: List[Any] = field(default_factory=list)
    null_field_counts: Dict[str, int] = field(default_factory=dict)
    
    def __post_init__(self):
        if self.failed_records is None:
            self.failed_records = []

    def __repr__(self) -> str:
        return f"ValidationResult({self.check_name}: {self.status} - {self.validation_percent:.1f}%)"


class BaseValidator:
    """Base class for data validators."""
    
    def __init__(self, load_date: Optional[date] = None):
        self.load_date = load_date or date.today()
        self.session = get_db_session()
        self.results: List[ValidationResult] = []
        self.audit_logs: List[ValidationAudit] = []
        self.check_counter = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            self.session.close()

    def add_result(self, result: ValidationResult):
        """Add validation result with audit logging."""
        self.results.append(result)
        log_level = logging.WARNING if result.status == ValidationStatus.FAIL else logging.INFO
        logger.log(log_level, str(result))
        
        # Create audit log entry
        if result.audit_log:
            self.audit_logs.append(result.audit_log)
            self._log_audit_entry(result.audit_log)

    def _log_audit_entry(self, audit: ValidationAudit):
        """Log validation audit entry to ETL logs."""
        try:
            etl_log = ETLLog(
                process_name="data_validator",
                process_step=f"{audit.check_name}",
                record_count=audit.total_records_checked,
                status=audit.status,
                log_date=self.load_date,
                details=audit.to_dict()
            )
            self.session.add(etl_log)
            self.session.commit()
            logger.info(f"Audit logged: {audit.check_name} - {audit.status}")
        except Exception as e:
            logger.error(f"Failed to log audit: {e}")
            self.session.rollback()

    def create_audit_log(
        self,
        check_name: str,
        table_name: str,
        status: ValidationStatus,
        total_records: int,
        failed_records: int,
        details: str,
        duration: float = 0.0
    ) -> ValidationAudit:
        """Create validation audit log."""
        self.check_counter += 1
        audit = ValidationAudit(
            check_id=f"CHK_{self.load_date}_{self.check_counter:04d}",
            check_name=check_name,
            table_name=table_name,
            status=status,
            executed_at=datetime.now(),
            total_records_checked=total_records,
            records_failed=failed_records,
            records_passed=total_records - failed_records,
            failure_details=details,
            execution_duration_seconds=duration
        )
        return audit

    def get_summary(self) -> Dict[str, Any]:
        """Get validation summary."""
        total_results = len(self.results)
        passed = sum(1 for r in self.results if r.status == ValidationStatus.PASS)
        warned = sum(1 for r in self.results if r.status == ValidationStatus.WARNING)
        failed = sum(1 for r in self.results if r.status == ValidationStatus.FAIL)
        
        avg_validity = sum(r.validation_percent for r in self.results) / total_results if total_results > 0 else 0
        
        return {
            "total_checks": total_results,
            "passed": passed,
            "warned": warned,
            "failed": failed,
            "average_validity_percent": avg_validity,
            "overall_status": ValidationStatus.FAIL if failed > 0 else (ValidationStatus.WARNING if warned > 0 else ValidationStatus.PASS),
            "audit_logs_count": len(self.audit_logs)
        }


class StagingValidator(BaseValidator):
    """Validate staging table data quality."""
    
    def validate_orders(self) -> None:
        """Validate orders staging table."""
        query = self.session.query(StagingOrdersConformed).filter(
            StagingOrdersConformed.source_load_date == self.load_date
        )
        
        total = query.count()
        if total == 0:
            self.add_result(ValidationResult(
                check_name="Orders Completeness",
                table_name="stg_orders_conformed",
                status=ValidationStatus.FAIL,
                total_records=0,
                valid_records=0,
                invalid_records=0,
                validation_percent=0,
                details="No records found for load date"
            ))
            return
        
        # Check required fields
        valid = query.filter(
            StagingOrdersConformed.order_id.isnot(None),
            StagingOrdersConformed.customer_business_key.isnot(None),
            StagingOrdersConformed.product_sku.isnot(None),
            StagingOrdersConformed.order_date.isnot(None),
            StagingOrdersConformed.order_quantity > 0,
            StagingOrdersConformed.net_amount > 0
        ).count()
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Orders Completeness",
            table_name="stg_orders_conformed",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} orders have required fields"
        ))
    
    def validate_customers(self) -> None:
        """Validate customers staging table."""
        query = self.session.query(StagingCustomersConformed).filter(
            StagingCustomersConformed.source_load_date == self.load_date
        )
        
        total = query.count()
        
        # Check completeness
        valid = query.filter(
            StagingCustomersConformed.customer_id.isnot(None),
            StagingCustomersConformed.customer_name.isnot(None)
        ).count()
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Customers Completeness",
            table_name="stg_customers_conformed",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} customers have required fields"
        ))
        
        # Check for duplicates
        duplicates = self.session.query(
            StagingCustomersConformed.customer_id,
            func.count().label('cnt')
        ).filter(
            StagingCustomersConformed.source_load_date == self.load_date
        ).group_by(
            StagingCustomersConformed.customer_id
        ).having(
            func.count() > 1
        ).count()
        
        dup_status = ValidationStatus.PASS if duplicates == 0 else ValidationStatus.WARNING
        
        self.add_result(ValidationResult(
            check_name="Customers Duplicates",
            table_name="stg_customers_conformed",
            status=dup_status,
            total_records=total,
            valid_records=total - duplicates,
            invalid_records=duplicates,
            validation_percent=((total - duplicates) / total * 100) if total > 0 else 0,
            details=f"{duplicates} duplicate customer IDs found"
        ))
    
    def validate_opportunities(self) -> None:
        """Validate opportunities staging table."""
        query = self.session.query(StagingOpportunitiesConformed).filter(
            StagingOpportunitiesConformed.source_load_date == self.load_date
        )
        
        total = query.count()
        
        # Check required fields
        valid = query.filter(
            StagingOpportunitiesConformed.opportunity_id.isnot(None),
            StagingOpportunitiesConformed.customer_id.isnot(None),
            StagingOpportunitiesConformed.opportunity_amount.isnot(None)
        ).count()
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Opportunities Completeness",
            table_name="stg_opportunities_conformed",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} opportunities have required fields"
        ))
    
    def validate_inventory(self) -> None:
        """Validate inventory staging table."""
        query = self.session.query(StagingInventoryConformed).filter(
            StagingInventoryConformed.source_load_date == self.load_date
        )
        
        total = query.count()
        
        # Check data consistency
        valid = query.filter(
            StagingInventoryConformed.closing_quantity >= 0,
            StagingInventoryConformed.inventory_value >= 0
        ).count()
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Inventory Consistency",
            table_name="stg_inventory_conformed",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} inventory records have valid values"
        ))


class FactValidator(BaseValidator):
    """Validate fact table data quality."""
    
    def validate_fact_sales_completeness(self) -> None:
        """Validate fact_sales table completeness."""
        query = self.session.query(FactSales).filter(
            FactSales.load_date == self.load_date
        )
        
        total = query.count()
        
        # Check for required dimensions
        valid = query.filter(
            FactSales.customer_key != -1,
            FactSales.product_key != -1
        ).count()
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 98 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Fact Sales Dimension Keys",
            table_name="fact_sales",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} sales have valid dimension keys"
        ))
    
    def validate_fact_sales_amounts(self) -> None:
        """Validate fact_sales amount calculations."""
        query = self.session.query(FactSales).filter(
            FactSales.load_date == self.load_date
        )
        
        total = query.count()
        
        # Check amount integrity: net_amount = gross - discount
        records = query.all()
        valid = 0
        
        for record in records:
            expected_net = (record.gross_amount or 0) - (record.discount_amount or 0)
            actual_net = record.net_amount or 0
            
            if abs(expected_net - actual_net) < 0.01:  # Allow for rounding
                valid += 1
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Fact Sales Amount Integrity",
            table_name="fact_sales",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} sales have correct amount calculations"
        ))
    
    def validate_fact_revenue_aggregates(self) -> None:
        """Validate fact_revenue aggregations."""
        query = self.session.query(FactRevenue).filter(
            FactRevenue.load_date == self.load_date
        )
        
        total = query.count()
        
        # Verify total revenue matches sum of fact_sales
        fact_sales_total = self.session.query(
            func.sum(FactSales.net_amount)
        ).filter(
            FactSales.load_date == self.load_date
        ).scalar() or 0
        
        revenue_total = self.session.query(
            func.sum(FactRevenue.total_net_revenue)
        ).filter(
            FactRevenue.load_date == self.load_date
        ).scalar() or 0
        
        variance_percent = abs(fact_sales_total - revenue_total) / abs(fact_sales_total) * 100 if fact_sales_total > 0 else 0
        
        status = ValidationStatus.PASS if variance_percent < 0.01 else (ValidationStatus.WARNING if variance_percent < 1 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Fact Revenue Aggregation",
            table_name="fact_revenue",
            status=status,
            total_records=total,
            valid_records=total if variance_percent < 1 else 0,
            invalid_records=0 if variance_percent < 1 else total,
            validation_percent=100 - variance_percent,
            details=f"Variance: {variance_percent:.2f}% | Sales: ${fact_sales_total:,.2f} | Revenue: ${revenue_total:,.2f}"
        ))


class BusinessLogicValidator(BaseValidator):
    """Validate business logic rules."""
    
    def validate_order_delivery_logic(self) -> None:
        """Validate order delivery business logic."""
        query = self.session.query(StagingOrdersConformed).filter(
            StagingOrdersConformed.source_load_date == self.load_date,
            StagingOrdersConformed.actual_delivery_date.isnot(None)
        )
        
        total = query.count()
        
        # Check: delivery_days = actual_delivery_date - requested_delivery_date
        records = query.all()
        valid = 0
        
        for record in records:
            if record.requested_delivery_date and record.actual_delivery_date:
                expected_days = (record.actual_delivery_date - record.requested_delivery_date).days
                actual_days = record.delivery_days or 0
                
                if expected_days == actual_days:
                    valid += 1
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Order Delivery Calculation",
            table_name="stg_orders_conformed",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} orders have correct delivery day calculations"
        ))
    
    def validate_margin_calculations(self) -> None:
        """Validate margin percentage calculations."""
        query = self.session.query(StagingOrdersConformed).filter(
            StagingOrdersConformed.source_load_date == self.load_date,
            StagingOrdersConformed.net_amount > 0
        )
        
        total = query.count()
        
        # Check: gross_margin_percent = (gross_profit / net_amount) * 100
        records = query.all()
        valid = 0
        
        for record in records:
            if record.net_amount and record.gross_profit is not None:
                expected_margin = (record.gross_profit / record.net_amount * 100)
                actual_margin = record.gross_margin_percent or 0
                
                if abs(expected_margin - actual_margin) < 0.1:  # Allow 0.1% tolerance
                    valid += 1
        
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        self.add_result(ValidationResult(
            check_name="Margin Calculation",
            table_name="stg_orders_conformed",
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} orders have correct margin calculations"
        ))


class NullValidator(BaseValidator):
    """Validate null fields in staging and fact tables."""
    
    REQUIRED_FIELDS = {
        'stg_orders_conformed': [
            'order_id', 'customer_business_key', 'product_sku',
            'order_date', 'order_quantity', 'net_amount'
        ],
        'stg_customers_conformed': [
            'customer_id', 'customer_name', 'customer_type'
        ],
        'stg_opportunities_conformed': [
            'opportunity_id', 'customer_id', 'opportunity_amount'
        ],
        'stg_inventory_conformed': [
            'warehouse_id', 'product_sku', 'closing_quantity'
        ],
        'fact_sales': [
            'customer_key', 'product_key', 'order_date', 'net_amount'
        ]
    }
    
    def validate_null_fields(self, table_name: str, model_class: Any) -> None:
        """Validate null fields in specified table."""
        start_time = datetime.now()
        
        query = self.session.query(model_class)
        if hasattr(model_class, 'source_load_date'):
            query = query.filter(model_class.source_load_date == self.load_date)
        elif hasattr(model_class, 'load_date'):
            query = query.filter(model_class.load_date == self.load_date)
        
        total = query.count()
        if total == 0:
            return
        
        required_fields = self.REQUIRED_FIELDS.get(table_name, [])
        null_field_counts = defaultdict(int)
        
        for field_name in required_fields:
            if hasattr(model_class, field_name):
                field = getattr(model_class, field_name)
                null_count = query.filter(field.is_(None)).count()
                if null_count > 0:
                    null_field_counts[field_name] = null_count
        
        # Calculate valid records (no nulls in required fields)
        valid = total - len([count for count in null_field_counts.values() if count > 0])
        invalid = total - valid
        percent = (valid / total * 100) if total > 0 else 0
        
        status = ValidationStatus.PASS if percent >= 99 else (ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL)
        
        duration = (datetime.now() - start_time).total_seconds()
        audit_log = self.create_audit_log(
            check_name=f"Null Validation - {table_name}",
            table_name=table_name,
            status=status,
            total_records=total,
            failed_records=invalid,
            details=f"Null fields found: {dict(null_field_counts)}",
            duration=duration
        )
        
        result = ValidationResult(
            check_name=f"Null Field Validation",
            table_name=table_name,
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=invalid,
            validation_percent=percent,
            details=f"{valid}/{total} records have no null required fields. Nulls: {dict(null_field_counts)}",
            audit_log=audit_log,
            null_field_counts=dict(null_field_counts)
        )
        self.add_result(result)
    
    def validate_all_tables(self) -> None:
        """Validate null fields across all staging tables."""
        logger.info("Starting null field validation")
        
        # Validate staging tables
        self.validate_null_fields('stg_orders_conformed', StagingOrdersConformed)
        self.validate_null_fields('stg_customers_conformed', StagingCustomersConformed)
        self.validate_null_fields('stg_opportunities_conformed', StagingOpportunitiesConformed)
        self.validate_null_fields('stg_inventory_conformed', StagingInventoryConformed)
        
        # Validate fact tables
        self.validate_null_fields('fact_sales', FactSales)
        
        logger.info(f"Null validation complete: {len(self.results)} checks")


class DuplicateValidator(BaseValidator):
    """Validate for duplicate records using business keys."""
    
    # Business keys for duplicate detection
    BUSINESS_KEYS = {
        'stg_orders_conformed': ['order_id', 'order_date'],
        'stg_customers_conformed': ['customer_id'],
        'stg_opportunities_conformed': ['opportunity_id'],
        'stg_inventory_conformed': ['warehouse_id', 'product_sku'],
    }
    
    def validate_duplicates_by_keys(
        self,
        table_name: str,
        model_class: Any,
        key_fields: List[str]
    ) -> None:
        """Validate for duplicate records based on business keys."""
        start_time = datetime.now()
        
        query = self.session.query(model_class)
        if hasattr(model_class, 'source_load_date'):
            query = query.filter(model_class.source_load_date == self.load_date)
        elif hasattr(model_class, 'load_date'):
            query = query.filter(model_class.load_date == self.load_date)
        
        total = query.count()
        if total == 0:
            return
        
        # Get all records
        records = query.all()
        seen_keys: Dict[Tuple, List[Any]] = defaultdict(list)
        duplicate_ids = []
        
        for record in records:
            # Create composite key tuple
            key_values = tuple(getattr(record, key, None) for key in key_fields)
            seen_keys[key_values].append(record)
        
        # Find duplicates
        duplicate_count = 0
        for key_values, key_records in seen_keys.items():
            if len(key_records) > 1:
                duplicate_count += len(key_records) - 1  # All but first
                for rec in key_records[1:]:
                    duplicate_ids.append(getattr(rec, 'id', str(key_values)))
        
        valid = total - duplicate_count
        percent = (valid / total * 100) if total > 0 else 0
        
        status = ValidationStatus.PASS if duplicate_count == 0 else (
            ValidationStatus.WARNING if percent >= 95 else ValidationStatus.FAIL
        )
        
        duration = (datetime.now() - start_time).total_seconds()
        audit_log = self.create_audit_log(
            check_name=f"Duplicate Check - {table_name}",
            table_name=table_name,
            status=status,
            total_records=total,
            failed_records=duplicate_count,
            details=f"Duplicates found on keys: {key_fields}",
            duration=duration
        )
        
        result = ValidationResult(
            check_name=f"Duplicate Records",
            table_name=table_name,
            status=status,
            total_records=total,
            valid_records=valid,
            invalid_records=duplicate_count,
            validation_percent=percent,
            details=f"{duplicate_count} duplicate records found on keys {key_fields}",
            audit_log=audit_log,
            duplicate_ids=duplicate_ids
        )
        self.add_result(result)
    
    def validate_all_tables(self) -> None:
        """Validate duplicates across all staging tables."""
        logger.info("Starting duplicate validation")
        
        for table_name, key_fields in self.BUSINESS_KEYS.items():
            model_mapping = {
                'stg_orders_conformed': StagingOrdersConformed,
                'stg_customers_conformed': StagingCustomersConformed,
                'stg_opportunities_conformed': StagingOpportunitiesConformed,
                'stg_inventory_conformed': StagingInventoryConformed,
            }
            
            model_class = model_mapping.get(table_name)
            if model_class:
                self.validate_duplicates_by_keys(table_name, model_class, key_fields)
        
        logger.info(f"Duplicate validation complete: {len(self.results)} checks")


class MasterValidator:
    """Orchestrate all validation tasks."""
    
    def __init__(self, load_date: Optional[date] = None):
        self.load_date = load_date or date.today()
        self.logger = logging.getLogger(__name__)

    def validate_all(self) -> ValidationResult:
        """Execute all validation tasks."""
        self.logger.info(f"Starting master validation for {self.load_date}")
        
        all_results = []
        
        # Staging validations
        with StagingValidator(self.load_date) as validator:
            validator.validate_orders()
            validator.validate_customers()
            validator.validate_opportunities()
            validator.validate_inventory()
            all_results.extend(validator.results)
        
        # Fact validations
        with FactValidator(self.load_date) as validator:
            validator.validate_fact_sales_completeness()
            validator.validate_fact_sales_amounts()
            validator.validate_fact_revenue_aggregates()
            all_results.extend(validator.results)
        
        # Business logic validations
        with BusinessLogicValidator(self.load_date) as validator:
            validator.validate_order_delivery_logic()
            validator.validate_margin_calculations()
            all_results.extend(validator.results)
        
        # Null field validations
        with NullValidator(self.load_date) as validator:
            validator.validate_all_tables()
            all_results.extend(validator.results)
        
        # Duplicate record validations
        with DuplicateValidator(self.load_date) as validator:
            validator.validate_all_tables()
            all_results.extend(validator.results)
        
        # Calculate DQ score
        total_checks = len(all_results)
        passed_checks = sum(1 for r in all_results if r.status == ValidationStatus.PASS)
        avg_validity = sum(r.validation_percent for r in all_results) / total_checks if total_checks > 0 else 0
        
        # Determine grade
        if avg_validity >= 95:
            grade = "Excellent"
        elif avg_validity >= 85:
            grade = "Good"
        elif avg_validity >= 75:
            grade = "Fair"
        else:
            grade = "Poor"
        
        # Log DQ score and validation summary
        session = get_db_session()
        try:
            dq_score = DataQualityScore(
                load_date=self.load_date,
                completeness_score=avg_validity,
                accuracy_score=avg_validity,
                consistency_score=avg_validity,
                timeliness_score=100,
                validity_score=avg_validity,
                overall_dq_score=avg_validity,
                dq_status=grade
            )
            session.add(dq_score)
            session.commit()
            
            self.logger.info(f"DQ Score: {avg_validity:.2f}% ({grade})")
            
            # Log detailed validation summary
            self.logger.info(f"Validation Results:")
            self.logger.info(f"  Total Checks: {total_checks}")
            self.logger.info(f"  Passed: {passed_checks}")
            self.logger.info(f"  Failed: {sum(1 for r in all_results if r.status == ValidationStatus.FAIL)}")
            self.logger.info(f"  Warnings: {sum(1 for r in all_results if r.status == ValidationStatus.WARNING)}")
            
            # Log checks by category
            staging_checks = sum(1 for r in all_results if 'stg_' in r.table_name)
            fact_checks = sum(1 for r in all_results if 'fact_' in r.table_name)
            null_checks = sum(1 for r in all_results if 'Null' in r.check_name)
            dup_checks = sum(1 for r in all_results if 'Duplicate' in r.check_name)
            
            self.logger.info(f"Validation Breakdown:")
            self.logger.info(f"  Staging Checks: {staging_checks}")
            self.logger.info(f"  Fact Checks: {fact_checks}")
            self.logger.info(f"  Null Validations: {null_checks}")
            self.logger.info(f"  Duplicate Checks: {dup_checks}")
            
        finally:
            session.close()
        
        return ValidationResult(
            check_name="Master Validation",
            table_name="All Tables",
            status=ValidationStatus.FAIL if passed_checks < total_checks else ValidationStatus.PASS,
            total_records=total_checks,
            valid_records=passed_checks,
            invalid_records=total_checks - passed_checks,
            validation_percent=avg_validity,
            details=f"{passed_checks}/{total_checks} checks passed | Grade: {grade} | "
                   f"Staging: {staging_checks} | Fact: {fact_checks} | "
                   f"Null: {null_checks} | Duplicate: {dup_checks}"
        )


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    validator = MasterValidator()
    result = validator.validate_all()
    print(f"Validation Summary: {result}")
