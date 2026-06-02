# Workflow Orchestration & Pipeline Triggers Implementation Guide

## Overview

This document describes the comprehensive workflow orchestration system implemented for the Enterprise KPI ETL platform, including advanced error handling, retry policies, dependency management, monitoring, and alerting.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│             Workflow Orchestrator                            │
│  (Advanced orchestration engine with task dependencies)     │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
┌───────▼────────┐  ┌────────▼────────┐
│  Retry Handler │  │ Task Executor   │
│  - Exponential │  │ - Async exec    │
│  - Linear      │  │ - Timeouts      │
│  - Immediate   │  │ - Error capture │
│  - Circuit     │  │ - Rollback      │
└────────────────┘  └─────────────────┘
        │                     │
┌───────┴─────────────────────┴────────┐
│                                      │
│      ETL Workflow Adapter            │
│  (Bridges orchestrator with ETL)     │
│                                      │
│  - Data Ingestion                    │
│  - Staging Transformation            │
│  - Dimension Load                    │
│  - Fact Load                         │
│  - KPI Calculation                   │
│  - Validation & Reconciliation       │
└──────────────────┬───────────────────┘
                   │
    ┌──────────────┼──────────────┐
    │              │              │
┌───▼───┐  ┌──────▼────┐  ┌─────▼──┐
│Ingestion│ │Validation │ │Recon   │
│        │ │           │ │ciliate │
└────────┘ └───────────┘ └────────┘
```

---

## Key Components

### 1. **WorkflowOrchestrator**

Core orchestration engine that manages task execution, dependencies, and error handling.

#### Features:
- **Topological Sorting**: Automatically determines execution order based on dependencies
- **Dependency Resolution**: Manages task dependencies and failure propagation
- **Error Handling**: Comprehensive try-catch and error logging
- **Retry Logic**: Multiple retry strategies with configurable backoff
- **Execution Tracking**: Records task status, duration, and metadata
- **Alerting**: Generates alerts for failures and anomalies

#### Key Methods:

```python
# Create orchestrator
orchestrator = WorkflowOrchestrator(
    workflow_id="ETL_WORKFLOW_001",
    workflow_name="Enterprise KPI ETL"
)

# Add tasks with dependencies
task = WorkflowTask(
    task_id="TASK_001",
    task_name="Load Data",
    execute_func=load_data_function,
    retry_policy=RetryPolicy(max_attempts=3),
    dependencies=[TaskDependency("TASK_000", required=True)]
)
orchestrator.add_task(task)

# Execute workflow
success = await orchestrator.execute(continue_on_error=False)

# Get execution report
report = orchestrator.get_execution_report()
orchestrator.save_report()
```

### 2. **WorkflowTask**

Encapsulates a single workflow task with execution logic, retry policy, and rollback capability.

#### Configuration:

```python
task = WorkflowTask(
    task_id="TASK_INGEST",
    task_name="Data Ingestion",
    execute_func=lambda ctx: ingest_data(ctx),
    retry_policy=RetryPolicy(
        strategy=RetryStrategy.EXPONENTIAL_BACKOFF,
        max_attempts=3,
        initial_delay_seconds=5,
        max_delay_seconds=300,
        backoff_multiplier=2.0,
        jitter=True
    ),
    timeout_seconds=600,
    dependencies=[TaskDependency("TASK_INIT", required=True)],
    rollback_func=lambda ctx: rollback_ingestion(ctx),
    on_failure=lambda ctx: handle_ingestion_failure(ctx)
)
```

### 3. **RetryPolicy**

Defines how tasks should retry on failure.

#### Retry Strategies:

| Strategy | Description | Use Case |
|----------|-------------|----------|
| `EXPONENTIAL_BACKOFF` | 5s, 10s, 20s, 40s... | Network failures, temp unavailability |
| `LINEAR_BACKOFF` | 5s, 10s, 15s, 20s... | Resource contention |
| `IMMEDIATE` | No delay | Circuit breaker, quick retries |
| `CIRCUIT_BREAKER` | Blocks after 3 failures | Cascading failures, degradation |

#### Configuration Examples:

```python
# Exponential backoff (default)
RetryPolicy(
    strategy=RetryStrategy.EXPONENTIAL_BACKOFF,
    max_attempts=3,
    initial_delay_seconds=5,
    backoff_multiplier=2.0,
    jitter=True
)

# Linear backoff
RetryPolicy(
    strategy=RetryStrategy.LINEAR_BACKOFF,
    max_attempts=2,
    initial_delay_seconds=10
)

# Circuit breaker (fail fast)
RetryPolicy(
    strategy=RetryStrategy.CIRCUIT_BREAKER,
    max_attempts=1
)

# No retry
RetryPolicy(
    strategy=RetryStrategy.IMMEDIATE,
    max_attempts=1
)
```

### 4. **TaskDependency**

Defines how tasks depend on each other.

```python
# Required dependency - task skipped if dependency fails
TaskDependency("TASK_PARENT", required=True)

# Optional dependency - task runs even if dependency fails
TaskDependency("TASK_PARENT", required=False)
```

### 5. **WorkflowHealthMonitor**

Monitors workflow health and generates metrics.

```python
monitor = WorkflowHealthMonitor()

# Get health metrics
metrics = monitor.check_workflow_health(orchestrator)
# {
#     'total_tasks': 10,
#     'successful_tasks': 9,
#     'failed_tasks': 1,
#     'success_rate': 90.0,
#     'total_duration': 450.5,
#     'alerts_count': 2
# }

# Generate health report
report = monitor.generate_health_report(orchestrator)
print(report)
```

---

## ETL Workflow Tasks

The `ETLWorkflowAdapter` implements a complete ETL workflow with 10 stages:

### Task Execution Flow

```
1. Initialize DB (5-10s)
   ↓
2. Data Ingestion (5-10 min)
   ├─ ERP Orders
   ├─ Salesforce Customers
   └─ Inventory
   ↓
3. Staging Transformation (15-20 min)
   ↓
4. Dimension Load (10-15 min) ─────┐
   ↓                                │
5. Fact Load (15-20 min)           │
   ├─ Depends on: Dims             │
   ↓                                │
6. KPI Calculation (10-15 min)     ├─ Parallel
   ├─ Depends on: Facts            │
   ↓                                │
7. Validation (5-10 min)           │
   ├─ Depends on: Facts            │
   ↓                                │
8. Reconciliation (5-10 min)       │
   ├─ Depends on: KPIs + Validation─┤
   ↓
9. Staging Cleanup (2-3 min)
   ├─ Depends on: Reconciliation (optional)
   ↓
10. Health Check (2-3 min)
    ├─ Depends on: Cleanup (optional)
    └─ Final verification

Total Time: 70-120 minutes
```

### Task Configuration

| Task | Dependencies | Retry Strategy | Max Attempts | Timeout |
|------|--------------|-----------------|---|---------|
| Init DB | None | Exponential | 3 | 30s |
| Ingestion | Init DB | Exponential | 3 | 10 min |
| Staging | Ingestion | Linear | 2 | 15 min |
| Dimensions | Staging | Exponential | 2 | 10 min |
| Facts | Dimensions | Exponential | 2 | 15 min |
| KPIs | Facts | Exponential | 2 | 10 min |
| Validation | Facts | Immediate | 2 | 5 min |
| Reconciliation | KPIs + Validation | Linear | 2 | 5 min |
| Cleanup | Reconciliation (opt) | Immediate | 1 | 5 min |
| Health Check | Cleanup (opt) | Immediate | 1 | 5 min |

---

## Usage Examples

### Basic Execution

```python
import asyncio
from etl_workflow_adapter import ETLWorkflowAdapter
from datetime import date

async def main():
    # Create adapter
    adapter = ETLWorkflowAdapter(
        load_date=date(2024, 6, 1),
        workflow_id="ETL_WORKFLOW_JUNE_2024"
    )
    
    # Execute workflow
    success = await adapter.execute_workflow(continue_on_error=False)
    
    return success

# Run workflow
if __name__ == "__main__":
    asyncio.run(main())
```

### With Custom Error Handling

```python
async def main():
    adapter = ETLWorkflowAdapter()
    orchestrator = adapter.create_workflow()
    
    # Execute with error continuation
    success = await orchestrator.execute(continue_on_error=True)
    
    if not success:
        # Get execution report for analysis
        report = orchestrator.get_execution_report()
        
        # Print failed tasks
        for task_id, result in report['task_results'].items():
            if result['status'] == 'FAILED':
                print(f"Task {task_id}: {result['error']}")
        
        # Optionally rollback
        await orchestrator.rollback()
```

### Command-Line Usage

```bash
# Execute with defaults (today's date, localhost)
python etl_workflow_adapter.py

# Custom date and server
python etl_workflow_adapter.py \
    --date 2024-06-01 \
    --server db.mycompany.com \
    --database Enterprise_KPI_DW

# Continue on errors
python etl_workflow_adapter.py --continue-on-error
```

---

## Error Handling & Recovery

### Automatic Retry

All tasks automatically retry on failure with configured strategy:

```
Attempt 1: Fails after 5s
Attempt 2: Retry after 5s delay (5s - 10s backoff = 5s)
Attempt 3: Retry after 10s delay (5s * 2 = 10s)
Failed: After 3 attempts, task fails permanently
```

### Circuit Breaker

Prevents cascading failures by opening circuit after repeated failures:

```
Success  ✓
Success  ✓
Failure  ✗ (1/3 failures)
Failure  ✗ (2/3 failures)
Failure  ✗ (3/3 failures) → CIRCUIT OPEN
Reject   ✗ (no retry, circuit open)
Reject   ✗ (no retry, circuit open)
[30s timeout]
Attempt  ✓ (circuit reset, try again)
```

### Rollback Strategy

When a critical task fails, rollback can be triggered:

```python
# Automatic rollback on dimension/fact load failure
if not success:
    await orchestrator.rollback()  # Restores previous data
```

Rollback executes in reverse order:
```
Health Check (skip - not critical)
Cleanup (skip)
Reconciliation (skip)
Validation (skip)
KPIs (skip)
Facts (rollback)    ← Restore fact data
Dimensions (rollback) ← Restore dimension data
Staging (skip)
Ingestion (skip)
```

---

## Monitoring & Alerting

### Execution Alerts

Alerts are generated for:

| Event | Severity | Example |
|-------|----------|---------|
| Task failure | ERROR | "Task 'Data Ingestion' failed: Connection timeout" |
| Dependency failure | ERROR | "Task skipped due to failed dependencies" |
| Validation failure | ERROR | "Validation failed: Score 92.1% < 95% threshold" |
| Circuit open | WARNING | "Circuit breaker opened due to repeated failures" |
| Retry attempt | WARNING | "Retrying task in 5.2s (Attempt 2/3)" |

### Health Metrics

```python
metrics = monitor.check_workflow_health(orchestrator)
# {
#     'total_tasks': 10,
#     'successful_tasks': 9,
#     'failed_tasks': 1,
#     'skipped_tasks': 0,
#     'success_rate': 90.0,
#     'total_duration': 4567.8,
#     'alerts_count': 3,
#     'critical_alerts': 1
# }
```

### Execution Reports

Detailed JSON report saved to `logs/orchestration_report_*.json`:

```json
{
  "workflow_id": "ETL_WORKFLOW_001",
  "workflow_name": "Enterprise KPI ETL - 2024-06-01",
  "status": "FAILED",
  "start_time": "2024-06-01T12:45:00",
  "end_time": "2024-06-01T14:30:15",
  "duration_seconds": 6615,
  "execution_order": ["TASK_INIT_DB", "TASK_INGEST", ...],
  "task_results": {
    "TASK_INGEST": {
      "task_id": "TASK_INGEST",
      "task_name": "Data Ingestion",
      "status": "FAILED",
      "duration_seconds": 125.5,
      "attempt": 3,
      "error": "Connection timeout after 3 retries",
      "error_type": "ConnectionError",
      "metadata": {
        "stage": "Data Ingestion",
        "total_records_ingested": 0
      }
    }
  },
  "alerts": [
    {
      "severity": "ERROR",
      "message": "Task 'Data Ingestion' failed: Connection timeout",
      "task_id": "TASK_INGEST",
      "metadata": {
        "error_type": "ConnectionError",
        "attempts": 3
      }
    }
  ]
}
```

---

## SQL Server Agent Integration

### Trigger Configuration

Create SQL Server Agent job to trigger orchestration:

```sql
-- Create job
EXEC sp_add_job
    @job_name = 'ETL_Workflow_Orchestration',
    @enabled = 1,
    @schedule_name = 'ETL_Nightly_Schedule'

-- Add step
EXEC sp_add_jobstep
    @job_name = 'ETL_Workflow_Orchestration',
    @step_name = 'Execute_Python_Orchestrator',
    @command = 'C:\Python\python.exe C:\backend\etl_workflow_adapter.py --date $(ESCAPE_NONE(DBDATE)) --continue-on-error',
    @subsystem = 'CmdExec'

-- Schedule: 12:45 AM daily
EXEC sp_add_schedule
    @schedule_name = 'ETL_Nightly_Schedule',
    @freq_type = 4,        -- Daily
    @active_start_time = 004500  -- 00:45:00
```

### Pipeline Triggers

#### Event-Based Triggers
```python
# Trigger on data available
if source_data_available():
    orchestrator.execute()

# Trigger on scheduled time
if datetime.now().hour == 1 and datetime.now().minute == 0:
    orchestrator.execute()

# Trigger on dependency completion
on_parent_job_complete:
    orchestrator.execute()
```

#### Webhook Triggers (via Flask)
```python
from flask import Flask, request

app = Flask(__name__)

@app.route('/trigger-etl', methods=['POST'])
def trigger_etl():
    """Webhook to trigger ETL workflow."""
    data = request.json
    load_date = data.get('load_date')
    
    adapter = ETLWorkflowAdapter(load_date=load_date)
    asyncio.run(adapter.execute_workflow())
    
    return {'status': 'ETL triggered'}
```

---

## Performance Tuning

### Task Optimization

1. **Parallel Execution**:
   - KPI calculation and validation run in parallel (both depend on facts)
   - Reduces total execution time

2. **Timeout Configuration**:
   - Set realistic timeouts (factors in data volume)
   - Too short: Tasks timeout prematurely
   - Too long: Slow to detect real hangs

3. **Retry Backoff**:
   - Exponential backoff: Good for transient failures
   - Linear backoff: Better for resource-constrained scenarios
   - Jitter: Prevents thundering herd

4. **Batch Sizing**:
   - Adjust batch size in ingestion based on memory
   - Larger batches = fewer queries but more memory
   - Smaller batches = more queries but lower memory

### Monitoring Recommendations

```sql
-- Monitor ETL job execution
SELECT TOP 20
    workflow_id,
    workflow_name,
    status,
    start_time,
    duration_seconds,
    success_rate,
    alerts_count
FROM vw_etl_workflow_executions
ORDER BY start_time DESC

-- Alert on failures
CREATE ALERT 'ETL_Workflow_Failed'
WHERE orchestration_status = 'FAILED'
ACTION send_email_to_dba_team
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Tasks timeout | Slow source/database | Increase timeout or optimize query |
| Retries exhausted | Persistent error | Check error logs, fix root cause |
| Circular dependency | Task configuration | Review task dependencies graph |
| Memory spike | Large batch size | Reduce batch size in ingestion |
| Data validation fails | Quality issues | Review validation rules, check source |

### Debug Mode

```python
# Enable verbose logging
logger.setLevel(logging.DEBUG)

# Run with debug output
python etl_workflow_adapter.py --debug

# Check orchestration logs
tail -f logs/orchestration_*.log
```

---

## Best Practices

1. **Dependency Management**
   - Keep dependencies shallow (avoid deep chains)
   - Use required=False for cleanup tasks
   - Test dependency graph for cycles

2. **Error Handling**
   - Always define failure handlers for critical tasks
   - Log meaningful error messages
   - Implement alerting for critical failures

3. **Retry Strategy**
   - Exponential backoff for external dependencies
   - Immediate for internal checks
   - Circuit breaker for cascading failures

4. **Testing**
   - Test workflow with sample data first
   - Verify rollback procedures
   - Test timeout scenarios

5. **Monitoring**
   - Track success rates per task
   - Monitor retry frequency
   - Alert on anomalies

---

## Files Created

| File | Purpose |
|------|---------|
| `workflow_orchestrator.py` | Core orchestration engine |
| `etl_workflow_adapter.py` | ETL-specific implementation |
| [This file] | Documentation & guide |

---

## Next Steps

1. **Integrate with existing infrastructure**:
   - Configure SQL Server Agent jobs to call adapter
   - Set up webhook triggers for event-based execution

2. **Customize retry policies**:
   - Analyze your ingestion patterns
   - Adjust timeouts based on historical data
   - Configure backoff multipliers

3. **Implement monitoring**:
   - Connect to monitoring platform (DataDog, New Relic, etc.)
   - Create dashboards for workflow health
   - Set up alerting thresholds

4. **Production deployment**:
   - Test end-to-end in staging
   - Validate rollback procedures
   - Document runbooks for common failures

---

## Summary

The workflow orchestration system provides:

✓ **Advanced Retry Logic**: Multiple strategies for different scenarios
✓ **Dependency Management**: Topological sorting and dependency tracking
✓ **Error Handling**: Comprehensive exception handling and recovery
✓ **Monitoring & Alerting**: Real-time health checks and alerts
✓ **Rollback Capability**: Undo failed operations
✓ **Execution Reporting**: Detailed JSON reports for analysis
✓ **Scalability**: Async execution for concurrent tasks
✓ **Flexibility**: Customizable policies per task

This creates a robust, production-grade ETL orchestration platform for the Enterprise KPI system.
