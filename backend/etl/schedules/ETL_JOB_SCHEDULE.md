# ETL Job Execution Schedule

## Overview
This document defines the complete SQL Server Agent job schedule for the Enterprise KPI Data Warehouse platform.

---

## Daily ETL Pipeline Schedule

### Stage 1: Incremental Data Loads (12:45 AM - 1:30 AM)
Data arrives from source systems and is loaded into staging tables incrementally.

| Time | Job Name | Purpose | Duration | Retry Logic |
|------|----------|---------|----------|-------------|
| 12:45 AM | `ETL_Incremental_Inventory_Load` | Load inventory changes | 5-10 min | 3x, 5 min intervals |
| 1:00 AM | `ETL_Incremental_Salesforce_Customers_Load` | Load customer updates from Salesforce | 5-10 min | 3x, 5 min intervals |
| 1:30 AM | `ETL_Incremental_ERP_Orders_Load` | Load order changes from ERP | 10-15 min | 3x, 5 min intervals |

**Dependencies:** None - these run in parallel

---

### Stage 2: Master ETL Orchestration (2:00 AM - 3:15 AM)
Transforms staged data through dimensions, facts, and KPI calculations.

| Time | Job Name | Steps | Duration | Retry Logic |
|------|----------|-------|----------|-------------|
| 2:00 AM | `ETL_Master_Orchestration` | 1. Execute ETL | 60-120 min | 3x, 5 min intervals |
| | | 2. Validate Data Quality | | |
| | | 3. Refresh KPI Metrics | | |

**Dependencies:** Wait for all Stage 1 jobs to complete

---

### Stage 3: Monitoring & Validation (3:00 AM - 3:30 AM)
Post-ETL validation and freshness checks.

| Time | Job Name | Purpose | Duration | Retry Logic |
|------|----------|---------|----------|-------------|
| 3:00 AM | `ETL_Data_Freshness_Validation` | Verify data currency | 5 min | 1x, 5 min interval |

**Dependencies:** Wait for Master Orchestration completion

---

### Stage 4: Health Checks & Monitoring (Continuous)
Real-time monitoring runs every 30 minutes throughout the day.

| Frequency | Job Name | Purpose | Duration |
|-----------|----------|---------|----------|
| Every 30 min | `ETL_Health_Check_Monitor` | Monitor job health & failures | 2-3 min |

---

### Stage 5: Weekly Maintenance (4:00 AM Sunday)
Weekly cleanup and optimization tasks.

| Time | Job Name | Purpose | Duration |
|------|----------|---------|----------|
| 4:00 AM (Sun) | `ETL_Checkpoint_Maintenance` | Archive checkpoints, optimize tables | 15-30 min |

---

## Total Processing Time

| Component | Estimated Duration |
|-----------|-------------------|
| Stage 1 (Parallel Loads) | 30 minutes |
| Stage 2 (Master + Validation) | 90-120 minutes |
| Stage 3 (Post-Load Checks) | 10 minutes |
| **Total Nightly Pipeline** | **130-160 minutes** |
| **Completion Target** | **3:30 AM - 4:00 AM** |

---

## Incremental ETL Strategy

### How Incremental Loading Works

```
Source Systems → Incremental Load (Change Tracking)
                ↓
         Staging Tables (stg_raw_*)
                ↓
    Incremental Checkpoints (Track Last Load)
                ↓
   Master Orchestration (INCREMENTAL Mode)
                ↓
    Dimensions (SCD Type 2 for changes)
                ↓
         Fact Tables (Delta Insert)
                ↓
    KPI Summary Tables (Recalculate)
                ↓
   Reporting Views (Query Latest)
```

### Checkpoint Tracking

Each incremental load maintains a checkpoint record:

```sql
etl_incremental_checkpoints:
├── source_system (ERP, SALESFORCE, INVENTORY)
├── table_name (Orders, Customers, Stock)
├── last_load_time (Timestamp of last successful load)
├── record_count (How many records in last batch)
├── last_status (SUCCESS, FAILED, INCOMPLETE)
└── last_error_message (If failed)
```

### Recovery Mechanism

1. **First Failure:** Job retries automatically (3 attempts with 5-min intervals)
2. **Persistent Failure:** Job fails and alerts are generated
3. **Manual Recovery:** 
   - Check `etl_logs` for error details
   - Fix source data issue
   - Execute `sp_etl_master_orchestration` with same date
   - Checkpoint automatically updates

---

## Job Execution Flow Chart

```
┌─────────────────────────────────────┐
│   Daily Schedule Triggered (12:45)  │
└────────┬────────────────────────────┘
         │
         ├─ ERP Orders Load ────┐
         ├─ Salesforce Customers ─┤
         └─ Inventory Load ────┘
              (Parallel)
              ↓
         All 3 Succeed?
              │ Yes
              ↓
    ┌──────────────────────────┐
    │  Master Orchestration     │
    │  (2:00 AM - 3:00 AM)     │
    │  1. Transform Staging     │
    │  2. Load Dimensions       │
    │  3. Load Facts            │
    │  4. Calc KPIs             │
    └──────────────────────────┘
              ↓
         All Steps OK?
              │ Yes
              ↓
    ┌──────────────────────────┐
    │  Data Freshness Check     │
    │  (3:00 AM - 3:05 AM)     │
    └──────────────────────────┘
              ↓
    ┌──────────────────────────┐
    │  ETL Complete - Ready     │
    │  for Executive Reporting  │
    └──────────────────────────┘
```

---

## Failure Scenarios & Actions

### Scenario 1: Incremental Load Fails
- **When:** Stage 1 job fails after 3 retries
- **Alert:** Email + database log entry
- **Action:** 
  1. Check source system connectivity
  2. Verify data quality in source
  3. Manually execute failed job
  4. Rerun Master Orchestration

### Scenario 2: Master Orchestration Fails
- **When:** Any step in Stage 2 fails
- **Alert:** Email to DBA team
- **Action:**
  1. Check `etl_logs` for specific failure
  2. Review data quality validation results
  3. Execute `sp_etl_master_orchestration` with debug mode
  4. Address root cause

### Scenario 3: Data Not Fresh
- **When:** Data freshness check (Stage 3) fails
- **Alert:** Database alert + log
- **Action:**
  1. Check if Master Orchestration completed
  2. Verify fact tables have recent data
  3. If needed, run full refresh instead of incremental

---

## Performance Tuning Checkpoints

### Monitor These Metrics
```sql
-- Check job duration trends
SELECT 
    DateOfRun,
    AVG(DurationMinutes) AS AvgDuration,
    MAX(DurationMinutes) AS MaxDuration
FROM vw_job_history
WHERE JobName = 'ETL_Master_Orchestration'
GROUP BY DateOfRun
ORDER BY DateOfRun DESC;
```

### Optimization Targets
- **Stage 1:** Should complete in <30 min
- **Stage 2:** Should complete in <120 min  
- **Total:** Should complete by 3:30 AM

### If Slow:
1. Review indexes on staging tables
2. Check SQL Server resource usage
3. Consider parallelizing more jobs
4. Archive old checkpoint data

---

## Modification Procedures

### To Add a New Incremental Load Job:
1. Create source connector/query
2. Add new job script to `sql_jobs/` folder
3. Update checkpoint table with new source/table
4. Adjust orchestration schedule

### To Change Job Timing:
```sql
-- Modify schedule
EXEC sp_update_schedule 
    @schedule_name = 'Daily_02AM_Incremental_ETL',
    @active_start_time = 013000;  -- New time: 1:30 AM
```

### To Disable/Enable a Job:
```sql
-- Disable
EXEC sp_update_job @job_name = 'JobName', @enabled = 0;

-- Enable
EXEC sp_update_job @job_name = 'JobName', @enabled = 1;
```

---

## Monitoring Dashboard Query

```sql
-- Real-time job status
SELECT * FROM vw_etl_job_summary;

-- Recent failures
SELECT * FROM vw_recent_job_failures;

-- Performance metrics
EXEC sp_get_etl_job_dashboard @DaysToAnalyze = 7;

-- Incremental checkpoint health
EXEC sp_get_incremental_checkpoint_status;
```

---

## Support & Troubleshooting

### Common Issues

| Issue | Cause | Resolution |
|-------|-------|-----------|
| "No data in staging" | Source data not arrived | Wait for source extraction, check connectors |
| Checkpoint stuck | Previous load incomplete | Manually reset checkpoint, rerun |
| Slow performance | Missing indexes | Run index maintenance job |
| Jobs not triggering | Schedule disabled | Check `sysschedules`, re-enable |
| OOM errors | Large batch sizes | Reduce batch size in orchestration |

### Reference Tables
- `etl_logs` - All job activity logs
- `etl_incremental_checkpoints` - Checkpoint tracking
- `etl_alerts` - Alert history
- `msdb.dbo.sysjobhistory` - SQL Agent job history

