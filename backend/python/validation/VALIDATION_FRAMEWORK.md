# Data Validation Framework - Enhanced Features

Complete data validation framework with duplicate checks, null validations, and audit logging.

## Overview

The validation framework provides **5 validation categories** across **7 check types**:

| Category | Checks | Purpose |
|----------|--------|---------|
| **Staging Validation** | Completeness, Consistency | Core data quality |
| **Fact Validation** | Dimensions, Amounts, Aggregates | Dimensional integrity |
| **Business Logic** | Delivery calculations, Margins | Business rule compliance |
| **Null Validation** | Field nullness checks | Required field enforcement |
| **Duplicate Detection** | Business key uniqueness | Data uniqueness |

---

## 1. Duplicate Checks

### Overview
Detects duplicate records using **business keys** (unique identifiers per data type).

### Configuration

```python
BUSINESS_KEYS = {
    'stg_orders_conformed': ['order_id', 'order_date'],      # Composite key
    'stg_customers_conformed': ['customer_id'],              # Single key
    'stg_opportunities_conformed': ['opportunity_id'],       # Single key
    'stg_inventory_conformed': ['warehouse_id', 'product_sku'] # Composite key
}
```

### Usage

```python
from validation import DuplicateValidator

with DuplicateValidator(load_date=date(2024, 1, 15)) as validator:
    validator.validate_all_tables()
    summary = validator.get_summary()
    
    # Results
    for result in validator.results:
        if result.status == 'FAIL':
            print(f"Duplicates found: {result.table_name}")
            print(f"  IDs: {result.duplicate_ids}")
            print(f"  Count: {result.invalid_records}")
```

### Output Example

```
Duplicate Records (stg_orders_conformed): WARNING
  504,000 records | 1,200 duplicates | 99.76% unique
  Duplicates on keys: ['order_id', 'order_date']
  
Duplicate Records (stg_customers_conformed): PASS
  5,000 records | 0 duplicates | 100% unique
  Duplicates on keys: ['customer_id']
```

### Result Fields
- `duplicate_ids`: List of IDs with duplicate business keys
- `invalid_records`: Total duplicate record count
- `validation_percent`: Uniqueness percentage
- `status`: PASS (no duplicates) / WARNING (duplicates exist) / FAIL (high duplicate rate)

### Business Key Strategy
- **Composite Keys**: Use when single field insufficient (order_id + date)
- **Single Keys**: Use when single field is unique identifier
- **Custom Keys**: Can extend BUSINESS_KEYS dict for new tables

---

## 2. Null Validations

### Overview
Validates that **required fields** are never null, with field-level tracking.

### Configuration

```python
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
    'fact_sales': [
        'customer_key', 'product_key', 'order_date', 'net_amount'
    ]
}
```

### Usage

```python
from validation import NullValidator

with NullValidator(load_date=date.today()) as validator:
    validator.validate_all_tables()
    
    for result in validator.results:
        print(f"{result.table_name}: {result.status}")
        print(f"  Total: {result.total_records}")
        print(f"  Valid (no nulls): {result.valid_records}")
        print(f"  Null Field Details: {result.null_field_counts}")
        # Output: {'order_id': 0, 'customer_business_key': 5, 'product_sku': 10}
```

### Output Example

```
Null Field Validation (stg_orders_conformed): FAIL
  500,000 records checked | 150 with nulls | 99.97%
  Null fields: {'customer_business_key': 50, 'product_sku': 100}

Null Field Validation (stg_customers_conformed): PASS
  5,000 records checked | 0 with nulls | 100%
  Null fields: {}
```

### Result Fields
- `null_field_counts`: Dict mapping field names to null counts
- `invalid_records`: Total records with any null required field
- `validation_percent`: Completeness percentage
- `status`: PASS (≥99%) / WARNING (≥95%) / FAIL (<95%)

### Field-Level Tracking
```
null_field_counts = {
    'order_id': 0,                    # No nulls
    'customer_business_key': 50,      # 50 nulls
    'product_sku': 100,               # 100 nulls
    'order_date': 0,
    'order_quantity': 0,
    'net_amount': 0
}
```

---

## 3. Audit Logging

### Overview
Comprehensive audit trail of all validation activities with **detailed execution tracking**.

### ValidationAudit Structure

```python
@dataclass
class ValidationAudit:
    check_id: str                       # CHK_2024-01-15_0001
    check_name: str                     # "Null Field Validation"
    table_name: str                     # "stg_orders_conformed"
    status: ValidationStatus            # PASS / WARNING / FAIL
    executed_at: datetime               # When check ran
    total_records_checked: int          # 500,000
    records_failed: int                 # 150
    records_passed: int                 # 499,850
    failure_details: str                # "Nulls: {'field': count}"
    user_id: str                        # "system" or username
    execution_duration_seconds: float   # 2.34 seconds
    error_message: Optional[str]        # Error if failed
```

### Usage

```python
from validation import MasterValidator, NullValidator

validator = NullValidator()
validator.validate_null_fields('stg_orders_conformed', StagingOrdersConformed)

# Access audit logs
for audit in validator.audit_logs:
    print(f"Check ID: {audit.check_id}")
    print(f"Status: {audit.status}")
    print(f"Duration: {audit.execution_duration_seconds:.2f}s")
    print(f"Records Failed: {audit.records_failed}")
    
    # Convert to dict for storage
    audit_dict = audit.to_dict()
```

### Audit Data Storage

Audit logs are automatically stored in the `etl_logs` table:

```python
# Automatically logged
ETLLog(
    process_name="data_validator",
    process_step="Null Field Validation - stg_orders_conformed",
    record_count=500000,
    status="FAIL",
    log_date=date(2024, 1, 15),
    details={
        "check_id": "CHK_2024-01-15_0001",
        "status": "FAIL",
        "records_failed": 150,
        "execution_duration_seconds": 2.34,
        ...
    }
)
```

### Query Audit History

```python
from models import ETLLog
from datetime import date

# Get all validation audits
audits = session.query(ETLLog).filter(
    ETLLog.process_name == "data_validator",
    ETLLog.log_date == date(2024, 1, 15)
).order_by(ETLLog.log_timestamp.desc()).all()

for audit in audits:
    print(f"{audit.process_step}: {audit.status}")
    print(f"Records: {audit.record_count}")
    
    # Extract details
    details = audit.details  # Already parsed from JSON
    print(f"Duration: {details['execution_duration_seconds']:.2f}s")
```

### Audit Trail Features
- **Execution Timing**: Track validation duration
- **Record Counts**: Pass/fail record counts
- **Error Messages**: Capture any exceptions
- **User Tracking**: Record who ran validation
- **Detailed Results**: Store full validation outcome
- **Queryable History**: All audits in database for compliance

---

## 4. Enhanced Validation Framework

### Framework Architecture

```
ValidationResult
├── check_name, table_name, status
├── total_records, valid_records, invalid_records
├── validation_percent, details
├── failed_records (list)
├── audit_log (ValidationAudit)       ← NEW
├── duplicate_ids (list)               ← NEW
└── null_field_counts (dict)           ← NEW

ValidationAudit
├── check_id, check_name, table_name
├── status, executed_at
├── total_records_checked
├── records_failed, records_passed
├── failure_details
├── execution_duration_seconds
└── error_message

BaseValidator
├── audit_logs (list)                  ← NEW
├── check_counter                      ← NEW
├── add_result(result)                 ← ENHANCED
├── _log_audit_entry(audit)           ← NEW
├── create_audit_log(...)             ← NEW
└── get_summary()                      ← ENHANCED
```

### Validator Classes

| Class | Purpose | Key Methods |
|-------|---------|------------|
| `StagingValidator` | Staging table quality | validate_orders(), validate_customers() |
| `FactValidator` | Fact table integrity | validate_fact_sales_completeness() |
| `BusinessLogicValidator` | Business rules | validate_order_delivery_logic() |
| `NullValidator` | Required fields | validate_null_fields(), validate_all_tables() |
| `DuplicateValidator` | Business key uniqueness | validate_duplicates_by_keys() |
| `MasterValidator` | Orchestration | validate_all() |

### Example: Complete Validation with All Features

```python
from validation import MasterValidator
from datetime import date

# Run complete validation
validator = MasterValidator(load_date=date(2024, 1, 15))
result = validator.validate_all()

print(f"DQ Score: {result.validation_percent:.1f}%")
print(f"Status: {result.status}")
print(f"\nBreakdown:")
print(f"  Total Checks: {result.total_records}")
print(f"  Passed: {result.valid_records}")
print(f"  Failed: {result.invalid_records}")

# View audit logs
from models import ETLLog

audits = session.query(ETLLog).filter(
    ETLLog.process_name == "data_validator",
    ETLLog.log_date == date(2024, 1, 15)
).all()

print(f"\nAudit Trail ({len(audits)} entries):")
for audit in audits:
    print(f"  - {audit.process_step}: {audit.status}")
```

### Output Example

```
Starting master validation for 2024-01-15

Validation Results:
  Total Checks: 12
  Passed: 10
  Failed: 1
  Warnings: 1

Validation Breakdown:
  Staging Checks: 4
  Fact Checks: 3
  Null Validations: 2
  Duplicate Checks: 3

DQ Score: 96.2% (Excellent)

[12 audit entries logged to etl_logs table]
```

---

## 5. Validation Status Flow

```
Record → Null Check → Duplicate Check → Business Logic → Accuracy → Status
           ✓              ✓                  ✓            ✓        → PASS
           ✗                                                        → FAIL
                          ✗                                         → FAIL
                                             ✗                      → FAIL
                                                          ✗         → FAIL
```

### Status Determination

| Check Type | PASS | WARNING | FAIL |
|-----------|------|---------|------|
| **Null Validation** | ≥99% | 95-98% | <95% |
| **Duplicates** | 0 dupes | <1% | >1% |
| **Business Logic** | 100% calc ok | 95-99% | <95% |
| **Overall DQ Score** | ≥95% | 85-94% | <85% |

---

## 6. Common Patterns

### Check for Specific Duplicates

```python
from validation import DuplicateValidator

with DuplicateValidator() as validator:
    validator.validate_duplicates_by_keys(
        table_name='stg_orders_conformed',
        model_class=StagingOrdersConformed,
        key_fields=['order_id', 'order_date']
    )
    
    result = validator.results[0]
    if result.duplicate_ids:
        print(f"Duplicate order IDs: {result.duplicate_ids}")
```

### Check for Null Values in Specific Table

```python
from validation import NullValidator

with NullValidator() as validator:
    validator.validate_null_fields(
        table_name='stg_customers_conformed',
        model_class=StagingCustomersConformed
    )
    
    result = validator.results[0]
    for field, null_count in result.null_field_counts.items():
        if null_count > 0:
            print(f"{field}: {null_count} nulls")
```

### Access Full Audit Trail

```python
from validation import MasterValidator
from models import ETLLog

validator = MasterValidator()
result = validator.validate_all()

# Query audit logs
audits = session.query(ETLLog).filter(
    ETLLog.process_name == "data_validator"
).order_by(ETLLog.log_timestamp.desc()).limit(20).all()

for audit in audits:
    details = audit.details
    print(f"{details['check_name']}: {details['status']}")
    print(f"  Duration: {details['execution_duration_seconds']:.2f}s")
    print(f"  Records Failed: {details['records_failed']}")
```

---

## 7. Performance Considerations

### Validation Duration

| Operation | Volume | Duration |
|-----------|--------|----------|
| Staging Validation | 2.5M | ~1 min |
| Fact Validation | 500K | ~30 sec |
| Null Validation | 2.5M | ~1 min |
| Duplicate Detection | 2.5M | ~2 min |
| **Total Pipeline** | **2.5M** | **~5 min** |

### Optimization Tips

1. **Batch Processing**: Duplicates detected via in-memory comparison
2. **Index Usage**: SQLAlchemy uses database indexes for queries
3. **Parallel Validators**: Each validator class processes independently
4. **Lazy Evaluation**: Null checks use SQL filters (not in-memory)

---

## 8. Troubleshooting

### Issue: High Null Count

**Symptom**: Null validation fails with many nulls

```
Null Field Validation (stg_orders_conformed): FAIL
  customer_business_key: 5,000 nulls
```

**Solution**:
1. Check source data mapping
2. Verify ETL transformation logic
3. Review ingestion filter conditions

### Issue: Duplicate Warnings

**Symptom**: Duplicates detected on business keys

```
Duplicate Records (stg_orders_conformed): WARNING
  1,200 duplicates on ['order_id', 'order_date']
```

**Solution**:
1. Verify business key uniqueness in source
2. Check for data reloads in same batch
3. Review deduplication logic

### Issue: Audit Logs Missing

**Symptom**: Validation runs but no audit entries in database

**Solution**:
1. Verify ETLLog table exists
2. Check database session commit
3. Review error logs for SQL exceptions

---

## 9. Integration with ETL Pipeline

```python
from validation import MasterValidator
from reconciliation import MasterReconciler
from datetime import date

# In ETL Orchestrator
load_date = date(2024, 1, 15)

# Stage 3: Validation (with all new features)
validator = MasterValidator(load_date)
dq_result = validator.validate_all()

# Check result
if dq_result.status == 'FAIL':
    logger.error(f"Data quality failed: {dq_result.details}")
    # Could halt pipeline or alert
else:
    logger.info(f"Data quality passed: {dq_result.validation_percent:.1f}%")
    
    # Proceed to Stage 4: Reconciliation
    reconciler = MasterReconciler(load_date)
    reconcile_result = reconciler.reconcile_all()
```

---

## 10. Next Steps

1. ✅ Deploy enhanced validation framework
2. ✅ Run daily validation with audit logging
3. Monitor null and duplicate trends
4. Adjust thresholds based on data patterns
5. Build validation dashboards from audit logs

---

**Version**: 1.0.0
**Last Updated**: May 21, 2024
**Status**: Production Ready ✅
