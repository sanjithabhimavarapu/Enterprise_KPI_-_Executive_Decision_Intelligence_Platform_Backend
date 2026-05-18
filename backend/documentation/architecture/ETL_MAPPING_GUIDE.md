# Source-to-Target Data Mapping & ETL Guide

## Overview
This document provides detailed source-to-target mappings and ETL transformation logic for the Enterprise KPI data warehouse.

---

## 1. ERP (SAP/Oracle) → Data Warehouse Mapping

### Source: Orders

| Source Field | Data Type | Target Dimension/Fact | Target Field | Transformation |
|--------------|-----------|----------------------|--------------|-----------------|
| ORDER_ID | VARCHAR | fact_sales | order_id | Direct |
| ORDER_DATE | DATE | dim_date | date_value | Lookup dim_date via order_date_key |
| CUSTOMER_ID | VARCHAR | dim_customer | customer_id | Lookup dim_customer key |
| PRODUCT_ID | VARCHAR | dim_product | product_id | Lookup dim_product key |
| ORDER_QTY | DECIMAL | fact_sales | order_quantity | Direct |
| UNIT_PRICE | DECIMAL | fact_sales | unit_price | Direct |
| DISCOUNT_PERCENT | DECIMAL | fact_sales | discount_percent | Direct or calculate |
| SALES_REP_ID | VARCHAR | dim_employee | employee_id | Lookup dim_employee key |
| DELIVERY_DATE | DATE | fact_sales | delivery_date | Direct |
| ORDER_STATUS | VARCHAR | fact_sales | order_status | Standardize (Pending→Open, Complete→Closed) |

**Derived Fields**:
```sql
line_amount = order_quantity * unit_price
discount_amount = line_amount * discount_percent
net_sales_amount = line_amount - discount_amount
cost_amount = order_quantity * product_cost
gross_profit = net_sales_amount - cost_amount
days_to_delivery = DATEDIFF(delivery_date, order_date)
```

### Source: Inventory

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| WAREHOUSE_ID | fact_inventory | Direct lookup warehouse_location_id |
| PRODUCT_ID | fact_inventory | Lookup dim_product key |
| SNAPSHOT_DATE | fact_inventory | Lookup dim_date key |
| BEGINNING_BAL | fact_inventory | Direct |
| RECEIPTS | fact_inventory | units_received |
| ISSUES | fact_inventory | units_sold |
| RETURNS | fact_inventory | units_returned |
| DAMAGES | fact_inventory | units_damaged |
| ENDING_BAL | fact_inventory | Direct |

**Validation Rules**:
- `ENDING_BAL = BEGINNING_BAL + RECEIPTS - ISSUES + RETURNS - DAMAGES`
- `ENDING_BAL >= 0`
- `SNAPSHOT_DATE > prior_day_snapshot`

---

## 2. CRM (Salesforce) → Data Warehouse Mapping

### Source: Accounts/Customers

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| ACCOUNT_ID | dim_customer | customer_id (SCD Type 2) |
| ACCOUNT_NAME | dim_customer | customer_name |
| INDUSTRY | dim_customer | industry |
| BILLING_CITY, STATE, COUNTRY | dim_geography | Lookup geography_key |
| ACCOUNT_TYPE | dim_customer | account_type (Enterprise, SMB, etc.) |
| ARR (Annual Recurring Revenue) | dim_customer | annual_contract_value |
| LIFECYCLE_STAGE | dim_customer | subscription_status |
| CREATED_DATE | dim_customer | acquisition_date |
| OWNER_ID | dim_employee | Lookup employee_key |

**SCD Type 2 Trigger Logic**:
```sql
IF ISNULL(prior_INDUSTRY) != ISNULL(current_INDUSTRY) 
   OR ISNULL(prior_ARR) != ISNULL(current_ARR)
   OR ISNULL(prior_LIFECYCLE_STAGE) != ISNULL(current_LIFECYCLE_STAGE)
THEN
    UPDATE: Set end_date = TODAY - 1, is_current = FALSE
    INSERT: New row with effective_date = TODAY, is_current = TRUE
END
```

### Source: Opportunities

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| OPPORTUNITY_ID | fact_customer_interactions | interaction_id |
| ACCOUNT_ID | dim_customer | customer_key lookup |
| AMOUNT | fact_customer_interactions | Duration (in days): CLOSE_DATE - CREATED_DATE |
| CREATED_DATE | dim_date | Lookup date_key |
| CLOSE_DATE | dim_date | Lookup date_key |
| STAGE | fact_customer_interactions | mapping: Prospecting→1, Qualification→2, etc. |
| STATUS | fact_customer_interactions | Won/Lost mapping |
| OWNER_ID | dim_employee | Lookup employee_key |

### Source: Activities (Calls, Emails, Meetings)

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| ACTIVITY_ID | fact_customer_interactions | interaction_id |
| ACCOUNT_ID | dim_customer | customer_key |
| ACTIVITY_DATE | dim_date | date_key |
| CALL_DURATION | fact_customer_interactions | duration_seconds = duration * 60 |
| ACTIVITY_TYPE | fact_customer_interactions | Call, Email, Meeting, Task |
| WHO_ID | dim_employee | employee_key |
| CALL_DISPOSITION | fact_customer_interactions | mapping to result codes |
| DESCRIPTION | fact_customer_interactions | Store as notes (text) |

---

## 3. Financial System (NetSuite) → Data Warehouse Mapping

### Source: Transactions

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| TRANID | fact_revenue | order_id reference |
| TRANDATE | dim_date | date_key |
| ENTITY_ID | dim_customer | customer_key lookup |
| TOTAL | fact_revenue | total_revenue |
| AMOUNT | fact_revenue | net_revenue |
| TAXAMT | fact_revenue | tax component |
| MEMOMAIN | fact_revenue | internal_reference |
| STATUS | fact_revenue | mapping (Approved, Pending) |

**Ledger Mapping**:
```
Asset Accounts (1000-1999)     → Cost components
Liability Accounts (2000-2999) → Skip or map to payables
Revenue Accounts (4000-4999)   → gross_sales
COGS Accounts (5000-5999)      → cost_of_goods
Expense Accounts (6000-6999)   → operating_expenses
```

---

## 4. HRMS (Workday) → Data Warehouse Mapping

### Source: Employee Data

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| EMPLOYEE_ID | dim_employee | employee_id (SCD Type 2) |
| FULL_NAME | dim_employee | employee_name |
| JOB_TITLE | dim_employee | job_title (SCD Type 2) |
| DEPARTMENT | dim_department | Lookup department_key |
| MANAGER_ID | dim_employee | Lookup manager's employee_key |
| EMPLOYMENT_STATUS | dim_employee | mapping (Active, On Leave, Terminated) |
| HIRE_DATE | dim_employee | hire_date |
| TERMINATION_DATE | dim_employee | termination_date (if terminated) |
| CITY, STATE, COUNTRY | dim_geography | Lookup geography_key |

### Source: Payroll

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| EMPLOYEE_ID | fact_hr_metrics | employee_key lookup |
| PAY_DATE | dim_date | date_key |
| GROSS_PAY | fact_hr_metrics | revenue_generated (for commission tracking) |
| BASE_SALARY | fact_hr_metrics | base compensation |
| NET_PAY | fact_hr_metrics | Net compensation |

---

## 5. Operations (IoT/Custom Systems) → Data Warehouse Mapping

### Source: Production Data

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| BATCH_ID | fact_production_metrics | production_batch_id |
| LINE_ID | fact_production_metrics | line_id |
| PRODUCT_ID | dim_product | product_key lookup |
| PRODUCTION_TIMESTAMP | dim_date / dim_time | date_key, time_key lookups |
| UNITS_PRODUCED | fact_production_metrics | units_completed |
| UNITS_DEFECTIVE | fact_production_metrics | units_defective |
| SHIFT_SUPERVISOR | dim_employee | employee_key lookup |
| DOWNTIME_MIN | fact_production_metrics | downtime_minutes |

**Calculated Metrics**:
```sql
first_pass_yield = (units_completed - units_defective) / units_completed * 100
defect_rate = units_defective / units_completed * 100
efficiency = units_completed / (scheduled_units) * 100
```

---

## 6. Support System (ServiceNow/Jira) → Data Warehouse Mapping

### Source: Tickets

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| TICKET_ID | fact_support_metrics | ticket_id |
| ACCOUNT_ID | dim_customer | customer_key |
| CREATED_DATE | dim_date | created_date_key |
| RESOLVED_DATE | dim_date | resolved_date_key (if closed) |
| PRIORITY | fact_support_metrics | mapping (1=Critical, 2=High, 3=Medium, 4=Low) |
| DESCRIPTION | fact_support_metrics | category parsing (extract from description) |
| STATUS | fact_support_metrics | mapping (Open, In Progress, Resolved, Closed) |
| ASSIGNED_TO | dim_employee | agent_employee_key |
| RESOLUTION_NOTES | fact_support_metrics | Store as resolution_type |

**Time Calculations**:
```sql
time_to_first_response = DATEDIFF(first_response_date, created_date) * 1440  -- in minutes
time_to_resolution = DATEDIFF(resolved_date, created_date) * 24  -- in hours
escalations = COUNT(*) WHERE priority_increased
```

---

## 7. Marketing Automation (HubSpot/Marketo) → Data Warehouse Mapping

### Source: Campaigns

| Source Field | Target | Transformation |
|--------------|--------|-----------------|
| CAMPAIGN_ID | fact_marketing_performance | campaign_id |
| CAMPAIGN_NAME | fact_marketing_performance | campaign_name |
| CAMPAIGN_TYPE | fact_marketing_performance | mapping (Email, Social, Webinar, Paid_Search) |
| START_DATE | dim_date | campaign_date_key |
| IMPRESSIONS | fact_marketing_performance | Direct |
| CLICKS | fact_marketing_performance | Direct |
| LEADS_CREATED | fact_marketing_performance | Direct |
| CAMPAIGN_COST | fact_marketing_performance | Direct |

**Calculated Metrics**:
```sql
click_through_rate = clicks / impressions * 100
cost_per_click = campaign_cost / clicks
cost_per_lead = campaign_cost / leads_created
lead_conversion_rate = leads_converted / leads_created * 100
roi = (pipeline_value - campaign_cost) / campaign_cost * 100
```

---

## ETL Pipeline Architecture

### Phase 1: Extraction

```
Source Systems → API/DB Extraction → Staging Layer
                     ↓
        CDC (Change Data Capture) Logs
        ↓
    Identify Changed Records
```

### Phase 2: Transformation

```
Staging Tables → Data Validation
                    ↓
            Deduplication (if needed)
                    ↓
            Standardization & Cleansing
                    ↓
        Business Logic & Calculations
                    ↓
        Slowly Changing Dimension Logic
                    ↓
        Lookup Dimension Keys
```

### Phase 3: Loading

```
Transformed Data → Dimension Updates (SCD Type 2)
                    ↓
                Fact Table Inserts
                    ↓
            Data Quality Verification
                    ↓
            Update Metadata Tables
```

---

## Data Validation Rules

### Pre-Load Validation (Staging)

| Rule | Condition | Action |
|------|-----------|--------|
| Completeness | All NOT NULL columns populated | Flag & quarantine if NULL |
| Range Check | Date fields within reasonable range | Flag if future_date > TODAY + 1 year |
| Format Check | Email format valid | Flag invalid emails |
| Key Uniqueness | No duplicate business keys | Flag duplicates for investigation |
| Referential | Foreign keys exist in source | Flag orphaned records |

### Post-Load Validation (Warehouse)

```sql
-- Fact table validation
SELECT 'Missing customer_key' as issue, COUNT(*) as count
FROM fact_sales WHERE customer_key IS NULL
UNION ALL
SELECT 'Negative sales amount', COUNT(*)
FROM fact_sales WHERE net_sales_amount < 0
UNION ALL
SELECT 'Future order date', COUNT(*)
FROM fact_sales WHERE order_date_key > CONVERT(INT, FORMAT(GETDATE(), 'yyyyMMdd'));
```

---

## Performance Optimization Tips

### 1. Incremental Loading

**Instead of full refresh**:
```sql
-- Bad: Full table refresh (time/resource intensive)
TRUNCATE TABLE fact_sales;
INSERT INTO fact_sales SELECT * FROM stg_orders;

-- Good: Incremental load based on CDC
INSERT INTO fact_sales 
SELECT * FROM stg_orders 
WHERE source_record_id IN (
    SELECT source_record_id FROM stg_cdc_logs 
    WHERE source_table = 'orders' 
    AND processed_flag = FALSE
);
```

### 2. Batch Processing

```sql
-- Process in batches to manage memory
DECLARE @batch_size INT = 10000;
DECLARE @row_count INT = 0;

WHILE @row_count < (SELECT COUNT(*) FROM stg_orders WHERE processed = FALSE)
BEGIN
    INSERT INTO fact_sales (SELECT TOP @batch_size ... FROM stg_orders ...);
    SET @row_count = @row_count + @batch_size;
END
```

### 3. Parallel Dimension Loading

- Load independent dimensions in parallel
- fact_sales depends on all dimensions → load after
- Reduces overall ETL duration

---

## ETL Scheduling

| Source | Load Frequency | Load Window | Type |
|--------|---------------|-----------|----|
| ERP Orders | Real-time | 24x7 | CDC/Event |
| ERP Inventory | Hourly | 24x7 | Batch |
| CRM Customers | Real-time | 24x7 | CDC/Event |
| CRM Opportunities | Real-time | 24x7 | CDC/Event |
| CRM Activities | Real-time | 24x7 | CDC/Event |
| Finance | Daily | 00:00-02:00 UTC | Batch |
| HRMS | Weekly | Sunday 22:00 UTC | Batch |
| Operations | Real-time | 24x7 | Streaming |
| Support | Real-time | 24x7 | CDC/Event |
| Marketing | Daily | 01:00-03:00 UTC | Batch |

---

## Monitoring & Alerting

### Key Metrics

```sql
-- Data freshness
SELECT 
    source_system,
    MAX(source_load_ts) as last_load,
    DATEDIFF(minute, MAX(source_load_ts), GETDATE()) as minutes_stale
FROM stg_cdc_logs
GROUP BY source_system;

-- Record counts
SELECT 
    source_table,
    COUNT(*) as record_count,
    COUNT(DISTINCT source_record_id) as unique_records,
    COUNT(*) - COUNT(DISTINCT source_record_id) as duplicates
FROM stg_orders
WHERE load_ts > GETDATE() - 1
GROUP BY source_table;
```

### SLA Targets

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Data Freshness | <15 min | >30 min |
| ETL Success Rate | 100% | <95% |
| Data Quality Score | >98% | <95% |
| Failed Records | <0.1% | >0.5% |

