"""
Data Validation Scripts
=======================
Comprehensive data quality validation for staging tables and fact tables.
Includes completeness, accuracy, consistency, and business logic checks.
"""

import logging
from datetime import date, datetime, timedelta
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum

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

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            self.session.close()

    def add_result(self, result: ValidationResult):
        """Add validation result."""
        self.results.append(result)
        log_level = logging.WARNING if result.status == ValidationStatus.FAIL else logging.INFO
        logger.log(log_level, str(result))

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
            "overall_status": ValidationStatus.FAIL if failed > 0 else (ValidationStatus.WARNING if warned > 0 else ValidationStatus.PASS)
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
        
        # Log DQ score
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
            details=f"{passed_checks}/{total_checks} checks passed | Grade: {grade}"
        )


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    validator = MasterValidator()
    result = validator.validate_all()
    print(f"Validation Summary: {result}")
