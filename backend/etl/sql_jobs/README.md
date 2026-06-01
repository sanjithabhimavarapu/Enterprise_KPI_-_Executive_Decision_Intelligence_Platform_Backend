# SQL Server Agent Jobs - Enterprise KPI ETL Platform

## Overview
This folder contains all SQL Server Agent job definitions for the Enterprise KPI Data Warehouse platform. These jobs automate the complete ETL pipeline with built-in error handling, retry logic, and monitoring.

---

## Files in This Directory

### 1. **01_create_etl_master_job.sql**
Master orchestration job that coordinates the entire ETL pipeline.

**Components:**
- Execute incremental ETL transformation
- Validate data quality  
- Refresh KPI metrics
- Comprehensive error handling and logging

**Schedule:** Daily at 2:00 AM
**Duration:** 60-120 minutes
**Retry Logic:** 3 attempts with 5-minute intervals

**Key Procedure:** `sp_etl_master_orchestration`
- Parameters:
  - `@ProcessDate` - Date to process
  - `@ProcessType` - 'INCREMENTAL' or 'FULL_REFRESH'
  - `@DebugMode` - Verbose logging (0/1)

---

### 2. **02_create_incremental_load_jobs.sql**
Individual jobs for incremental data loads from each source system.

**Jobs Created:**
1. `ETL_Incremental_ERP_Orders_Load` (1:30 AM)
   - Loads order changes from ERP system
   - Uses checkpoint-based delta load
   
2. `ETL_Incremental_Salesforce_Customers_Load` (1:00 AM)
   - Loads customer updates from Salesforce
   - Tracks modifications via `modified_date`
   
3. `ETL_Incremental_Inventory_Load` (12:45 AM)
   - Loads inventory level changes
   - Supports SCD Type 2 for historical tracking

**Common Features:**
- Checkpoint tracking per source/table
- Automatic record counting
- Status logging in `etl_logs`
- 3x retry logic with 5-minute intervals
- Staggered scheduling to avoid resource contention

---

### 3. **03_create_monitoring_alerting_jobs.sql**
Jobs for monitoring, validation, and proactive alerting.

**Jobs Created:**
1. `ETL_Health_Check_Monitor` (Every 30 minutes)
   - Monitors job execution status
   - Identifies failures in last 24 hours
   - Logs health metrics
   - Triggers alerts if multiple failures detected

2. `ETL_Data_Freshness_Validation` (3:00 AM daily)
   - Validates fact tables contain current data
   - Checks for data staleness
   - Alerts if data not updated
   - Runs after master orchestration completes

3. `ETL_Checkpoint_Maintenance` (4:00 AM Sundays)
   - Archives old checkpoints (>3 months)
   - Optimizes checkpoint table
   - Updates statistics on staging tables
   - Two-step process with index rebuild

---

### 4. **04_job_execution_monitoring.sql**
Views and stored procedures for monitoring and reporting.

**Views:**
- `vw_etl_job_summary` - Current status of all ETL jobs
- `vw_recent_job_failures` - Recent failures for troubleshooting

**Procedures:**
- `sp_get_etl_job_dashboard` - 7-day performance metrics
- `sp_get_incremental_checkpoint_status` - Checkpoint health
- `sp_validate_etl_job_schedules` - Schedule validation
- `sp_list_all_etl_jobs` - Complete job inventory

---

## Installation Instructions

### Step 1: Prerequisites
Ensure these tables exist in your `Enterprise_KPI_DW` database:

```sql
-- Required tables (should exist from schema setup)
- etl_logs
- etl_incremental_checkpoints
- etl_alerts (create if doesn't exist)
- etl_checkpoint_archive
- stg_raw_erp_orders
- stg_raw_salesforce_customers
- stg_raw_inventory
- fact_orders
- dim_customer
```

### Step 2: Execute Installation Scripts in Order

```powershell
# PowerShell example
$sqlserver = "YourServerName"
$database = "Enterprise_KPI_DW"

# Execute each script in sequence
sqlcmd -S $sqlserver -d msdb -i "01_create_etl_master_job.sql"
sqlcmd -S $sqlserver -d msdb -i "02_create_incremental_load_jobs.sql"
sqlcmd -S $sqlserver -d msdb -i "03_create_monitoring_alerting_jobs.sql"
sqlcmd -S $sqlserver -d $database -i "04_job_execution_monitoring.sql"
```

### Step 3: Verify Installation

```sql
-- Check all jobs created
EXEC sp_list_all_etl_jobs;

-- Validate schedules
EXEC sp_validate_etl_job_schedules;

-- View complete schedule
SELECT * FROM vw_etl_job_summary;
```

### Step 4: Enable SQL Server Agent Service

```powershell
# Start SQL Server Agent (run as Administrator)
net start SQLSERVERAGENT
```

---

## Daily Execution Schedule

```
12:45 AM ─ Inventory Load (5-10 min)
  │
  ├─ 1:00 AM ─ Salesforce Load (5-10 min) [Parallel]
  │
  └─ 1:30 AM ─ ERP Orders Load (10-15 min) [Parallel]
     │
     └─ 2:00 AM ─ Master Orchestration (60-120 min)
        │
        ├─ Transform Staging
        ├─ Load Dimensions
        ├─ Load Facts
        └─ Refresh KPIs
           │
           └─ 3:00 AM ─ Freshness Validation (5 min)
              │
              └─ 3:30 AM ─ Ready for Reporting

Continuous:
├─ Every 30 min ─ Health Check Monitor
└─ Every Sun 4:00 AM ─ Maintenance
```

---

## Checkpoint-Based Incremental Loading

### How It Works

1. **First Run:** Load entire dataset, record timestamp
2. **Subsequent Runs:** Load only records modified since last checkpoint
3. **Advantage:** Dramatically reduces data transfer and processing time

### Checkpoint Table Structure

```sql
etl_incremental_checkpoints:
├── source_system (ERP, SALESFORCE, INVENTORY)
├── table_name (Orders, Customers, Stock)
├── last_load_time (DATETIME2) ← Key field
├── record_count (INT)
├── last_status (VARCHAR) - SUCCESS/FAILED
└── last_error_message (VARCHAR)
```

### Initialize Checkpoints

```sql
-- Set initial checkpoint for each source (run once)
INSERT INTO etl_incremental_checkpoints
VALUES 
    ('ERP', 'Orders', DATEADD(DAY, -30, CAST(GETDATE() AS DATE)), 0, 'PENDING', NULL),
    ('SALESFORCE', 'Customers', DATEADD(DAY, -30, CAST(GETDATE() AS DATE)), 0, 'PENDING', NULL),
    ('INVENTORY', 'Stock', DATEADD(DAY, -30, CAST(GETDATE() AS DATE)), 0, 'PENDING', NULL);
```

### Reset Checkpoint (Force Full Refresh)

```sql
-- Reset checkpoint to trigger full load
UPDATE etl_incremental_checkpoints
SET last_load_time = DATEADD(DAY, -365, CAST(GETDATE() AS DATE))
WHERE source_system = 'ERP' AND table_name = 'Orders';

-- Then execute the load job
```

---

## Error Handling & Retry Logic

### Automatic Retry Pattern
```
Attempt 1 ─ Fails
  ↓
Wait 5 min
  ↓
Attempt 2 ─ Fails
  ↓
Wait 5 min
  ↓
Attempt 3 ─ Fails
  ↓
Job Fails + Alert Sent
```

### Retry Configuration (Per Job)

```sql
-- Modify retry attempts (example: 5 retries instead of 3)
EXEC sp_update_jobstep
    @job_name = 'ETL_Incremental_ERP_Orders_Load',
    @step_name = 'Load_ERP_Orders',
    @retry_attempts = 5,
    @retry_interval = 5;
```

---

## Monitoring & Troubleshooting

### Real-Time Job Status
```sql
-- View current job status
SELECT * FROM vw_etl_job_summary;

-- View recent failures
SELECT * FROM vw_recent_job_failures;
```

### Performance Metrics
```sql
-- 7-day performance dashboard
EXEC sp_get_etl_job_dashboard @DaysToAnalyze = 7;

-- Check incremental load health
EXEC sp_get_incremental_checkpoint_status;
```

### Diagnostic Queries
```sql
-- All ETL activity for the day
SELECT * FROM etl_logs 
WHERE CAST(log_date AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY log_date DESC;

-- Job execution history (SQL Agent)
SELECT 
    j.name, 
    h.run_date, 
    h.run_time, 
    h.run_status,
    h.message
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE j.name LIKE 'ETL_%'
ORDER BY h.run_date DESC, h.run_time DESC;
```

---

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Jobs not executing | SQL Agent not running | `net start SQLSERVERAGENT` |
| "Procedure not found" | Stored procedures not created | Execute orchestration stored procedure scripts first |
| Checkpoint not updating | Permissions issue | Grant INSERT/UPDATE on checkpoints table |
| Long run times | Index missing on staging | Create indexes on source_modified_date columns |
| Frequent retries | Source system slow | Increase timeout or move load time earlier |
| Data gaps | Jobs disabled | Check `sysschedules.enabled = 1` |

---

## Performance Tips

### For Faster Loads:
1. **Index Creation:** Add indexes on change tracking columns
   ```sql
   CREATE INDEX ix_modified_date ON stg_raw_erp_orders(source_modified_date);
   ```

2. **Batch Processing:** Adjust batch sizes in orchestration
   ```sql
   @BatchSize = 100000  -- Process in chunks
   ```

3. **Parallel Execution:** Current schedule runs loads in parallel
   - Already optimized for concurrent execution
   - No conflicts between independent data sources

### For Better Monitoring:
1. Check `etl_logs` table regularly
2. Review `vw_etl_job_summary` daily
3. Set up email notifications on failures
4. Archive old logs to keep performance good

---

## Maintenance Tasks

### Weekly (Sunday 4:00 AM)
- Checkpoint archival (>3 months old)
- Statistics update on staging tables
- Log table cleanup

### Monthly
- Index defragmentation
- Checkpoint table rebuild
- Review and optimize job schedules

### Quarterly
- Capacity planning review
- Performance trend analysis
- Incremental load window adjustment

---

## Next Steps

1. ✅ Execute all four SQL scripts in order
2. ✅ Verify jobs in SQL Server Agent
3. ✅ Initialize checkpoints for your sources
4. ✅ Test a manual execution of master job
5. ✅ Monitor first scheduled run
6. ✅ Adjust timings based on performance
7. ✅ Set up email alerts for failures

---

## Support & References

- **ETL Architecture:** See `backend/documentation/architecture/DATABASE_ARCHITECTURE.md`
- **Job Schedule Details:** See `ETL_JOB_SCHEDULE.md`
- **Stored Procedures:** See `backend/database/stored_procedures/`
- **SQL Optimization:** See `backend/documentation/architecture/SQL_OPTIMIZATION_IMPLEMENTATION_GUIDE.md`

---

**Last Updated:** June 2024
**Version:** 1.0
