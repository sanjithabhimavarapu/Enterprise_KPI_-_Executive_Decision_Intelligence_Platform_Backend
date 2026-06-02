# Workflow Orchestration: Implementation & Deployment Guide

## Quick Start

### 1. Installation

```bash
# Python dependencies are already in requirements.txt
cd backend/python

# Verify dependencies
pip install -r requirements.txt

# Test orchestration module
python -c "from workflow_orchestrator import WorkflowOrchestrator; print('✓ Orchestration module loaded')"
```

### 2. Basic Execution

```bash
# Run ETL with orchestration (defaults: today's date, localhost)
python etl_workflow_adapter.py

# With custom date
python etl_workflow_adapter.py --date 2024-06-01

# With custom database
python etl_workflow_adapter.py --server prod-db.company.com --database KPI_DW

# Continue on errors (don't stop if task fails)
python etl_workflow_adapter.py --continue-on-error
```

### 3. Check Results

```bash
# Find latest execution report
ls -lt logs/orchestration_report_*.json | head -1

# View report
cat logs/orchestration_report_ETL_WORKFLOW_001_20240601_123456.json | python -m json.tool
```

---

## Architecture Overview

### File Structure

```
backend/python/
├── workflow_orchestrator.py         # ← Core orchestration engine (NEW)
├── etl_workflow_adapter.py          # ← ETL-specific implementation (NEW)
├── etl_orchestrator.py              # ← Existing ETL pipeline
├── database.py                      # ← Database connection
├── models.py                        # ← Data models
├── requirements.txt                 # ← Dependencies
├── ingestion/                       # ← Ingestion modules
├── validation/                      # ← Validation modules
├── reconciliation/                  # ← Reconciliation modules
└── logging/                         # ← Logging utilities

backend/documentation/architecture/
├── WORKFLOW_ORCHESTRATION_GUIDE.md  # ← Detailed orchestration guide (NEW)
├── PIPELINE_TRIGGERS_GUIDE.md       # ← Trigger configuration guide (NEW)
└── DATABASE_ARCHITECTURE.md         # ← Existing database docs

backend/etl/
├── sql_jobs/                        # ← SQL Server Agent jobs
│   ├── 01_create_etl_master_job.sql
│   ├── 02_create_incremental_load_jobs.sql
│   └── 03_create_monitoring_alerting_jobs.sql
└── schedules/
    └── ETL_JOB_SCHEDULE.md
```

---

## Production Deployment Steps

### Step 1: Prepare Environment

```bash
# 1.1 Create deployment folders
mkdir -p /opt/etl/{bin,config,logs,data}
cd /opt/etl

# 1.2 Copy Python scripts
cp /source/backend/python/*.py ./bin/
cp -r /source/backend/python/{ingestion,validation,reconciliation,logging} ./bin/

# 1.3 Copy configuration
cp /source/backend/configs/*.yaml ./config/

# 1.4 Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 1.5 Install dependencies
pip install --upgrade pip
pip install -r bin/requirements.txt
```

### Step 2: Configure Database Connection

Edit `config/database_config.yaml`:

```yaml
database:
  server: "prod-sql-server.company.com"
  database: "Enterprise_KPI_DW"
  username: "etl_service_account"
  password: "${DB_PASSWORD}"  # From environment variable
  driver: "ODBC Driver 17 for SQL Server"
  pool_size: 10
  max_overflow: 20
  connection_timeout: 30
```

Set environment variable:

```bash
export DB_PASSWORD="your_secure_password"
```

### Step 3: Create SQL Server Jobs

```sql
-- Execute on production SQL Server

-- 1. Create orchestration job
EXEC sp_add_job
    @job_name = 'ETL_Workflow_Orchestration',
    @enabled = 1,
    @description = 'Advanced workflow orchestration with error handling'

-- 2. Create schedule (12:45 AM daily)
EXEC sp_add_schedule
    @schedule_name = 'ETL_Nightly_Advanced',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 004500

-- 3. Attach schedule to job
EXEC sp_attach_schedule
    @job_name = 'ETL_Workflow_Orchestration',
    @schedule_name = 'ETL_Nightly_Advanced'

-- 4. Add job step
EXEC sp_add_jobstep
    @job_name = 'ETL_Workflow_Orchestration',
    @step_name = 'Execute_Python_Orchestrator',
    @subsystem = 'CmdExec',
    @command = 'C:\Python39\python.exe "C:\opt\etl\bin\etl_workflow_adapter.py"'

-- 5. Enable notifications
EXEC sp_update_job
    @job_name = 'ETL_Workflow_Orchestration',
    @notify_level_email = 2,  -- Email on failure
    @notify_email_operator_name = 'DBA Team'
```

### Step 4: Set Up Logging

```bash
# Create logging directory with proper permissions
mkdir -p /opt/etl/logs
chmod 755 /opt/etl/logs

# Create log rotation configuration
cat > /etc/logrotate.d/etl-orchestration << EOF
/opt/etl/logs/orchestration_*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 etl_user etl_group
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

# Activate log rotation
logrotate -v /etc/logrotate.d/etl-orchestration
```

### Step 5: Create Monitoring Alerts

```sql
-- SQL Server Database Mail (for email alerts)
EXEC sp_send_dbmail
    @profile_name = 'Default',
    @recipients = 'dba-team@company.com',
    @subject = 'ETL Orchestration - Daily Report',
    @body = 'ETL execution summary attached',
    @query = 'SELECT TOP 10 * FROM vw_etl_workflow_executions ORDER BY start_time DESC'

-- Or create stored procedure for monitoring
CREATE PROCEDURE sp_monitor_etl_workflow AS
BEGIN
    DECLARE @LastStatus NVARCHAR(20)
    DECLARE @LastDuration FLOAT
    
    SELECT TOP 1
        @LastStatus = status,
        @LastDuration = duration_seconds
    FROM vw_etl_workflow_executions
    ORDER BY start_time DESC
    
    -- Alert if workflow failed
    IF @LastStatus = 'FAILED'
    BEGIN
        EXEC sp_send_dbmail
            @recipients = 'dba-team@company.com',
            @subject = 'ALERT: ETL Workflow Failed',
            @body = 'Last ETL workflow execution failed'
    END
    
    -- Alert if workflow took too long
    IF @LastDuration > 7200  -- 2 hours
    BEGIN
        EXEC sp_send_dbmail
            @recipients = 'dba-team@company.com',
            @subject = 'WARNING: ETL Workflow Slow',
            @body = CONCAT('ETL took ', @LastDuration, ' seconds to complete')
    END
END
```

### Step 6: Create REST API Endpoint (Optional)

```bash
# 6.1 Create systemd service for Flask API
cat > /etc/systemd/system/etl-webhook.service << EOF
[Unit]
Description=ETL Webhook API
After=network.target

[Service]
Type=simple
User=etl_user
WorkingDirectory=/opt/etl
Environment="PYTHONUNBUFFERED=1"
ExecStart=/opt/etl/venv/bin/python /opt/etl/bin/etl_webhook_api.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 6.2 Enable and start service
systemctl daemon-reload
systemctl enable etl-webhook
systemctl start etl-webhook

# 6.3 Verify service
systemctl status etl-webhook

# 6.4 Check webhook is responding
curl http://localhost:5000/api/trigger-etl/status
```

---

## Configuration Examples

### High-Frequency Orchestration (Hourly)

```python
# For frequent runs, adjust retry policies to fail faster
RetryPolicy(
    strategy=RetryStrategy.CIRCUIT_BREAKER,
    max_attempts=1,  # Fail fast
    initial_delay_seconds=0
)
```

### Low-Latency Ingestion

```python
# For real-time data feeds, reduce timeouts
WorkflowTask(
    task_id="TASK_INGEST_RT",
    task_name="Real-Time Ingestion",
    execute_func=ingest_realtime_data,
    timeout_seconds=30,  # Short timeout
    retry_policy=RetryPolicy(
        strategy=RetryStrategy.EXPONENTIAL_BACKOFF,
        max_attempts=2
    )
)
```

### High-Reliability (Critical Data)

```python
# For critical loads, use aggressive retries
RetryPolicy(
    strategy=RetryStrategy.EXPONENTIAL_BACKOFF,
    max_attempts=5,
    initial_delay_seconds=10,
    backoff_multiplier=3.0,
    jitter=True
)
```

---

## Testing & Validation

### Unit Tests

```python
# test_orchestration.py
import asyncio
import pytest
from workflow_orchestrator import WorkflowOrchestrator, WorkflowTask, RetryPolicy

@pytest.mark.asyncio
async def test_workflow_execution():
    """Test basic workflow execution."""
    
    # Create simple task
    async def sample_task(ctx):
        ctx.metadata['executed'] = True
    
    orchestrator = WorkflowOrchestrator("TEST_001", "Test Workflow")
    task = WorkflowTask("TASK_001", "Sample", sample_task)
    orchestrator.add_task(task)
    
    # Execute
    success = await orchestrator.execute()
    
    assert success
    assert orchestrator.task_results["TASK_001"].status.value == "SUCCESS"

@pytest.mark.asyncio
async def test_retry_logic():
    """Test retry mechanism."""
    
    attempt_count = 0
    
    async def failing_task(ctx):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count < 3:
            raise Exception("Temporary failure")
    
    task = WorkflowTask(
        "TASK_RETRY",
        "Retry Test",
        failing_task,
        retry_policy=RetryPolicy(max_attempts=3)
    )
    
    success = await task.execute()
    
    assert success
    assert attempt_count == 3

@pytest.mark.asyncio
async def test_dependency_handling():
    """Test task dependencies."""
    
    execution_order = []
    
    async def task_1(ctx):
        execution_order.append("TASK_1")
    
    async def task_2(ctx):
        execution_order.append("TASK_2")
    
    orchestrator = WorkflowOrchestrator("DEP_001", "Dependency Test")
    
    t1 = WorkflowTask("T1", "First", task_1)
    t2 = WorkflowTask(
        "T2",
        "Second",
        task_2,
        dependencies=[TaskDependency("T1")]
    )
    
    orchestrator.add_task(t1)
    orchestrator.add_task(t2)
    
    await orchestrator.execute()
    
    assert execution_order == ["TASK_1", "TASK_2"]
```

Run tests:

```bash
pytest test_orchestration.py -v

# With coverage
pytest test_orchestration.py --cov=workflow_orchestrator --cov-report=html
```

### Integration Tests

```bash
# 1. Test with sample data
python etl_workflow_adapter.py --date 2024-05-01

# 2. Check execution report
cat logs/orchestration_report_*.json | python -m json.tool

# 3. Verify database state
SELECT COUNT(*) FROM fact_orders WHERE load_date = '2024-05-01'
SELECT COUNT(*) FROM dim_customers WHERE effective_from = '2024-05-01'

# 4. Check logs for errors
grep -i "error\|failed" logs/orchestration_*.log
```

---

## Monitoring & Observability

### Create Monitoring Views

```sql
-- View: Latest ETL workflow executions
CREATE VIEW vw_etl_workflow_executions AS
SELECT
    workflow_id,
    workflow_name,
    status,
    start_time,
    end_time,
    DATEDIFF(SECOND, start_time, end_time) as duration_seconds,
    (SELECT COUNT(*) FROM orchestration_tasks t WHERE t.workflow_id = w.workflow_id AND t.status = 'SUCCESS')
        * 100.0 / NULLIF((SELECT COUNT(*) FROM orchestration_tasks WHERE workflow_id = w.workflow_id), 0)
    as success_rate
FROM orchestration_workflows w
ORDER BY start_time DESC

-- View: Failed tasks requiring investigation
CREATE VIEW vw_failed_workflow_tasks AS
SELECT
    w.workflow_id,
    w.workflow_name,
    t.task_id,
    t.task_name,
    t.status,
    t.error_message,
    t.attempt,
    t.max_attempts
FROM orchestration_workflows w
INNER JOIN orchestration_tasks t ON w.workflow_id = t.workflow_id
WHERE t.status = 'FAILED'
ORDER BY w.start_time DESC, t.task_id
```

### Create Dashboard Queries

```sql
-- Last 7 days execution summary
SELECT
    CAST(start_time AS DATE) as execution_date,
    COUNT(*) as total_runs,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_runs,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_runs,
    AVG(DATEDIFF(SECOND, start_time, end_time)) as avg_duration_seconds
FROM orchestration_workflows
WHERE start_time >= DATEADD(DAY, -7, GETDATE())
GROUP BY CAST(start_time AS DATE)
ORDER BY execution_date DESC

-- Task performance metrics
SELECT
    task_id,
    task_name,
    COUNT(*) as total_executions,
    AVG(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100 as success_rate_percent,
    AVG(DATEDIFF(SECOND, start_time, end_time)) as avg_duration_seconds,
    MAX(DATEDIFF(SECOND, start_time, end_time)) as max_duration_seconds,
    MIN(DATEDIFF(SECOND, start_time, end_time)) as min_duration_seconds
FROM orchestration_tasks
GROUP BY task_id, task_name
ORDER BY success_rate_percent ASC, total_executions DESC
```

---

## Troubleshooting

### Check Execution Status

```bash
# Find latest execution
LATEST_REPORT=$(ls -t logs/orchestration_report_*.json | head -1)

# Check status
jq '.status' "$LATEST_REPORT"

# Check failed tasks
jq '.task_results | to_entries[] | select(.value.status=="FAILED") | {id: .key, error: .value.error}' "$LATEST_REPORT"

# Check alerts
jq '.alerts[] | select(.severity=="ERROR")' "$LATEST_REPORT"
```

### Enable Debug Mode

```bash
# Edit etl_workflow_adapter.py
logger.setLevel(logging.DEBUG)

# Or run with debug flag
python etl_workflow_adapter.py --debug 2>&1 | tee debug.log

# Check debug output
grep "DEBUG\|TRACE" debug.log | head -50
```

### Test Individual Tasks

```python
# test_task.py
import asyncio
from etl_workflow_adapter import ETLWorkflowAdapter
from workflow_orchestrator import TaskContext

async def test_ingestion_task():
    adapter = ETLWorkflowAdapter()
    
    # Create task context
    ctx = TaskContext("TASK_INGEST", "Test Ingestion")
    
    # Execute just ingestion task
    try:
        await adapter.task_run_ingestion(ctx)
        print(f"✓ Ingestion completed: {ctx.metadata}")
    except Exception as e:
        print(f"✗ Ingestion failed: {e}")
        import traceback
        traceback.print_exc()

asyncio.run(test_ingestion_task())
```

### Database Connection Issues

```sql
-- Test connection from SQL Server
EXEC xp_cmdshell 'python -c "import pyodbc; print(pyodbc.connect(...))"'

-- Check connection pool
SELECT * FROM sys.dm_exec_connections
WHERE session_id > 50

-- Check SQL Server Agent error logs
EXEC msdb.dbo.sp_help_job @job_name='ETL_Workflow_Orchestration'
EXEC msdb.dbo.sp_help_jobhistory @job_name='ETL_Workflow_Orchestration'
```

---

## Performance Tuning

### Parallel Task Execution

```python
# Increase task parallelism by adjusting dependencies
# Example: Validation and KPI calc can run in parallel

task_kpi = WorkflowTask(..., dependencies=[TaskDependency("TASK_FACTS")])
task_validate = WorkflowTask(..., dependencies=[TaskDependency("TASK_FACTS")])

# Both depend only on TASK_FACTS, so they'll run in parallel
```

### Timeout Optimization

```python
# Analyze historical execution times
SELECT
    task_name,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_seconds) as p95_duration,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_seconds) as p99_duration
FROM orchestration_tasks
GROUP BY task_name

# Set timeout = p99_duration * 1.1 (10% buffer above worst case)
```

---

## Maintenance

### Regular Tasks

```bash
# Daily: Monitor ETL health
0 8 * * * /opt/etl/bin/check_etl_health.sh | mail -s "Daily ETL Report" admin@company.com

# Weekly: Clean old logs
0 3 * * 0 find /opt/etl/logs -name "*.log" -mtime +30 -delete

# Monthly: Update statistics
0 2 1 * * python /opt/etl/bin/update_statistics.py

# Quarterly: Analyze performance
0 1 1 */3 * python /opt/etl/bin/performance_analysis.py
```

---

## Disaster Recovery

### Backup Orchestration Metadata

```bash
# Backup to file
sqlcmd -S prod-sql -d Enterprise_KPI_DW -o backup_orchestration_$(date +%Y%m%d).bak \
  "BACKUP DATABASE Enterprise_KPI_DW TO DISK=N'/backup/orchestration_backup_$(date +%Y%m%d).bak'"

# Backup to cloud storage
az storage blob upload --account-name storagename \
  --container-name backups \
  --name "orchestration_backup_$(date +%Y%m%d).bak" \
  --file "backup_orchestration_$(date +%Y%m%d).bak"
```

### Recovery Procedures

```bash
# 1. Identify last successful execution
SELECT TOP 1 * FROM orchestration_workflows WHERE status = 'SUCCESS'

# 2. Check what tasks succeeded
SELECT * FROM orchestration_tasks WHERE workflow_id = 'ETL_WORKFLOW_XXX'

# 3. Rollback if needed
python /opt/etl/bin/etl_workflow_adapter.py --rollback --workflow-id ETL_WORKFLOW_XXX

# 4. Rerun from specific task
python /opt/etl/bin/etl_workflow_adapter.py --start-from TASK_FACTS
```

---

## Summary

**Installation**: Copy files, set up virtual environment
**Configuration**: Database credentials, schedules
**Deployment**: SQL Server jobs, API endpoints
**Testing**: Unit tests, integration tests, manual validation
**Monitoring**: Views, dashboards, alerts
**Maintenance**: Log rotation, backup procedures, performance tuning

For detailed information, refer to:
- [WORKFLOW_ORCHESTRATION_GUIDE.md](WORKFLOW_ORCHESTRATION_GUIDE.md)
- [PIPELINE_TRIGGERS_GUIDE.md](PIPELINE_TRIGGERS_GUIDE.md)
