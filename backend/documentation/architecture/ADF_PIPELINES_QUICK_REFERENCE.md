# ADF Pipelines & Workflow Orchestration - Quick Reference

## What Was Implemented

### 1. **Advanced Workflow Orchestration Engine** (`workflow_orchestrator.py`)

A production-grade orchestration framework providing:

**Core Features:**
- ✓ Task dependency management (topological sorting)
- ✓ Multiple retry strategies (exponential, linear, circuit breaker)
- ✓ Async task execution
- ✓ Comprehensive error handling and recovery
- ✓ Rollback capability
- ✓ Health monitoring and alerting
- ✓ Execution reporting (JSON format)

**Key Classes:**
- `WorkflowOrchestrator` - Main orchestration engine
- `WorkflowTask` - Individual task definition
- `RetryPolicy` - Configurable retry strategies
- `TaskDependency` - Task dependency definition
- `WorkflowHealthMonitor` - Health checks and reporting
- `RetryHandler` - Retry logic implementation

### 2. **ETL Workflow Adapter** (`etl_workflow_adapter.py`)

Integrates orchestration with existing ETL pipeline:

**ETL Tasks:**
1. Initialize Database
2. Data Ingestion (ERP, Salesforce, Inventory)
3. Staging Transformation
4. Dimension Load (with rollback)
5. Fact Load (with rollback)
6. KPI Calculation
7. Data Quality Validation
8. ETL Reconciliation
9. Staging Cleanup
10. Post-ETL Health Check

**Task Dependencies:**
```
Init DB
  ↓
Ingestion
  ↓
Staging Transform
  ↓
Dimensions ────┐
  ↓             │
Facts ────────┤ (parallel)
  ├→ KPIs ────┤
  └→ Validate─┤
       ↓      │
    Reconcile─┘
       ↓
    Cleanup
       ↓
    Health Check
```

### 3. **Pipeline Triggers** (See PIPELINE_TRIGGERS_GUIDE.md)

Multiple trigger mechanisms:
- **Scheduled**: SQL Server Agent, Windows Task Scheduler, cron
- **Event-Based**: File drops, message queues, data quality checks
- **Dependency**: Parent job completion, resource availability
- **Webhook**: REST API endpoints for external systems
- **Manual**: Ad-hoc execution

### 4. **Documentation**

Created comprehensive guides:
- `WORKFLOW_ORCHESTRATION_GUIDE.md` - Detailed orchestration reference
- `PIPELINE_TRIGGERS_GUIDE.md` - Trigger configuration guide
- `ORCHESTRATION_IMPLEMENTATION_GUIDE.md` - Deployment and setup
- `QUICK_REFERENCE.md` (this file)

---

## How It Works

### Execution Flow

```
1. Create Orchestrator
   ↓
2. Add Tasks with Dependencies
   ↓
3. Validate Dependencies
   ↓
4. Topological Sort (determine order)
   ↓
5. Execute Tasks Sequentially/Parallel
   ├→ Task executes
   ├→ On failure: Retry (with backoff)
   ├→ If retries exhausted: Skip or fail
   └→ Track status, duration, error
   ↓
6. Check Dependent Tasks
   ├→ If dependency failed & required: Skip
   └→ If dependency passed: Execute
   ↓
7. Generate Report
   ├→ Summary statistics
   ├→ Task results
   ├→ Alerts
   └→ Save JSON report
```

### Retry Strategies

| Strategy | Pattern | Use Case |
|----------|---------|----------|
| **Exponential** | 5s, 10s, 20s, 40s... | Network failures |
| **Linear** | 5s, 10s, 15s, 20s... | Resource contention |
| **Immediate** | No delay | Quick retries |
| **Circuit Breaker** | Fail fast after 3 failures | Cascading failures |

---

## Quick Start

### Basic Usage

```python
import asyncio
from etl_workflow_adapter import ETLWorkflowAdapter
from datetime import date

async def main():
    # Create adapter (defaults to today)
    adapter = ETLWorkflowAdapter(load_date=date(2024, 6, 1))
    
    # Execute workflow
    success = await adapter.execute_workflow(continue_on_error=False)
    
    # Results saved to: logs/orchestration_report_ETL_WORKFLOW_001_*.json
    return success

asyncio.run(main())
```

### Command Line

```bash
# Default (today, localhost)
python etl_workflow_adapter.py

# Custom date
python etl_workflow_adapter.py --date 2024-06-01

# Custom server
python etl_workflow_adapter.py --server prod-db.company.com --database KPI_DW

# Continue on errors
python etl_workflow_adapter.py --continue-on-error
```

### Check Results

```bash
# Find latest report
ls -lt logs/orchestration_report_*.json | head -1

# View report
cat logs/orchestration_report_ETL_WORKFLOW_001_*.json | python -m json.tool

# Extract key info
jq '.status, .duration_seconds, .alerts' report.json
```

---

## Task Configuration

### Add a New Task

```python
from workflow_orchestrator import WorkflowTask, RetryPolicy, TaskDependency

# Define task function
async def my_task(context: TaskContext):
    context.metadata['step'] = 'Processing'
    # Do work here
    context.metadata['result'] = 'Success'

# Create task
task = WorkflowTask(
    task_id="TASK_CUSTOM",
    task_name="My Custom Task",
    execute_func=my_task,
    retry_policy=RetryPolicy(max_attempts=3),
    timeout_seconds=600,
    dependencies=[TaskDependency("TASK_PARENT", required=True)],
    rollback_func=None,
    on_failure=None
)

# Add to orchestrator
orchestrator.add_task(task)
```

### Customize Retry Policy

```python
from workflow_orchestrator import RetryPolicy, RetryStrategy

# Exponential backoff (default)
policy1 = RetryPolicy(
    strategy=RetryStrategy.EXPONENTIAL_BACKOFF,
    max_attempts=5,
    initial_delay_seconds=10,
    backoff_multiplier=2.0,
    jitter=True
)

# Circuit breaker (fail fast)
policy2 = RetryPolicy(
    strategy=RetryStrategy.CIRCUIT_BREAKER,
    max_attempts=1
)

# Linear backoff
policy3 = RetryPolicy(
    strategy=RetryStrategy.LINEAR_BACKOFF,
    max_attempts=3,
    initial_delay_seconds=5
)
```

---

## Monitoring & Alerts

### Execution Metrics

```python
from workflow_orchestrator import WorkflowHealthMonitor

monitor = WorkflowHealthMonitor()
metrics = monitor.check_workflow_health(orchestrator)

# Metrics include:
# - total_tasks
# - successful_tasks
# - failed_tasks
# - skipped_tasks
# - success_rate (%)
# - total_duration (seconds)
# - alerts_count
# - critical_alerts
```

### Generate Report

```python
# Get execution report
report = orchestrator.get_execution_report()

# Contains:
# - workflow_id, workflow_name
# - status (SUCCESS/FAILED)
# - start_time, end_time, duration_seconds
# - execution_order
# - task_results (with status, error, metadata)
# - alerts (with severity, message, task_id)

# Save to file
report_path = orchestrator.save_report()
```

### SQL Monitoring Views

```sql
-- Latest execution status
SELECT TOP 10
    workflow_id,
    workflow_name,
    status,
    start_time,
    DATEDIFF(SECOND, start_time, end_time) as duration_seconds
FROM orchestration_workflows
ORDER BY start_time DESC

-- Task success rates
SELECT
    task_name,
    COUNT(*) as executions,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as success_rate
FROM orchestration_tasks
GROUP BY task_name
ORDER BY success_rate ASC
```

---

## Trigger Setup

### Scheduled Trigger (SQL Server Agent)

```sql
-- Create schedule
EXEC sp_add_schedule
    @schedule_name = 'ETL_Daily',
    @freq_type = 4,
    @active_start_time = 004500

-- Create job
EXEC sp_add_job @job_name = 'ETL_Orchestration'

-- Add step
EXEC sp_add_jobstep
    @job_name = 'ETL_Orchestration',
    @command = 'C:\Python39\python.exe C:\backend\etl_workflow_adapter.py'

-- Attach schedule
EXEC sp_attach_schedule
    @job_name = 'ETL_Orchestration',
    @schedule_name = 'ETL_Daily'
```

### Event Trigger (File Drop)

```python
from pathlib import Path
import asyncio

async def monitor_files():
    from etl_workflow_adapter import ETLWorkflowAdapter
    
    watch_folder = Path("C:\\data\\incoming")
    
    while True:
        # Look for CSV files
        for file in watch_folder.glob("*.csv"):
            print(f"File detected: {file.name}")
            
            # Trigger ETL
            adapter = ETLWorkflowAdapter()
            await adapter.execute_workflow()
            
            # Archive file
            file.rename(watch_folder / "processed" / file.name)
        
        await asyncio.sleep(30)  # Check every 30 seconds

asyncio.run(monitor_files())
```

### Webhook Trigger (REST API)

```bash
# Trigger via HTTP
curl -X POST http://localhost:5000/api/trigger-etl \
  -H "Content-Type: application/json" \
  -d '{"load_date": "2024-06-01"}'

# Response
{
  "status": "SUCCESS",
  "timestamp": "2024-06-01T02:45:00",
  "load_date": "2024-06-01"
}
```

---

## Error Handling

### Automatic Retry

```
Task execution fails → Check retry policy
  ↓
Should retry? (max_attempts not reached)
  ├→ Yes: Wait delay_seconds, retry
  ├→ No: Task FAILED, mark dependency failures
  
Example: 3 retries with exponential backoff
  Attempt 1: Fails
  Wait 5s
  Attempt 2: Fails
  Wait 10s
  Attempt 3: Fails
  Result: FAILED (no more retries)
```

### Circuit Breaker

```
Normal: Success → Task completes
Failure: 3 failed attempts → Circuit OPEN
Blocked: No more attempts (fast failure)
Recovery: Wait 30s → Circuit RESET → Try again
```

### Rollback

```python
# On critical failure, trigger rollback
if orchestrator.status == TaskStatus.FAILED:
    await orchestrator.rollback()
    # Executes in reverse order:
    # - Fact Load (rollback)
    # - Dimension Load (rollback)
    # - Earlier stages (skip)
```

---

## Performance Tuning

### Task Parallelization

```python
# Tasks with same dependency level run in parallel
task_kpi = WorkflowTask(..., dependencies=[TaskDependency("FACTS")])
task_validate = WorkflowTask(..., dependencies=[TaskDependency("FACTS")])

# Both depend only on FACTS, so they run in parallel
# Reduces total execution time
```

### Timeout Configuration

```python
# Set realistic timeouts based on data volume
# Too short: Tasks timeout prematurely
# Too long: Slow to detect real hangs

# Recommended: P95 historical duration * 1.2

task = WorkflowTask(
    ...,
    timeout_seconds=600  # 10 minutes
)
```

### Batch Sizing

```python
# Adjust ingestion batch size for optimal performance
from ingestion.data_ingestor import IngestorConfig

config = IngestorConfig(
    batch_size=1000  # Records per batch
    # Larger = fewer queries, more memory
    # Smaller = more queries, less memory
)
```

---

## File Locations

```
Orchestration Code:
  backend/python/workflow_orchestrator.py       (Core engine)
  backend/python/etl_workflow_adapter.py        (ETL implementation)

Documentation:
  backend/documentation/architecture/WORKFLOW_ORCHESTRATION_GUIDE.md
  backend/documentation/architecture/PIPELINE_TRIGGERS_GUIDE.md
  backend/documentation/architecture/ORCHESTRATION_IMPLEMENTATION_GUIDE.md
  backend/documentation/architecture/QUICK_REFERENCE.md (this file)

Execution Reports:
  backend/python/logs/orchestration_report_*.json

SQL Jobs:
  backend/etl/sql_jobs/01_create_etl_master_job.sql
  backend/etl/sql_jobs/02_create_incremental_load_jobs.sql
  backend/etl/sql_jobs/03_create_monitoring_alerting_jobs.sql
```

---

## Common Tasks

### Check if ETL Succeeded

```bash
# Get latest execution status
jq '.status' logs/orchestration_report_ETL_WORKFLOW_001_*.json | tail -1

# Get failed tasks
jq '.task_results[] | select(.status=="FAILED")' logs/orchestration_report_*.json
```

### Troubleshoot Failed Task

```bash
# Find task error
jq '.task_results.TASK_INGEST' logs/orchestration_report_*.json

# Check how many retries happened
jq '.task_results.TASK_INGEST.attempt' logs/orchestration_report_*.json

# View error message
jq '.task_results.TASK_INGEST.error' logs/orchestration_report_*.json
```

### Monitor Real-Time Execution

```bash
# Tail logs
tail -f logs/orchestration_*.log

# Filter for errors
tail -f logs/orchestration_*.log | grep -i error

# Filter for specific task
tail -f logs/orchestration_*.log | grep "TASK_INGEST"
```

### Manually Trigger ETL

```bash
# Today
python backend/python/etl_workflow_adapter.py

# Specific date
python backend/python/etl_workflow_adapter.py --date 2024-06-01

# Remote server
python backend/python/etl_workflow_adapter.py --server prod-sql.company.com
```

---

## Deployment Checklist

- [ ] Copy Python files to production server
- [ ] Create virtual environment and install dependencies
- [ ] Configure database credentials (environment variables)
- [ ] Create SQL Server Agent jobs and schedules
- [ ] Set up logging directory with rotation
- [ ] Create monitoring views in database
- [ ] Deploy Flask API for webhooks (optional)
- [ ] Configure email alerts for failures
- [ ] Test with sample data
- [ ] Validate rollback procedures
- [ ] Create runbooks for common issues
- [ ] Set up monitoring dashboard

---

## Key Metrics to Track

```sql
-- Daily ETL summary
SELECT
    CAST(start_time AS DATE) as date,
    COUNT(*) as runs,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as success_rate,
    AVG(DATEDIFF(SECOND, start_time, end_time)) as avg_duration_s
FROM orchestration_workflows
GROUP BY CAST(start_time AS DATE)

-- Most frequently failing tasks
SELECT TOP 10
    task_name,
    COUNT(*) as failures,
    AVG(attempt) as avg_retries
FROM orchestration_tasks
WHERE status = 'FAILED'
GROUP BY task_name
ORDER BY failures DESC
```

---

## Resources

- **Comprehensive Guide**: See [WORKFLOW_ORCHESTRATION_GUIDE.md](WORKFLOW_ORCHESTRATION_GUIDE.md)
- **Triggers Reference**: See [PIPELINE_TRIGGERS_GUIDE.md](PIPELINE_TRIGGERS_GUIDE.md)
- **Implementation Steps**: See [ORCHESTRATION_IMPLEMENTATION_GUIDE.md](ORCHESTRATION_IMPLEMENTATION_GUIDE.md)
- **Code Examples**: See `workflow_orchestrator.py` and `etl_workflow_adapter.py`
- **SQL Jobs**: See `backend/etl/sql_jobs/` directory

---

## Support

For issues or questions:
1. Check logs: `tail -f logs/orchestration_*.log`
2. Review execution report: `cat logs/orchestration_report_*.json`
3. Check task status: Query `orchestration_tasks` table
4. Review documentation for configuration options
5. Enable debug mode for detailed logs

---

**Last Updated**: June 2024
**Version**: 1.0
**Status**: Production Ready
