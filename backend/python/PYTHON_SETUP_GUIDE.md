"""
Python Backend Implementation - Quick Start Guide
=================================================

Complete setup instructions for the Enterprise KPI Platform Python backend.
"""

# STEP 1: ENVIRONMENT SETUP
# ========================

## Install Python 3.10+
```bash
python --version  # Should show 3.10 or higher
```

## Create Virtual Environment
```bash
python -m venv venv
source venv/Scripts/activate  # Windows: venv\Scripts\activate
```

## Install Dependencies
```bash
pip install -r backend/python/requirements.txt
```

## Configure Environment Variables
Create `backend/configs/environment/.env.local`:

```
# Database Connection
DB_SERVER=localhost
DB_PORT=1433
DB_NAME=KPI_DataWarehouse
DB_USER=sa
DB_PASSWORD=your_password
DB_DRIVER=ODBC Driver 17 for SQL Server

# Connection Pool
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20
DB_POOL_RECYCLE=3600
DB_POOL_PRE_PING=True

# Logging
LOG_LEVEL=INFO
LOG_FILE=logs/etl_pipeline.log

# Salesforce (if using)
SALESFORCE_INSTANCE_URL=https://yourinstance.salesforce.com
SALESFORCE_API_TOKEN=your_token

# Ingestion
INGESTOR_BATCH_SIZE=1000
INGESTOR_TIMEOUT=300
```

# STEP 2: DATABASE MODELS
# =======================

The ORM models are defined in `backend/python/models.py`:

## Key Model Groups

### 1. Staging Tables
- StagingOrdersConformed - ERP orders with margins
- StagingCustomersConformed - Salesforce customers
- StagingOpportunitiesConformed - Sales opportunities
- StagingInventoryConformed - Warehouse inventory
- StagingCustomerInteractionsConformed - Contact center interactions

### 2. Dimension Tables
- DimensionCustomer - SCD Type 2 customer tracking
- DimensionProduct - SCD Type 2 product tracking
- DimensionDate - Time dimension

### 3. Fact Tables
- FactSales - Transactional sales (500K+ daily)
- FactRevenue - Daily revenue aggregates
- FactCustomerInteractions - Interaction metrics

### 4. Support Tables
- ETLLog - Process execution logs
- DataQualityScore - Daily DQ metrics
- KPIResult - KPI calculation results
- ReconciliationLog - ETL reconciliation logs

# STEP 3: DATABASE CONNECTION
# ============================

```python
from database import init_db, get_db_session, DatabaseConfig

# Initialize connection
db = init_db(echo=False)

# Get a session
session = get_db_session()

# Use the session
from models import FactSales
orders = session.query(FactSales).filter(
    FactSales.load_date == date.today()
).all()

session.close()
```

# STEP 4: DATA INGESTION
# ======================

### Ingest ERP Orders from CSV
```python
from ingestion.data_ingestor import ERPOrdersIngestor

config = IngestorConfig(batch_size=1000)
with ERPOrdersIngestor(config) as ingestor:
    count = ingestor.ingest_from_csv("data/erp_orders.csv")
    print(f"Ingested {count} orders")
```

### Ingest Salesforce Data
```python
from ingestion.data_ingestor import SalesforceIngestor

with SalesforceIngestor(config, api_token="token", instance_url="url") as ingestor:
    customers = ingestor.ingest_customers()
    opportunities = ingestor.ingest_opportunities()
```

### Ingest from JSON
```python
from ingestion.data_ingestor import InventoryIngestor

with InventoryIngestor(config) as ingestor:
    count = ingestor.ingest_from_json("data/inventory.json")
```

### Run All Ingestion
```python
from ingestion.data_ingestor import MasterIngestor

master = MasterIngestor()
results = master.ingest_all(load_date=date.today())
# results: {'erp_orders': 500000, 'salesforce_customers': 5000, ...}
```

# STEP 5: DATA VALIDATION
# =======================

### Validate All Data
```python
from validation.data_validator import MasterValidator

validator = MasterValidator(load_date=date.today())
result = validator.validate_all()

print(f"DQ Score: {result.validation_percent:.1f}%")
print(f"Status: {result.status}")
# Validates: completeness, accuracy, consistency, business logic
```

### Individual Validators
```python
from validation.data_validator import StagingValidator, FactValidator

# Validate staging tables
with StagingValidator() as validator:
    validator.validate_orders()
    validator.validate_customers()
    summary = validator.get_summary()

# Validate fact tables
with FactValidator() as validator:
    validator.validate_fact_sales_completeness()
    validator.validate_fact_sales_amounts()
```

### Validation Checks Included
- Completeness: All required fields populated
- Accuracy: Calculated fields correct (margins, totals, dates)
- Consistency: Data types, ranges, relationships valid
- Duplicates: No duplicate business keys
- Business Logic: Order delivery dates, margin percentages

# STEP 6: DATA RECONCILIATION
# ============================

### Reconcile All ETL
```python
from reconciliation.data_reconciler import MasterReconciler

reconciler = MasterReconciler(load_date=date.today())
results = reconciler.reconcile_all()

print(f"Status: {results['overall_status']}")
print(f"Passed: {results['passed']}/{results['total_reconciliations']}")
```

### Individual Reconcilers
```python
from reconciliation.data_reconciler import OrderReconciler

with OrderReconciler(load_date=date.today(), variance_tolerance=0.01) as reconciler:
    reconciler.reconcile_from_staging()  # Source → Staging
    reconciler.reconcile_to_facts()      # Staging → Fact
    summary = reconciler.get_summary()
```

### What Gets Reconciled
- Record Counts: Source → Staging → Facts
- Total Amounts: Revenue matches across layers
- Variance Tolerance: Default 0.01% (configurable)
- Data Type Breakdown: Orders, Customers, Revenue, etc.

# STEP 7: END-TO-END ETL PIPELINE
# ================================

### Run Complete Pipeline
```bash
# Run with default settings (today's date, localhost)
python backend/python/etl_orchestrator.py

# Run with custom date
python backend/python/etl_orchestrator.py --date 2024-01-15

# Run with custom database
python backend/python/etl_orchestrator.py \
    --server prod-server \
    --database KPI_Prod \
    --username admin \
    --password password
```

### Pipeline Stages
1. **Initialization**: Database connection test
2. **Ingestion**: Load data from all sources
3. **Validation**: Data quality checks
4. **Reconciliation**: Source-to-fact verification

### Output
- Console logs with stage status
- `logs/etl_pipeline_YYYYMMDD_HHMMSS.log` file
- Database logs in `etl_logs` table
- DQ scores in `dq_scores` table
- Reconciliation results in `etl_reconciliation` table

# STEP 8: PRODUCTION DEPLOYMENT
# ==============================

### Docker Setup
```dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY backend/python/requirements.txt .
RUN pip install -r requirements.txt

COPY backend/python .
ENV DB_SERVER=prod-db.example.com
ENV DB_NAME=KPI_DataWarehouse

CMD ["python", "etl_orchestrator.py"]
```

### Schedule Jobs
```python
# Using APScheduler for job scheduling
from apscheduler.schedulers.background import BackgroundScheduler

scheduler = BackgroundScheduler()

# Run daily at 2 AM
scheduler.add_job(
    func=run_etl_pipeline,
    trigger="cron",
    hour=2,
    minute=0,
    id='daily_etl'
)

scheduler.start()
```

### Monitoring & Alerts
- Check `etl_logs` table for job status
- Monitor `dq_scores` for quality trends
- Alert if validation_percent < 95
- Alert if reconciliation status = FAIL

# STEP 9: COMMON OPERATIONS
# ==========================

### Query Ingestion Results
```python
session = get_db_session()
orders = session.query(StagingOrdersConformed).filter(
    StagingOrdersConformed.source_load_date == date.today()
).count()
print(f"Orders loaded: {orders}")
```

### Check Data Quality
```python
from models import DataQualityScore
dq = session.query(DataQualityScore).filter(
    DataQualityScore.load_date == date.today()
).first()
print(f"DQ Score: {dq.overall_dq_score}% ({dq.dq_status})")
```

### View ETL Logs
```python
from models import ETLLog
logs = session.query(ETLLog).filter(
    ETLLog.log_date == date.today()
).order_by(ETLLog.log_timestamp.desc()).all()

for log in logs:
    print(f"{log.process_name}: {log.status} - {log.record_count} records")
```

### Rerun Failed Stage
```python
# If ingestion failed, rerun just that stage
from ingestion.data_ingestor import MasterIngestor

master = MasterIngestor()
results = master.ingest_all(load_date=date(2024, 1, 15))
```

# TROUBLESHOOTING
# ===============

## Database Connection Errors
```
Error: Database connection failed
Solution:
1. Verify connection string in .env
2. Check SQL Server is running
3. Verify credentials
4. Test with: SELECT @@VERSION
```

## Out of Memory on Large Loads
```
Error: MemoryError during bulk insert
Solution:
1. Reduce batch_size in IngestorConfig
2. Split ingestion into date ranges
3. Increase server memory or use pagination
```

## Validation Failures
```
Error: Data quality score < 95%
Solution:
1. Check etl_logs for detailed errors
2. Run individual validators for each table
3. Review failed_records in validation results
```

## Reconciliation Mismatches
```
Error: Record variance > 0.01%
Solution:
1. Check for duplicate rows
2. Verify all records processed (no filter issues)
3. Compare record counts across stages
4. Review reconciliation_notes in database
```

# FILE STRUCTURE
# ==============

backend/python/
├── __init__.py                    # Package initialization
├── database.py                    # SQLAlchemy configuration
├── models.py                      # ORM models (all tables)
├── etl_orchestrator.py           # Main pipeline orchestration
├── requirements.txt              # Python dependencies
├── ingestion/
│   └── data_ingestor.py         # Data ingestion classes
├── validation/
│   └── data_validator.py        # Data quality validation
├── reconciliation/
│   └── data_reconciler.py       # ETL reconciliation
├── logging/
│   └── logger_config.py         # Logging configuration (create if needed)
├── automation/
│   └── job_scheduler.py         # Job scheduling (create if needed)
└── tests/
    └── test_*.py                # Unit tests (create if needed)

# NEXT STEPS
# ==========

1. ✓ Install dependencies: pip install -r requirements.txt
2. ✓ Configure environment: Copy example .env and update values
3. ✓ Create tables: db.create_tables()
4. ✓ Test connection: python -c "from database import init_db; init_db()"
5. ✓ Run sample ingestion: python ingestion/data_ingestor.py
6. ✓ Run sample validation: python validation/data_validator.py
7. ✓ Run complete pipeline: python etl_orchestrator.py
8. ✓ Check database tables for results

# SUPPORT & DOCUMENTATION
# ========================

- Database config: See database.py docstrings
- Model details: See models.py class definitions
- Ingestion guide: See ingestion/data_ingestor.py examples
- Validation rules: See validation/data_validator.py checks
- Reconciliation logic: See reconciliation/data_reconciler.py
- SQL stored procedures: See backend/database/stored_procedures/

"""

# Code examples follow...

if __name__ == "__main__":
    print(__doc__)
