# Pipeline Triggers & Event-Based Orchestration Guide

## Overview

This guide describes how to set up various triggers for the ETL workflow orchestration system, including scheduled triggers, event-based triggers, dependency triggers, and webhook-based triggers.

---

## Trigger Types

```
┌─────────────────────────────────────────────────────┐
│            Pipeline Triggers                        │
├─────────────────────────────────────────────────────┤
│                                                     │
├─ Scheduled Triggers                                │
│  ├─ Time-based (daily, weekly, custom)            │
│  ├─ Cron expressions                              │
│  └─ SQL Server Agent schedules                    │
│                                                     │
├─ Event-Based Triggers                              │
│  ├─ Data arrival                                  │
│  ├─ File drop                                     │
│  ├─ External system alerts                        │
│  └─ Message queue events                          │
│                                                     │
├─ Dependency Triggers                               │
│  ├─ Parent job completion                         │
│  ├─ Upstream system success                       │
│  ├─ Data quality checks                           │
│  └─ Resource availability                         │
│                                                     │
├─ Webhook Triggers                                  │
│  ├─ REST API endpoints                            │
│  ├─ Payload validation                            │
│  ├─ Custom headers/authentication                 │
│  └─ Response handling                             │
│                                                     │
└─ Manual Triggers                                   │
   └─ On-demand execution                           │
```

---

## 1. Scheduled Triggers

### 1.1 SQL Server Agent Scheduler

Configure SQL Server Agent to trigger ETL at specific times.

#### Daily Schedule (Nightly Pipeline)

```sql
-- Create schedule: Daily at 12:45 AM
EXEC sp_add_schedule
    @schedule_name = 'ETL_Nightly_Schedule',
    @freq_type = 4,              -- Daily
    @freq_interval = 1,           -- Every day
    @active_start_time = 004500,  -- 00:45:00 (HHmmss)
    @active_end_time = 235959;

-- Create job
EXEC sp_add_job
    @job_name = 'ETL_Daily_Orchestration',
    @enabled = 1,
    @description = 'Daily ETL workflow orchestration';

-- Add schedule to job
EXEC sp_attach_schedule
    @job_name = 'ETL_Daily_Orchestration',
    @schedule_name = 'ETL_Nightly_Schedule';

-- Add job step
EXEC sp_add_jobstep
    @job_name = 'ETL_Daily_Orchestration',
    @step_name = 'Execute_Orchestration',
    @command = 'C:\Python39\python.exe C:\backend\python\etl_workflow_adapter.py',
    @subsystem = 'CmdExec',
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
```

#### Weekly Schedule (Sunday Maintenance)

```sql
-- Create weekly schedule
EXEC sp_add_schedule
    @schedule_name = 'ETL_Weekly_Maintenance',
    @freq_type = 8,           -- Weekly
    @freq_interval = 1,       -- Sunday (1=Sunday, 2=Monday, etc.)
    @active_start_time = 040000;  -- 4:00 AM

-- Use in job
EXEC sp_attach_schedule
    @job_name = 'ETL_Weekly_Cleanup',
    @schedule_name = 'ETL_Weekly_Maintenance';
```

#### Custom Schedule (Multiple Times Daily)

```sql
-- Create schedule: Every 6 hours
EXEC sp_add_schedule
    @schedule_name = 'ETL_Every_6_Hours',
    @freq_type = 4,           -- Daily
    @freq_subday_type = 8,    -- Hour
    @freq_subday_interval = 6;

-- Create schedule: Noon, 6 PM, Midnight
EXEC sp_add_schedule
    @schedule_name = 'ETL_Custom_Times',
    @freq_type = 4,
    @freq_subday_type = 1;    -- Minute frequency

-- Create 3 separate jobs for different times
-- 12:00 PM
EXEC sp_add_schedule @schedule_name = 'ETL_Noon', @freq_type = 4, @active_start_time = 120000;
-- 6:00 PM
EXEC sp_add_schedule @schedule_name = 'ETL_Evening', @freq_type = 4, @active_start_time = 180000;
-- 12:00 AM
EXEC sp_add_schedule @schedule_name = 'ETL_Midnight', @freq_type = 4, @active_start_time = 000000;
```

### 1.2 Windows Task Scheduler

Alternative to SQL Server Agent using Windows Task Scheduler.

```powershell
# Create scheduled task for daily ETL
$trigger = New-ScheduledTaskTrigger -Daily -At 12:45AM
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$action = New-ScheduledTaskAction -Execute "C:\Python39\python.exe" `
    -Argument "C:\backend\python\etl_workflow_adapter.py"
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable `
    -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName "ETL_Daily_Orchestration" `
    -Trigger $trigger -Principal $principal `
    -Action $action -Settings $settings -Force
```

### 1.3 Cron Expressions (Linux/Docker)

For containerized deployments:

```bash
# Daily at 12:45 AM
45 0 * * * /usr/bin/python3 /app/etl_workflow_adapter.py

# Every 6 hours
0 */6 * * * /usr/bin/python3 /app/etl_workflow_adapter.py

# Monday-Friday at 9 AM
0 9 * * 1-5 /usr/bin/python3 /app/etl_workflow_adapter.py

# First day of month at 1 AM
0 1 1 * * /usr/bin/python3 /app/etl_workflow_adapter.py
```

---

## 2. Event-Based Triggers

### 2.1 File Drop Trigger

Monitor folder for incoming data files and trigger ETL.

```python
"""
File monitoring trigger - watches for incoming data files
"""

import os
import time
import asyncio
from pathlib import Path
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class FileDropTrigger:
    """Monitor folder for file arrivals and trigger ETL."""
    
    def __init__(
        self,
        watch_folder: str,
        file_pattern: str = "*.csv",
        processed_folder: str = None
    ):
        self.watch_folder = Path(watch_folder)
        self.file_pattern = file_pattern
        self.processed_folder = Path(processed_folder) if processed_folder else self.watch_folder / "processed"
        self.processed_files = set()
        
        # Create folders
        self.watch_folder.mkdir(parents=True, exist_ok=True)
        self.processed_folder.mkdir(parents=True, exist_ok=True)
    
    async def check_for_files(self, callback: callable):
        """Continuously check for new files."""
        logger.info(f"Monitoring {self.watch_folder} for {self.file_pattern}")
        
        while True:
            try:
                # Find new files
                files = list(self.watch_folder.glob(self.file_pattern))
                
                for file in files:
                    if file.is_file() and str(file) not in self.processed_files:
                        logger.info(f"New file detected: {file.name}")
                        
                        # Call trigger callback
                        await callback(file)
                        
                        # Move to processed folder
                        processed_path = self.processed_folder / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{file.name}"
                        file.rename(processed_path)
                        
                        self.processed_files.add(str(file))
                        logger.info(f"File processed and archived: {processed_path}")
                
                # Check every 5 seconds
                await asyncio.sleep(5)
                
            except Exception as e:
                logger.error(f"Error monitoring files: {e}")
                await asyncio.sleep(10)
    
    async def trigger_on_file_drop(self, file_path: Path):
        """Execute ETL when file arrives."""
        from etl_workflow_adapter import ETLWorkflowAdapter
        
        logger.info(f"Triggering ETL for file: {file_path.name}")
        
        adapter = ETLWorkflowAdapter()
        success = await adapter.execute_workflow()
        
        if success:
            logger.info(f"ETL completed successfully for {file_path.name}")
        else:
            logger.error(f"ETL failed for {file_path.name}")

# Usage
async def main():
    trigger = FileDropTrigger(
        watch_folder="C:\\data\\incoming",
        file_pattern="erp_orders_*.csv"
    )
    
    await trigger.check_for_files(trigger.trigger_on_file_drop)

if __name__ == "__main__":
    asyncio.run(main())
```

### 2.2 Data Quality Trigger

Trigger ETL only if source data quality is acceptable.

```python
"""
Data quality-based trigger - check source data before ETL
"""

class DataQualityTrigger:
    """Check source data quality before triggering ETL."""
    
    def __init__(self, db_config):
        self.db_config = db_config
        self.db = init_db(db_config)
    
    def check_source_data_quality(self) -> bool:
        """Verify source data meets quality thresholds."""
        
        checks = {
            'record_count': self._check_record_count(),
            'null_percentage': self._check_null_percentage(),
            'duplicate_count': self._check_duplicates(),
            'data_freshness': self._check_freshness()
        }
        
        # All checks must pass
        return all(checks.values())
    
    def _check_record_count(self) -> bool:
        """Verify minimum record count."""
        # Query: SELECT COUNT(*) FROM source_table
        # Threshold: > 1000 records
        pass
    
    def _check_null_percentage(self) -> bool:
        """Verify null percentage is acceptable."""
        # Threshold: < 5% nulls in key columns
        pass
    
    def _check_duplicates(self) -> bool:
        """Verify duplicate count is low."""
        # Threshold: < 100 duplicates
        pass
    
    def _check_freshness(self) -> bool:
        """Verify data is recent."""
        # Threshold: Data updated within last 24 hours
        pass
    
    async def trigger_if_quality_ok(self):
        """Trigger ETL only if quality checks pass."""
        if self.check_source_data_quality():
            logger.info("Source data quality OK - triggering ETL")
            
            adapter = ETLWorkflowAdapter()
            return await adapter.execute_workflow()
        else:
            logger.warning("Source data quality issues - skipping ETL")
            return False

# Usage
async def main():
    trigger = DataQualityTrigger(DatabaseConfig())
    success = await trigger.trigger_if_quality_ok()

if __name__ == "__main__":
    asyncio.run(main())
```

### 2.3 Message Queue Trigger

Trigger ETL from message queue events (Azure Service Bus, RabbitMQ, etc.).

```python
"""
Message queue trigger - execute ETL on queue events
"""

from azure.servicebus import ServiceBusClient
import json

class MessageQueueTrigger:
    """Trigger ETL from Azure Service Bus messages."""
    
    def __init__(self, connection_string: str, queue_name: str):
        self.connection_string = connection_string
        self.queue_name = queue_name
        self.client = ServiceBusClient.from_connection_string(connection_string)
    
    async def listen_for_triggers(self):
        """Listen for trigger messages."""
        with self.client:
            receiver = self.client.get_queue_receiver(self.queue_name)
            
            async with receiver:
                async for message in receiver:
                    try:
                        payload = json.loads(str(message.body))
                        logger.info(f"Received trigger message: {payload}")
                        
                        # Extract trigger parameters
                        load_date = payload.get('load_date')
                        
                        # Execute ETL
                        from etl_workflow_adapter import ETLWorkflowAdapter
                        adapter = ETLWorkflowAdapter(load_date=load_date)
                        success = await adapter.execute_workflow()
                        
                        # Complete message
                        if success:
                            await receiver.complete_message(message)
                            logger.info("Message completed")
                        else:
                            await receiver.abandon_message(message)
                            logger.error("Message abandoned - ETL failed")
                    
                    except Exception as e:
                        logger.error(f"Error processing message: {e}")
                        await receiver.abandon_message(message)

# Usage
async def main():
    trigger = MessageQueueTrigger(
        connection_string="Endpoint=sb://...;SharedAccessKeyName=...;SharedAccessKey=...",
        queue_name="etl-triggers"
    )
    
    await trigger.listen_for_triggers()

if __name__ == "__main__":
    asyncio.run(main())
```

---

## 3. Dependency Triggers

### 3.1 Parent Job Completion Trigger

Trigger when upstream job completes.

```sql
-- Parent job completes, trigger child ETL
CREATE JOB ETL_DependentOn_SourceJob AS
BEGIN
    -- Check if parent job succeeded
    DECLARE @ParentJobStatus INT
    
    SELECT @ParentJobStatus = last_run_outcome
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'Parent_Import_Job')
    ORDER BY run_date DESC, run_time DESC
    LIMIT 1
    
    IF @ParentJobStatus = 1  -- Success
    BEGIN
        -- Trigger ETL via stored procedure
        EXEC sp_start_job N'ETL_Daily_Orchestration'
    END
    ELSE
    BEGIN
        PRINT 'Parent job failed - skipping dependent ETL'
    END
END
```

### 3.2 Resource Availability Trigger

Trigger only when system resources are available.

```python
"""
Resource-based trigger - execute ETL when resources are available
"""

import psutil
import asyncio

class ResourceAvailabilityTrigger:
    """Check system resources before triggering ETL."""
    
    def __init__(
        self,
        min_cpu_available: float = 20.0,  # 20% CPU
        min_memory_available: float = 30.0,  # 30% memory
        min_disk_available_gb: float = 50.0  # 50GB disk
    ):
        self.min_cpu_available = min_cpu_available
        self.min_memory_available = min_memory_available
        self.min_disk_available_gb = min_disk_available_gb
    
    def check_resources(self) -> tuple[bool, str]:
        """Check system resources."""
        
        # CPU check
        cpu_percent = psutil.cpu_percent(interval=1)
        cpu_available = 100 - cpu_percent
        if cpu_available < self.min_cpu_available:
            return False, f"CPU utilization too high: {cpu_percent}%"
        
        # Memory check
        memory = psutil.virtual_memory()
        if memory.percent > (100 - self.min_memory_available):
            return False, f"Memory utilization too high: {memory.percent}%"
        
        # Disk check
        disk = psutil.disk_usage('/')
        disk_free_gb = disk.free / (1024 ** 3)
        if disk_free_gb < self.min_disk_available_gb:
            return False, f"Insufficient disk space: {disk_free_gb:.1f}GB available"
        
        return True, "Resources OK"
    
    async def trigger_when_resources_available(self, max_wait_minutes: int = 60):
        """Wait for resources and trigger ETL."""
        
        start_time = datetime.now()
        
        while True:
            ok, message = self.check_resources()
            
            if ok:
                logger.info("Resources available - triggering ETL")
                
                from etl_workflow_adapter import ETLWorkflowAdapter
                adapter = ETLWorkflowAdapter()
                return await adapter.execute_workflow()
            
            # Check if timeout exceeded
            elapsed_minutes = (datetime.now() - start_time).total_seconds() / 60
            if elapsed_minutes > max_wait_minutes:
                logger.error(f"Timeout waiting for resources after {max_wait_minutes} minutes")
                return False
            
            logger.warning(f"Resources not available: {message}. Waiting 5 minutes...")
            await asyncio.sleep(300)  # 5 minutes

# Usage
async def main():
    trigger = ResourceAvailabilityTrigger(
        min_cpu_available=25.0,
        min_memory_available=40.0
    )
    
    success = await trigger.trigger_when_resources_available(max_wait_minutes=120)

if __name__ == "__main__":
    asyncio.run(main())
```

---

## 4. Webhook Triggers

### 4.1 Flask REST API Endpoint

```python
"""
REST API webhook for triggering ETL
"""

from flask import Flask, request, jsonify
from datetime import datetime
import asyncio
import logging

app = Flask(__name__)
logger = logging.getLogger(__name__)

@app.route('/api/trigger-etl', methods=['POST'])
def trigger_etl():
    """
    Webhook endpoint to trigger ETL workflow.
    
    Request JSON:
    {
        "load_date": "2024-06-01",
        "continue_on_error": false,
        "priority": "normal"
    }
    """
    try:
        data = request.get_json()
        
        # Validate request
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        load_date = data.get('load_date')
        continue_on_error = data.get('continue_on_error', False)
        
        # Parse date
        if load_date:
            try:
                from datetime import datetime
                load_date = datetime.strptime(load_date, '%Y-%m-%d').date()
            except ValueError:
                return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
        
        # Trigger ETL
        from etl_workflow_adapter import ETLWorkflowAdapter
        
        adapter = ETLWorkflowAdapter(load_date=load_date)
        
        # Run async in thread pool
        loop = asyncio.new_event_loop()
        success = loop.run_until_complete(
            adapter.execute_workflow(continue_on_error=continue_on_error)
        )
        
        return jsonify({
            'status': 'SUCCESS' if success else 'FAILED',
            'timestamp': datetime.now().isoformat(),
            'load_date': str(load_date) if load_date else 'today'
        }), 200 if success else 500
    
    except Exception as e:
        logger.error(f"Error triggering ETL: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/trigger-etl/status', methods=['GET'])
def get_etl_status():
    """Get current ETL execution status."""
    # Query database for latest execution
    # Return status, duration, success rate, etc.
    pass

@app.route('/api/trigger-etl/history', methods=['GET'])
def get_etl_history():
    """Get ETL execution history."""
    limit = request.args.get('limit', 10, type=int)
    # Query database for recent executions
    # Return list of executions with status, duration, etc.
    pass

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
```

### 4.2 Webhook Usage Examples

```bash
# Trigger ETL for today
curl -X POST http://localhost:5000/api/trigger-etl \
  -H "Content-Type: application/json" \
  -d '{"continue_on_error": false}'

# Trigger for specific date
curl -X POST http://localhost:5000/api/trigger-etl \
  -H "Content-Type: application/json" \
  -d '{"load_date": "2024-06-01"}'

# Get ETL status
curl http://localhost:5000/api/trigger-etl/status

# Get ETL history
curl "http://localhost:5000/api/trigger-etl/history?limit=20"
```

### 4.3 Azure Logic Apps Integration

Create Logic App to trigger ETL via webhook:

```json
{
  "definition": {
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "actions": {
      "HTTP_Trigger_ETL": {
        "inputs": {
          "body": {
            "load_date": "@{utcNow('yyyy-MM-dd')}",
            "continue_on_error": false
          },
          "headers": {
            "Content-Type": "application/json"
          },
          "method": "POST",
          "uri": "http://etl-server:5000/api/trigger-etl"
        },
        "runAfter": {},
        "type": "Http"
      }
    },
    "triggers": {
      "Recurrence": {
        "recurrence": {
          "frequency": "Day",
          "interval": 1,
          "startTime": "2024-01-01T00:45:00Z"
        },
        "type": "Recurrence"
      }
    }
  }
}
```

---

## 5. Multi-Trigger Setup

### Combined Trigger Logic

```python
"""
Orchestrate multiple triggers with priority
"""

class MultiTriggerOrchestrator:
    """Manage multiple trigger types."""
    
    def __init__(self):
        self.scheduled_trigger = None
        self.event_trigger = None
        self.dependency_trigger = None
        self.webhook_trigger = None
        self.last_execution = None
        self.min_interval_hours = 6  # Prevent too frequent executions
    
    async def run_all_triggers(self):
        """Run all triggers concurrently."""
        
        tasks = [
            self._run_scheduled_trigger(),
            self._run_event_trigger(),
            self._run_dependency_trigger(),
        ]
        
        await asyncio.gather(*tasks)
    
    async def _run_scheduled_trigger(self):
        """Execute scheduled trigger."""
        # Run at scheduled times
        pass
    
    async def _run_event_trigger(self):
        """Monitor and execute event trigger."""
        # Monitor file drops, message queues
        pass
    
    async def _run_dependency_trigger(self):
        """Check dependencies and trigger."""
        # Check upstream job completion
        pass
    
    async def trigger_etl(self) -> bool:
        """Unified trigger execution with throttling."""
        
        # Check minimum interval
        if self.last_execution:
            elapsed_hours = (datetime.now() - self.last_execution).total_seconds() / 3600
            if elapsed_hours < self.min_interval_hours:
                logger.info(f"Throttling: ETL executed {elapsed_hours:.1f}h ago. Min interval: {self.min_interval_hours}h")
                return False
        
        # Execute ETL
        from etl_workflow_adapter import ETLWorkflowAdapter
        adapter = ETLWorkflowAdapter()
        success = await adapter.execute_workflow()
        
        if success:
            self.last_execution = datetime.now()
        
        return success
```

---

## Best Practices

1. **Schedule Planning**
   - Run ETL during off-peak hours
   - Leave buffer between runs (6-hour minimum)
   - Consider data source refresh cycles

2. **Error Handling**
   - Implement retry logic in triggers
   - Alert on trigger failures
   - Log all trigger invocations

3. **Monitoring**
   - Track trigger execution frequency
   - Monitor trigger latency
   - Alert on missed triggers

4. **Security**
   - Validate webhook requests (API keys, IP whitelisting)
   - Encrypt trigger payloads
   - Audit trigger logs

5. **Testing**
   - Test each trigger type individually
   - Test combined triggers
   - Verify error scenarios

---

## Summary

Trigger Types:

| Type | Use Case | Latency | Reliability |
|------|----------|---------|-------------|
| **Scheduled** | Predictable, recurring | Low | High |
| **Event-based** | Real-time, responsive | Very Low | Medium |
| **Dependency** | Workflow dependent | Low-Medium | High |
| **Webhook** | External system driven | Low | Medium |
| **Manual** | Ad-hoc, testing | N/A | High |

Select the appropriate trigger strategy based on your requirements and operational characteristics.
