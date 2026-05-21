# Quick Reference - Enhanced Validation Features

## 1. Duplicate Checks - Quick Start

### Basic Usage
```python
from validation import DuplicateValidator
from datetime import date

# Validate all tables for duplicates
with DuplicateValidator(load_date=date.today()) as validator:
    validator.validate_all_tables()
    
    for result in validator.results:
        print(f"{result.table_name}: {result.status}")
        if result.duplicate_ids:
            print(f"  Duplicate IDs: {result.duplicate_ids}")
```

### Check Single Table
```python
from models import StagingOrdersConformed

with DuplicateValidator() as validator:
    validator.validate_duplicates_by_keys(
        table_name='stg_orders_conformed',
        model_class=StagingOrdersConformed,
        key_fields=['order_id', 'order_date']
    )
    
    result = validator.results[0]
    print(f"Valid records: {result.valid_records}/{result.total_records}")
    print(f"Duplicates: {result.invalid_records}")
```

### Access Duplicate Details
```python
result = validator.results[0]

# Get duplicate record identifiers
duplicate_ids = result.duplicate_ids
print(f"Records with duplicate keys: {duplicate_ids}")

# Get duplicate count
dup_count = result.invalid_records
print(f"Total duplicates: {dup_count}")

# Get uniqueness percentage
uniqueness = result.validation_percent
print(f"Uniqueness: {uniqueness:.2f}%")
```

---

## 2. Null Validations - Quick Start

### Basic Usage
```python
from validation import NullValidator
from datetime import date

# Validate all tables for nulls
with NullValidator(load_date=date.today()) as validator:
    validator.validate_all_tables()
    
    for result in validator.results:
        print(f"{result.table_name}: {result.status}")
        print(f"  Completeness: {result.validation_percent:.1f}%")
```

### Check Single Table
```python
from models import StagingOrdersConformed

with NullValidator() as validator:
    validator.validate_null_fields(
        table_name='stg_orders_conformed',
        model_class=StagingOrdersConformed
    )
    
    result = validator.results[0]
    print(f"Valid records: {result.valid_records}/{result.total_records}")
```

### Access Null Field Details
```python
result = validator.results[0]

# Get field-level null counts
null_counts = result.null_field_counts
# Output: {'order_id': 0, 'customer_id': 5, 'amount': 10}

for field, count in null_counts.items():
    if count > 0:
        print(f"{field}: {count} nulls")

# Get total records with any nulls
invalid_count = result.invalid_records
print(f"Records with nulls: {invalid_count}")

# Get completeness percentage
completeness = result.validation_percent
print(f"Completeness: {completeness:.1f}%")
```

---

## 3. Audit Logging - Quick Start

### Access Validation Audit Logs
```python
from validation import NullValidator, DuplicateValidator
from datetime import date

# Run validation
validator = NullValidator(load_date=date.today())
validator.validate_all_tables()

# Access audit logs
for audit in validator.audit_logs:
    print(f"Check ID: {audit.check_id}")
    print(f"Check: {audit.check_name}")
    print(f"Status: {audit.status}")
    print(f"Records Failed: {audit.records_failed}")
    print(f"Duration: {audit.execution_duration_seconds:.2f}s")
    print()
```

### Convert Audit to Dictionary
```python
audit = validator.audit_logs[0]

# Convert to dictionary for logging/storage
audit_dict = audit.to_dict()
print(audit_dict)

# Output:
# {
#   'check_id': 'CHK_2024-01-15_0001',
#   'check_name': 'Null Field Validation - stg_orders_conformed',
#   'table_name': 'stg_orders_conformed',
#   'status': 'PASS',
#   'executed_at': '2024-01-15T14:30:45.123456',
#   'total_records_checked': 500000,
#   'records_failed': 0,
#   'records_passed': 500000,
#   ...
# }
```

### Query Database Audit Logs
```python
from models import ETLLog
from database import get_db_session
from datetime import date

session = get_db_session()

# Get all validation audits for a date
audits = session.query(ETLLog).filter(
    ETLLog.process_name == "data_validator",
    ETLLog.log_date == date(2024, 1, 15)
).all()

for log in audits:
    details = log.details  # Auto-parsed from JSON
    
    print(f"{details['check_name']}: {details['status']}")
    print(f"  Check ID: {details['check_id']}")
    print(f"  Duration: {details['execution_duration_seconds']:.2f}s")
    print(f"  Records Failed: {details['records_failed']}")
    print()
```

### Create Custom Audit Log
```python
from validation import DuplicateValidator, ValidationStatus
from datetime import datetime

validator = DuplicateValidator()

# Create audit manually
custom_audit = validator.create_audit_log(
    check_name="Custom Duplicate Check",
    table_name="stg_custom_table",
    status=ValidationStatus.PASS,
    total_records=1000,
    failed_records=0,
    details="All custom checks passed",
    duration=1.5
)

print(f"Audit ID: {custom_audit.check_id}")
```

---

## 4. Enhanced Results - Quick Start

### Access All Result Fields
```python
result = validator.results[0]

# Basic fields
print(f"Check: {result.check_name}")
print(f"Table: {result.table_name}")
print(f"Status: {result.status}")

# Record counts
print(f"Total: {result.total_records}")
print(f"Valid: {result.valid_records}")
print(f"Invalid: {result.invalid_records}")

# Percentages
print(f"Validity: {result.validation_percent:.1f}%")

# Details
print(f"Details: {result.details}")

# NEW: Audit log
if result.audit_log:
    print(f"Audit ID: {result.audit_log.check_id}")
    print(f"Duration: {result.audit_log.execution_duration_seconds:.2f}s")

# NEW: Duplicate IDs
if result.duplicate_ids:
    print(f"Duplicate IDs: {result.duplicate_ids[:10]}")

# NEW: Null field counts
if result.null_field_counts:
    print(f"Null Fields: {result.null_field_counts}")
```

---

## 5. Master Validator with All Features

### Complete Validation Pipeline
```python
from validation import MasterValidator
from datetime import date

# Run complete validation
validator = MasterValidator(load_date=date(2024, 1, 15))
result = validator.validate_all()

print(f"DQ Score: {result.validation_percent:.1f}%")
print(f"Overall Status: {result.status}")
print(f"\n{result.details}")
```

### Parse Results by Type
```python
# Parse results by category
staging_results = [r for r in validator.results if 'stg_' in r.table_name]
fact_results = [r for r in validator.results if 'fact_' in r.table_name]
null_results = [r for r in validator.results if 'Null' in r.check_name]
dup_results = [r for r in validator.results if 'Duplicate' in r.check_name]

print(f"Staging Checks: {len(staging_results)}")
print(f"Fact Checks: {len(fact_results)}")
print(f"Null Validations: {len(null_results)}")
print(f"Duplicate Checks: {len(dup_results)}")

# Analyze by status
passed = sum(1 for r in validator.results if r.status == 'PASS')
failed = sum(1 for r in validator.results if r.status == 'FAIL')
warned = sum(1 for r in validator.results if r.status == 'WARNING')

print(f"\nResults: {passed} passed | {warned} warned | {failed} failed")
```

---

## 6. Error Handling

### Handle Validation Failures
```python
from validation import MasterValidator, ValidationStatus

validator = MasterValidator()
result = validator.validate_all()

if result.status == ValidationStatus.FAIL:
    print(f"Validation failed: {result.details}")
    
    # Find failed checks
    failed_checks = [r for r in validator.results if r.status == ValidationStatus.FAIL]
    
    for check in failed_checks:
        print(f"\nFailed Check: {check.check_name}")
        print(f"  Table: {check.table_name}")
        print(f"  Invalid Records: {check.invalid_records}")
        print(f"  Details: {check.details}")
        
        # Handle specific failures
        if 'Duplicate' in check.check_name:
            print(f"  Duplicate IDs: {check.duplicate_ids[:5]}")
        elif 'Null' in check.check_name:
            print(f"  Null Fields: {check.null_field_counts}")
```

### Handle Audit Logging Errors
```python
try:
    validator = NullValidator()
    validator.validate_all_tables()
    
    # Audit logs automatically created
    print(f"Audit entries created: {len(validator.audit_logs)}")
    
except Exception as e:
    print(f"Validation error: {e}")
    
    # Check for partial audit logs
    if validator.audit_logs:
        print(f"Partial audit logs: {len(validator.audit_logs)}")
        
        # Log which checks failed
        for audit in validator.audit_logs:
            if audit.error_message:
                print(f"  {audit.check_name}: {audit.error_message}")
```

---

## 7. Configuration Changes

### Add Custom Business Keys
```python
from validation import DuplicateValidator

# Extend business keys
DuplicateValidator.BUSINESS_KEYS['custom_table'] = ['custom_id', 'date']

# Now validate custom tables
with DuplicateValidator() as validator:
    validator.validate_duplicates_by_keys(
        table_name='custom_table',
        model_class=CustomTableModel,
        key_fields=['custom_id', 'date']
    )
```

### Add Custom Required Fields
```python
from validation import NullValidator

# Extend required fields
NullValidator.REQUIRED_FIELDS['custom_table'] = [
    'custom_id',
    'custom_name',
    'custom_value'
]

# Now validate custom tables
with NullValidator() as validator:
    validator.validate_null_fields('custom_table', CustomTableModel)
```

### Change Variance Tolerance
```python
from reconciliation import MasterReconciler

# Use tighter tolerance
reconciler = MasterReconciler(variance_tolerance=0.001)  # 0.001% instead of 0.01%

results = reconciler.reconcile_all()
```

---

## 8. Integration Examples

### In ETL Pipeline
```python
from validation import MasterValidator
from reconciliation import MasterReconciler
from datetime import date

load_date = date(2024, 1, 15)

# Stage 3: Validation
print("Running validation...")
validator = MasterValidator(load_date)
dq_result = validator.validate_all()

if dq_result.status == 'FAIL':
    print(f"⚠ Data quality check failed!")
    print(f"Details: {dq_result.details}")
    # Can halt or continue
else:
    print(f"✓ Data quality passed: {dq_result.validation_percent:.1f}%")
    
    # Stage 4: Reconciliation
    print("\nRunning reconciliation...")
    reconciler = MasterReconciler(load_date)
    recon_result = reconciler.reconcile_all()
    
    if recon_result['overall_status'] == 'PASS':
        print(f"✓ Reconciliation passed")
    else:
        print(f"⚠ Reconciliation issues detected")
```

### In Monitoring Dashboard
```python
from models import ETLLog, DataQualityScore
from database import get_db_session
from datetime import date, timedelta

session = get_db_session()

# Get last 7 days of validation audits
audits = session.query(ETLLog).filter(
    ETLLog.process_name == "data_validator",
    ETLLog.log_date >= date.today() - timedelta(days=7)
).all()

# Analyze trends
by_status = {}
for audit in audits:
    status = audit.status
    by_status[status] = by_status.get(status, 0) + 1

print("Last 7 days validation results:")
for status, count in by_status.items():
    print(f"  {status}: {count} checks")

# Get DQ score trends
dq_scores = session.query(DataQualityScore).filter(
    DataQualityScore.load_date >= date.today() - timedelta(days=7)
).order_by(DataQualityScore.load_date).all()

print("\nDQ Score trends:")
for score in dq_scores:
    print(f"  {score.load_date}: {score.overall_dq_score:.1f}% ({score.dq_status})")
```

---

## 9. Useful Queries

### Find Records with Nulls
```python
from models import StagingOrdersConformed
from database import get_db_session

session = get_db_session()

# Find orders missing customer_business_key
orders = session.query(StagingOrdersConformed).filter(
    StagingOrdersConformed.customer_business_key.is_(None),
    StagingOrdersConformed.source_load_date == date.today()
).all()

print(f"Orders with missing customer_business_key: {len(orders)}")
for order in orders[:10]:
    print(f"  Order ID: {order.order_id}")
```

### Find Duplicate Orders
```python
from sqlalchemy import func

# Find orders with same order_id and date
duplicates = session.query(
    StagingOrdersConformed.order_id,
    StagingOrdersConformed.order_date,
    func.count().label('cnt')
).filter(
    StagingOrdersConformed.source_load_date == date.today()
).group_by(
    StagingOrdersConformed.order_id,
    StagingOrdersConformed.order_date
).having(
    func.count() > 1
).all()

for order_id, order_date, count in duplicates:
    print(f"Order {order_id} on {order_date}: {count} occurrences")
```

### Audit Log Statistics
```python
# Count validation checks by status
from sqlalchemy import func

stats = session.query(
    ETLLog.status,
    func.count().label('count'),
    func.avg(ETLLog.details['execution_duration_seconds']).label('avg_duration')
).filter(
    ETLLog.process_name == "data_validator",
    ETLLog.log_date == date.today()
).group_by(
    ETLLog.status
).all()

for status, count, avg_duration in stats:
    print(f"{status}: {count} checks, avg duration {avg_duration:.2f}s")
```

---

## 10. Command Line Usage

### Run Validation from CLI
```bash
# Run in Python REPL
python -c "
from validation import MasterValidator
from datetime import date
validator = MasterValidator(date(2024, 1, 15))
result = validator.validate_all()
print(f'DQ Score: {result.validation_percent:.1f}%')
"
```

### Export Audit Logs to CSV
```bash
python -c "
from models import ETLLog
from database import get_db_session
import csv
from datetime import date

session = get_db_session()
audits = session.query(ETLLog).filter(
    ETLLog.process_name == 'data_validator',
    ETLLog.log_date == date(2024, 1, 15)
).all()

with open('audit_logs.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Check Name', 'Table', 'Status', 'Records Checked', 'Failed'])
    
    for audit in audits:
        details = audit.details
        writer.writerow([
            details['check_name'],
            details['table_name'],
            details['status'],
            details['total_records_checked'],
            details['records_failed']
        ])

print('Exported to audit_logs.csv')
"
```

---

**Last Updated**: May 21, 2024
**Status**: Production Ready ✅
