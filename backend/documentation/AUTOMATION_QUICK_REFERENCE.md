# Automation System - Quick Reference Guide

## Quick Start

### 1. Basic Reconciliation

```python
from datetime import date
from reconciliation.automated_reconciliation_scheduler import (
    AutomatedReconciler, ReconciliationConfig
)

config = ReconciliationConfig(
    reconciliation_name="Quick_Recon",
    data_types=["Orders"]
)

with AutomatedReconciler(config) as reconciler:
    result = reconciler.run(load_date=date.today())
    print(result["status"])
```

### 2. Basic Validation

```python
from validation.automated_validation_scheduler import (
    AutomatedValidator, ValidationConfig
)

config = ValidationConfig(
    validation_suite_name="Quick_Validation",
    checks=[]  # Configure checks as needed
)

with AutomatedValidator(config) as validator:
    result = validator.run()
    print(f"Passed: {result['passed']}, Failed: {result['failed']}")
```

### 3. Basic Orchestration

```python
from automation_orchestrator import AutomationOrchestrator, TaskConfig

with AutomationOrchestrator("Quick_Pipeline") as orch:
    orch.add_task(TaskConfig(
        task_id="recon",
        task_name="Reconciliation",
        task_type="reconciliation"
    ))
    
    result = orch.run()
    print(result["status"])
```

---

## Common Tasks

### Run Reconciliation for Specific Date

```python
from datetime import date
from reconciliation.automated_reconciliation_scheduler import (
    AutomatedReconciler, ReconciliationConfig
)

config = ReconciliationConfig(
    reconciliation_name="Historical_Recon",
    data_types=["Orders", "Customers", "Inventory"],
    alert_emails=["team@company.com"]
)

# Run for specific date
target_date = date(2024, 6, 1)

with AutomatedReconciler(config) as reconciler:
    result = reconciler.run(load_date=target_date)
    
    if result["status"] == "SUCCESS":
        print("✓ Reconciliation passed")
    else:
        print("✗ Reconciliation failed")
        for error in result.get("errors", []):
            print(f"  Error: {error}")
```

### Configure Custom Validation Checks

```python
from validation.automated_validation_scheduler import (
    AutomatedValidator, ValidationConfig, ValidationCheckConfig,
    ValidationSeverity
)
from datetime import date

# Define multiple checks
checks = [
    # Check 1: Null validation
    ValidationCheckConfig(
        check_id="orders_null",
        check_name="Orders Null Check",
        check_type="null_validation",
        table_name="stg_erp_orders_transformation",
        columns_to_check=["order_id", "customer_id", "order_date"],
        severity=ValidationSeverity.CRITICAL
    ),
    
    # Check 2: Duplicate detection
    ValidationCheckConfig(
        check_id="orders_dup",
        check_name="Orders Duplicate Check",
        check_type="duplicate",
        table_name="stg_erp_orders_transformation",
        columns_to_check=["order_id"],
        severity=ValidationSeverity.BLOCKER
    ),
    
    # Check 3: Custom SQL
    ValidationCheckConfig(
        check_id="orders_amount",
        check_name="Orders Amount Check",
        check_type="custom_sql",
        table_name="stg_erp_orders_transformation",
        sql_query="""
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN amount > 0 THEN 1 ELSE 0 END) as valid
            FROM stg_erp_orders_transformation
            WHERE CAST(load_date AS DATE) = :load_date
        """,
        severity=ValidationSeverity.WARNING
    )
]

# Configure suite
config = ValidationConfig(
    validation_suite_name="Orders_Quality_Suite",
    checks=checks,
    parallel_execution=True,
    max_parallel_checks=5,
    alert_emails=["qa@company.com"]
)

# Run validation
with AutomatedValidator(config) as validator:
    result = validator.run(load_date=date.today())
    
    # Check results
    print(f"Total Checks: {result['total_checks']}")
    print(f"Passed: {result['passed']}")
    print(f"Failed: {result['failed']}")
    
    # Show failed checks
    for check in result["results"]:
        if check["status"] != "PASS":
            print(f"\n{check['check_name']}: {check['status']}")
            print(f"  Records: {check['total_records']}")
            print(f"  Failed: {check['invalid_records']}")
            print(f"  Details: {check['details']}")
```

### Set Up Full Orchestrated Pipeline

```python
from automation_orchestrator import (
    AutomationOrchestrator, TaskConfig, AlertConfig
)
from datetime import date
import json

# Configure alerts
alerts = AlertConfig(
    enabled=True,
    on_failure=True,
    on_partial=True,
    email_recipients=["admin@company.com", "team@company.com"],
    webhook_urls=["https://hooks.slack.com/services/YOUR/WEBHOOK"],
    slack_channels=["#data-pipeline"]
)

# Create orchestrator
with AutomationOrchestrator("Daily_ETL_Pipeline", alerts) as orch:
    
    # Task 1: Reconciliation (no dependencies)
    orch.add_task(TaskConfig(
        task_id="recon_orders",
        task_name="Orders Reconciliation",
        task_type="reconciliation",
        severity="CRITICAL",
        enabled=True,
        retry_on_failure=True,
        max_retries=3
    ))
    
    orch.add_task(TaskConfig(
        task_id="recon_customers",
        task_name="Customers Reconciliation",
        task_type="reconciliation",
        severity="CRITICAL",
        enabled=True,
        run_parallel=True  # Can run in parallel with orders recon
    ))
    
    # Task 2: Validation (depends on reconciliation)
    orch.add_task(TaskConfig(
        task_id="validate_data",
        task_name="Data Quality Validation",
        task_type="validation",
        severity="WARNING",
        depends_on=["recon_orders", "recon_customers"],
        enabled=True,
        retry_on_failure=True
    ))
    
    # Task 3: Audit (depends on all above)
    orch.add_task(TaskConfig(
        task_id="audit_log",
        task_name="Audit Trail Logging",
        task_type="audit",
        severity="INFO",
        depends_on=["validate_data"],
        enabled=True
    ))
    
    # Execute workflow
    result = orch.run(load_date=date.today())
    
    # Display results
    print(json.dumps(result, indent=2, default=str))
    
    # Check overall status
    if result["status"] == "SUCCESS":
        print("\n✓ Pipeline executed successfully")
    elif result["status"] == "PARTIAL_SUCCESS":
        print("\n⚠ Pipeline completed with warnings")
    else:
        print("\n✗ Pipeline failed")
```

### Log Audit Trail

```python
from logging.audit_logger import AuditLogger, AuditAction, AuditEntityType

with AuditLogger() as audit:
    # Log ETL process
    audit.log_etl_process(
        process_name="Orders_Load",
        step_name="Staging_Transform",
        status="SUCCESS",
        record_count=5000,
        details={"records_loaded": 5000, "duration_seconds": 120},
        source_system="ERP",
        target_system="Staging"
    )
    
    # Log data change
    audit.log_data_change(
        table_name="orders",
        record_id="ORD-123456",
        action=AuditAction.UPDATE,
        before={"status": "pending"},
        after={"status": "completed"},
        change_reason="Order fulfillment"
    )
    
    # Log validation
    audit.log_validation(
        validation_name="Null_Check",
        table_name="staging_orders",
        total_records=5000,
        passed_records=4950,
        failed_records=50,
        details={"columns_checked": ["order_id", "customer_id"]}
    )
```

### Query Audit Trail

```python
from logging.audit_logger import AuditLogger
from datetime import datetime, timedelta

with AuditLogger() as audit:
    # Get audit trail for table
    trail = audit.get_audit_trail(
        entity_name="orders",
        start_date=datetime.now() - timedelta(days=7),
        end_date=datetime.now(),
        limit=100
    )
    
    # Display changes
    for entry in trail:
        print(f"{entry['timestamp']}: {entry['action']} by {entry['user_id']}")
    
    # Generate compliance report
    report = audit.generate_compliance_report(
        start_date=date(2024, 1, 1),
        end_date=date(2024, 6, 30)
    )
    
    print(json.dumps(report, indent=2))
```

---

## Scheduling with SQL Server Agent

### Create SQL Server Agent Job

```sql
-- Create new job
EXEC msdb.dbo.sp_add_job 
    @job_name = 'Daily_ETL_Automation',
    @enabled = 1;

-- Add job step - Python script
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'Daily_ETL_Automation',
    @step_name = 'Run_Orchestration',
    @subsystem = 'PowerShell',
    @command = N'
        cd "C:\path\to\backend\python"
        python -c "
from automation_orchestrator import AutomationOrchestrator, AlertConfig
from datetime import date
import json

alerts = AlertConfig(enabled=True, on_failure=True)
with AutomationOrchestrator(""Daily_Pipeline"", alerts) as orch:
    # Add your tasks here
    result = orch.run(load_date=date.today())
    print(json.dumps(result, indent=2, default=str))
"',
    @retry_attempts = 3,
    @retry_interval = 5;

-- Create schedule - Daily at 1 AM
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Daily_1AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 010000;

-- Attach schedule to job
EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'Daily_ETL_Automation',
    @schedule_name = 'Daily_1AM';
```

### Check Job Execution History

```sql
SELECT TOP 20
    j.name as job_name,
    jh.step_name,
    CASE jh.run_status 
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'In Progress'
    END as status,
    CONVERT(DATETIME, CAST(jh.run_date AS VARCHAR) + ' ' + 
            CAST(jh.run_time AS VARCHAR(6))) as execution_time,
    jh.run_duration as duration_seconds
FROM msdb.dbo.sysjobhistory jh
INNER JOIN msdb.dbo.sysjobs j ON jh.job_id = j.job_id
ORDER BY jh.run_date DESC, jh.run_time DESC;
```

---

## Monitoring & Troubleshooting

### Monitor Active Jobs

```python
from automation_orchestrator import AutomationOrchestrator
from sqlalchemy import text
from database import get_db_session

session = get_db_session()

# Check running orchestrations
query = text("""
    SELECT 
        JSON_EXTRACT(details, '$.execution_id') as execution_id,
        JSON_EXTRACT(details, '$.workflow') as workflow,
        JSON_EXTRACT(details, '$.status') as status,
        log_date,
        JSON_EXTRACT(details, '$.started_at') as start_time
    FROM etl_logs
    WHERE process_name LIKE 'orchestration_%'
    AND status = 'RUNNING'
    ORDER BY log_date DESC
""")

results = session.execute(query).fetchall()
for result in results:
    print(f"Execution: {result[0]} | Workflow: {result[1]} | Status: {result[2]}")
```

### View Execution Logs

```python
from sqlalchemy import text
from database import get_db_session
from datetime import date

session = get_db_session()

# Get logs for a specific date
query = text("""
    SELECT 
        process_name,
        process_step,
        status,
        record_count,
        details
    FROM etl_logs
    WHERE log_date = :log_date
    ORDER BY log_date DESC, created_at DESC
""")

logs = session.execute(query, {"log_date": date.today()}).fetchall()
for log in logs:
    print(f"[{log[0]}] {log[1]}: {log[2]} ({log[3]} records)")
```

### Analyze Performance

```python
from sqlalchemy import text
from database import get_db_session
from datetime import datetime, timedelta

session = get_db_session()

# Average execution duration by task
query = text("""
    SELECT 
        JSON_EXTRACT(details, '$.task_name') as task_name,
        AVG(CAST(JSON_EXTRACT(details, '$.duration_seconds') AS FLOAT)) as avg_duration,
        MIN(CAST(JSON_EXTRACT(details, '$.duration_seconds') AS FLOAT)) as min_duration,
        MAX(CAST(JSON_EXTRACT(details, '$.duration_seconds') AS FLOAT)) as max_duration
    FROM etl_logs
    WHERE process_name LIKE 'orchestration_%'
    AND log_date >= :start_date
    GROUP BY JSON_EXTRACT(details, '$.task_name')
    ORDER BY avg_duration DESC
""")

start_date = datetime.now() - timedelta(days=30)
results = session.execute(query, {"start_date": start_date}).fetchall()

for task, avg, min_dur, max_dur in results:
    print(f"{task}: Avg={avg:.1f}s, Min={min_dur:.1f}s, Max={max_dur:.1f}s")
```

---

## Configuration Examples

### Email Alerts Setup

```python
alert_config = AlertConfig(
    enabled=True,
    on_failure=True,
    on_success=False,
    on_partial=True,
    email_recipients=[
        "admin@company.com",
        "data-team@company.com",
        "executive-team@company.com"
    ]
)
```

### Webhook Integration

```python
alert_config = AlertConfig(
    webhook_urls=[
        "https://events.pagerduty.com/integration/...",  # PagerDuty
        "https://hooks.slack.com/services/...",          # Slack
        "https://api.datadog.com/webhooks/...",          # Datadog
    ]
)
```

### Task with Custom Retries

```python
task = TaskConfig(
    task_id="reconcile",
    task_name="Reconciliation",
    task_type="reconciliation",
    retry_on_failure=True,
    max_retries=5,
    retry_delay_seconds=120,  # 2 minute wait
    timeout_seconds=1800      # 30 minute timeout
)
```

---

## Useful SQL Queries

### Check Data Quality Trend

```sql
SELECT TOP 30
    check_date,
    check_name,
    AVG(quality_score) as avg_score,
    MIN(quality_score) as min_score,
    MAX(quality_score) as max_score
FROM data_quality_scores
GROUP BY check_date, check_name
ORDER BY check_date DESC;
```

### Find Failed Reconciliations

```sql
SELECT TOP 50
    load_date,
    reconciliation_type,
    source_name,
    record_variance,
    amount_variance_percent,
    reconciliation_status
FROM reconciliation_logs
WHERE reconciliation_status IN ('FAIL', 'CRITICAL')
ORDER BY load_date DESC;
```

### Audit Trail for Compliance

```sql
SELECT 
    JSON_EXTRACT(details, '$.timestamp') as action_time,
    JSON_EXTRACT(details, '$.user_id') as user_id,
    JSON_EXTRACT(details, '$.action') as action,
    JSON_EXTRACT(details, '$.entity_name') as entity,
    JSON_EXTRACT(details, '$.change_summary') as changes
FROM etl_logs
WHERE process_name LIKE 'audit_%'
AND log_date BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY JSON_EXTRACT(details, '$.timestamp') DESC;
```

---

## Error Recovery Examples

### Retry Failed Task

```python
# If a task fails, retry it
with AutomationOrchestrator("Retry_Pipeline") as orch:
    failed_task = TaskConfig(
        task_id="validate",
        task_name="Validation",
        task_type="validation",
        retry_on_failure=True,
        max_retries=5  # Retry up to 5 times
    )
    orch.add_task(failed_task)
    result = orch.run(date.today())
```

### Manual Data Correction + Re-reconciliation

```python
# Fix data issue
session.execute(text("""
    UPDATE stg_erp_orders_transformation
    SET order_amount = corrected_amount
    WHERE order_id IN (SELECT id FROM correction_list)
"""))
session.commit()

# Re-run reconciliation
config = ReconciliationConfig(
    reconciliation_name="Post_Correction_Recon",
    data_types=["Orders"]
)

with AutomatedReconciler(config) as reconciler:
    result = reconciler.run(load_date=date.today())
```

---

## Performance Tips

1. **Enable parallel execution** for independent tasks
2. **Configure appropriate timeouts** - don't set too high
3. **Use batch processing** for large datasets
4. **Archive old logs** regularly to maintain performance
5. **Index key columns** in ETL logs tables
6. **Monitor resource usage** - CPU, memory, I/O

---

**Version**: 1.0  
**Last Updated**: June 2024
