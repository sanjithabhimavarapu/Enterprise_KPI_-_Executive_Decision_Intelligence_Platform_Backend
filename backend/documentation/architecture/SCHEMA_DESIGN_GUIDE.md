# Data Warehouse Schema Design - Comprehensive Guide

## Table of Contents
1. [Schema Overview](#schema-overview)
2. [Dimensional Modeling Approach](#dimensional-modeling-approach)
3. [Dimension Table Details](#dimension-table-details)
4. [Fact Table Details](#fact-table-details)
5. [Staging Layer Design](#staging-layer-design)
6. [Data Quality & Metadata](#data-quality--metadata)
7. [Implementation Best Practices](#implementation-best-practices)
8. [Performance Considerations](#performance-considerations)

---

## Schema Overview

### Star Schema Architecture

The data warehouse uses a **dimensional modeling** approach based on Ralph Kimball's Star Schema methodology:

```
                    ┌──────────────────┐
                    │    dim_date      │
                    │  (conformed)     │
                    └──────────────────┘
                           ▲
                    ┌──────┴──────┐
                    │             │
        ┌───────────┴───────┐     │
        │                   │     │
    ┌────────────────┐  ┌───▼──────────────┐
    │  dim_customer  │  │   FACT_SALES     │◄─────┐
    │  (SCD Type 2)  │  │  (Transactional) │      │
    └────────────────┘  └───┬──────────────┘      │
        ▲                   │                      │
        │                   ├────────────────────┐ │
        │              ┌────▼───┐          ┌────┴─┴────────┐
        │              │ dim_   │          │ dim_product   │
        │              │employee│          │ (SCD Type 2)  │
        │              └────────┘          └───────────────┘
        │                                            ▲
        └────────────────────────────────────────────┘
```

### Database Layers

| Layer | Purpose | Retention | Update Frequency | Tables |
|-------|---------|-----------|------------------|--------|
| **Staging** | Raw data extraction | 7-30 days | Real-time to hourly | stg_* (30+) |
| **Cleansed** | Data validation & dedup | 90 days | Post-ingestion | Intermediate tables |
| **Warehouse** | Business-ready analytics | 5 years | Real-time to daily | dim_* (7), fact_* (8) |
| **Marts** | Domain-specific views | 2-3 years | Hourly to daily | Aggregated tables |
| **Analytics** | BI & dashboards | Current | On-demand | Views/Exports |

---

## Dimensional Modeling Approach

### Key Principles

1. **Conformed Dimensions**: Shared dimensions across fact tables (e.g., `dim_date`, `dim_geography`)
2. **Slowly Changing Dimensions (SCD)**:
   - **Type 1**: Overwrite - For attributes that change without need for history
   - **Type 2**: Maintain History - For attributes requiring complete audit trail (customer_key, effective_date, end_date, is_current)
3. **Junk Dimensions**: Grouping of low-cardinality attributes (embedded in fact tables)
4. **Bridge Tables**: Resolving many-to-many relationships (e.g., `bridge_customer_product`)

### Grain Definition

Each fact table has a clearly defined grain (level of detail):

| Fact Table | Grain | Example Record |
|-----------|-------|-----------------|
| fact_sales | Order line item | 1 product sold to 1 customer on 1 date |
| fact_revenue | Daily aggregate | All sales to customer X for product Y on date Z |
| fact_inventory | Warehouse location item day | Product X at warehouse Y on date Z |
| fact_customer_interactions | Interaction event | 1 phone call between customer and agent |
| fact_hr_metrics | Employee day | Employee X on date Y |
| fact_production_metrics | Production batch/shift | Batch X produced on date Y |
| fact_support_metrics | Support ticket | 1 customer ticket |
| fact_marketing_performance | Campaign day | Campaign X on date Y |

---

## Dimension Table Details

### 1. dim_customer (SCD Type 2)

**Purpose**: Track customer master data with full history of changes

**Key Features**:
- Captures customer segment (Enterprise, Mid-Market, SMB, Startup)
- Tracks acquisition date and first sale date
- Maintains subscription status history
- Supports many-to-many relationship via `bridge_customer_product`

**Example Use Cases**:
```sql
-- Find all revenue from enterprise segment (as of today)
SELECT SUM(fs.net_sales_amount)
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
WHERE dc.is_current = TRUE
  AND dc.customer_segment = 'Enterprise';

-- Time-travel: Revenue from customers that were Enterprise on specific date
SELECT SUM(fs.net_sales_amount)
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
WHERE dd.date_value = '2025-06-30'
  AND dc.effective_date <= '2025-06-30'
  AND COALESCE(dc.end_date, '9999-12-31') > '2025-06-30'
  AND dc.customer_segment = 'Enterprise';
```

### 2. dim_product (SCD Type 2)

**Purpose**: Track product master data including pricing and categorization

**Key Features**:
- Product hierarchy (category → subcategory → product)
- Cost tracking for margin calculations
- Supplier and warehouse location information
- Lead time for inventory planning

**Attributes for Analysis**:
- Gross margin percent (for profitability analysis)
- Unit of measure (for normalization)
- Product status (Active, Discontinued, etc.)

### 3. dim_employee (SCD Type 2)

**Purpose**: Track employee master data for HR and sales analysis

**Key Features**:
- Employment status tracking (Active, Inactive, On Leave, Terminated)
- Department and reporting hierarchy
- Location information for regional analysis
- Tracks manager relationships

**Example Use Cases**:
```sql
-- Sales per rep by month
SELECT 
    dd.year_month,
    de.employee_name,
    SUM(fr.total_revenue) as monthly_revenue
FROM fact_revenue fr
JOIN dim_employee de ON fr.employee_key = de.employee_key
JOIN dim_date dd ON fr.date_key = dd.date_key
WHERE de.is_current = TRUE
  AND de.employment_status = 'Active'
GROUP BY dd.year_month, de.employee_name;
```

### 4. dim_geography (SCD Type 2)

**Purpose**: Hierarchical geographic dimension for location-based analysis

**Hierarchy**: Country → Region → State → City → Postal Code

**Key Features**:
- Sales territory mapping
- Geographic coordinates for mapping
- Population and economic indicators
- Time zone information

### 5. dim_date (Conformed, Type 1)

**Purpose**: Standard calendar dimension for all date-based reporting

**Key Features**:
- Fiscal calendar support (fiscal_year, fiscal_quarter, fiscal_month)
- Business day identification
- Holiday flagging
- Week-based analysis support

**Pre-loaded Data**:
- 7,300 records (20 years: 2000-2020)
- Date keys formatted as YYYYMMDD (e.g., 20260518)
- All calendar attributes pre-calculated

### 6. dim_time (Conformed, Type 1)

**Purpose**: Time-of-day dimension for intra-day analysis

**Key Features**:
- One row per minute (1,440 records)
- Business hours flag
- Time period classification (Morning, Afternoon, Evening, Night)
- Hour and minute breakdowns

### 7. dim_department (SCD Type 2)

**Purpose**: Organizational hierarchy for HR and budget analysis

**Attributes**:
- Department hierarchy (parent-child relationships)
- Cost center mapping
- Budget tracking
- Headcount

---

## Fact Table Details

### 1. fact_sales (Transactional)

**Grain**: One row per sales transaction line item

**Update Strategy**: Real-time (via CDC or trigger)

**Key Metrics**:
- Order quantity
- Unit price
- Line amount (quantity × unit_price)
- Discount amount & percent
- Net sales amount (line_amount - discount)
- Cost amount
- Gross profit (net_sales - cost)

**Dimensions**:
- customer_key (who bought)
- product_key (what was bought)
- employee_key (sales rep)
- geography_key (delivery location)
- order_date_key / close_date_key (when)

**Typical Query**:
```sql
-- Sales by customer segment
SELECT 
    dc.customer_segment,
    COUNT(*) as order_count,
    SUM(fs.net_sales_amount) as total_revenue,
    AVG(fs.net_sales_amount) as avg_order_value,
    SUM(fs.gross_profit) as total_profit
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
WHERE dc.is_current = TRUE
GROUP BY dc.customer_segment;
```

### 2. fact_revenue (Aggregate)

**Grain**: One row per day per customer per product

**Purpose**: Pre-aggregated daily revenue for executive reporting

**Measures**:
- total_revenue
- revenue_count (number of transactions)
- average_transaction_amt
- gross_margin_percent

**Typical Query**:
```sql
-- Daily revenue trend
SELECT 
    dd.year_month,
    SUM(fr.total_revenue) as monthly_revenue,
    AVG(fr.total_revenue) as avg_daily_revenue
FROM fact_revenue fr
JOIN dim_date dd ON fr.date_key = dd.date_key
WHERE dd.year >= 2025
GROUP BY dd.year_month
ORDER BY dd.year_month;
```

### 3. fact_inventory (Transactional)

**Grain**: Inventory snapshot per warehouse location per product per day

**Key Metrics**:
- Beginning/Ending balance
- Units received/sold/returned/damaged
- Inventory value
- Days on hand
- Defect rate

### 4. fact_customer_interactions (Transactional)

**Grain**: One row per customer interaction event

**Interaction Types**: Call, Email, Meeting, Chat, Demo, etc.

**Key Metrics**:
- Duration (seconds)
- Sentiment (Positive, Neutral, Negative)
- Satisfaction score
- NPS (Net Promoter Score)
- Interaction result (Success, Partial, Failed)

### 5. fact_hr_metrics (Aggregate)

**Grain**: One row per employee per day

**Update Strategy**: Daily (End of Day)

**Key Metrics**:
- Hours worked
- Tasks completed
- Revenue generated (for sales staff)
- Training hours
- Performance rating

### 6. fact_production_metrics (Transactional)

**Grain**: One row per production batch/shift

**Key Metrics**:
- Units started/completed
- Defect rate
- First pass yield (FPY)
- Efficiency percent
- Downtime minutes

### 7. fact_support_metrics (Transactional)

**Grain**: One row per support ticket

**Key Metrics**:
- Time to first response (minutes)
- Time to resolution (hours)
- Customer satisfaction score
- Escalations count
- Total interactions

### 8. fact_marketing_performance (Aggregate)

**Grain**: One row per campaign per day

**Key Metrics**:
- Impressions/Clicks/Click-through rate
- Leads generated/qualified
- Lead conversion rate
- Opportunities created/won
- Cost per acquisition
- ROI percent

---

## Staging Layer Design

### Purpose
The staging layer serves as the extraction zone that captures raw data from all source systems before transformation and loading into the warehouse.

### Key Characteristics

1. **Exact Replica**: Direct copy of source data with minimal transformation
2. **Short Retention**: 7-30 days (sufficient for recovery and audit)
3. **Metadata Tracking**:
   - `load_ts`: Timestamp of load into staging
   - `source_load_ts`: Timestamp from source system
   - `dw_hash`: Hash of business key columns (for change detection)
   - `source_record_id`: Business key for uniqueness

### Staging Tables

#### From ERP (SAP/Oracle)
- `stg_orders`: Sales orders and line items
- `stg_inventory`: Inventory balances by location

#### From CRM (Salesforce)
- `stg_customers`: Customer master data
- `stg_opportunities`: Sales opportunities
- `stg_activities`: Customer interactions

#### From Finance (NetSuite)
- `stg_transactions`: Financial transactions
- `stg_gl_accounts`: General ledger accounts

#### From HRMS (Workday)
- `stg_employees`: Employee master data
- `stg_payroll`: Payroll information

#### From Operations
- `stg_production`: Production metrics

#### From Support (ServiceNow)
- `stg_tickets`: Support tickets

#### From Marketing (HubSpot)
- `stg_campaigns`: Marketing campaigns

### CDC & Quality Tracking

```sql
-- stg_cdc_logs: Tracks changes for CDC-enabled sources
-- stg_data_quality_metrics: Tracks data quality scores by load
```

---

## Data Quality & Metadata

### Data Quality Metrics Tracked

| Metric | Definition | Target | Calculation |
|--------|-----------|--------|-------------|
| **Completeness** | % of non-null values | >99% | (rows with all fields / total rows) × 100 |
| **Accuracy** | % of valid values | >98% | (valid rows / total rows) × 100 |
| **Timeliness** | % arriving within SLA | >99% | (on-time loads / total loads) × 100 |
| **Consistency** | Cross-source matches | >95% | (matched records / total records) × 100 |
| **Uniqueness** | No duplicate records | 100% | 1 - (duplicate rows / total rows) |

### Metadata Management

**Key Metadata Captured**:
- Table lineage (source → staging → warehouse)
- Column lineage (business logic transformations)
- Data owner and steward
- Update frequency and SLA
- Retention and archival policy
- Data classification (public, confidential, restricted)

---

## Implementation Best Practices

### 1. Surrogate Keys

**Why**: 
- Decouples data warehouse from source systems
- Enables SCD Type 2 slowly changing dimensions
- Improves query performance

**Implementation**:
```sql
-- AUTO_INCREMENT for simple, sequential keys
customer_key BIGINT PRIMARY KEY AUTO_INCREMENT

-- Or IDENTITY in SQL Server/PostgreSQL
```

### 2. Slowly Changing Dimension (SCD) Type 2

**Implementation Pattern**:
```sql
-- Check if record exists
IF EXISTS (SELECT 1 FROM dim_customer WHERE customer_id = @customer_id AND is_current = TRUE)
BEGIN
    -- If changed, close current record
    UPDATE dim_customer 
    SET end_date = @change_date, is_current = FALSE
    WHERE customer_id = @customer_id AND is_current = TRUE;
    
    -- Insert new version
    INSERT INTO dim_customer (..., effective_date, end_date, is_current)
    VALUES (..., @change_date, NULL, TRUE);
END
ELSE
BEGIN
    -- First time - insert as current
    INSERT INTO dim_customer (..., effective_date, end_date, is_current)
    VALUES (..., @load_date, NULL, TRUE);
END
```

### 3. Conformed Dimensions

**Practice**: Maintain single instance of shared dimensions (dim_date, dim_time, dim_geography)

**Benefit**: Consistent analysis across all fact tables

### 4. Indexing Strategy

```sql
-- Primary Key Index (Automatic)
ALTER TABLE dim_customer ADD PRIMARY KEY (customer_key);

-- Natural Key Index (for lookups)
CREATE INDEX idx_dim_customer_id ON dim_customer(customer_id);

-- SCD Filtering Index
CREATE INDEX idx_dim_customer_current ON dim_customer(is_current);

-- Foreign Key Indexes (for joins)
CREATE INDEX idx_fact_sales_customer_key ON fact_sales(customer_key);

-- Date Range Indexes (for time-based queries)
CREATE INDEX idx_dim_date_year_month ON dim_date(year, month);
```

### 5. Partitioning Strategy

**For Large Fact Tables** (>100M rows):
```sql
-- Partition by date (monthly or quarterly)
CREATE TABLE fact_sales (
    ...
) PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p_2024 VALUES LESS THAN (2025),
    PARTITION p_2025 VALUES LESS THAN (2026),
    PARTITION p_2026 VALUES LESS THAN (2027)
);
```

### 6. Naming Conventions

| Object | Naming Pattern | Example |
|--------|----------------|---------|
| Dimension | dim_[entity] | dim_customer |
| Fact | fact_[entity] | fact_sales |
| Staging | stg_[source]_[entity] | stg_erp_orders |
| Bridge | bridge_[dim1]_[dim2] | bridge_customer_product |
| Index | idx_[table]_[columns] | idx_fact_sales_customer_key |
| Foreign Key | fk_[table]_[ref_table] | fk_fact_sales_dim_customer |

---

## Performance Considerations

### 1. Query Optimization

```sql
-- Good: Filtered early
SELECT SUM(fs.net_sales_amount)
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
WHERE dc.is_current = TRUE
  AND fs.order_date_key BETWEEN 20260101 AND 20260331;

-- Avoid: Calculation in WHERE clause (prevents index use)
SELECT SUM(fs.net_sales_amount)
FROM fact_sales fs
WHERE YEAR(fs.order_date) = 2026;  -- ❌ Don't do this
```

### 2. Aggregate Table Maintenance

For frequently used aggregations:
```sql
-- Daily refresh of aggregate table
INSERT INTO fact_revenue (date_key, customer_key, product_key, total_revenue, ...)
SELECT dd.date_key, dc.customer_key, dp.product_key, SUM(fs.net_sales_amount), ...
FROM fact_sales fs
JOIN dim_date dd ON fs.order_date_key = dd.date_key
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
JOIN dim_product dp ON fs.product_key = dp.product_key
WHERE dd.date_value = CURDATE() - 1
GROUP BY dd.date_key, dc.customer_key, dp.product_key;
```

### 3. Storage Optimization

- **Compression**: Enable for historical data (1+ years old)
- **Archival**: Move very old data to cold storage (5+ years)
- **Purging**: Remove data beyond retention period

### 4. Monitoring

**Key Metrics**:
- Query execution time (target: <5 seconds for dashboards)
- Table size growth rate
- Index fragmentation
- Cache hit ratio
- Failed ETL loads

---

## Next Steps

1. **Create Date Dimension**: Pre-load 20 years of dates
2. **Implement Staging Tables**: Set up CDC for real-time sources
3. **Load Master Dimensions**: Initial load of customers, products, employees
4. **Build ETL Pipelines**: Transform staging → warehouse
5. **Create Data Marts**: Aggregate views for BI tools
6. **Set Up Monitoring**: Data quality and performance dashboards

For detailed SQL scripts, see:
- [01_dimensions.sql](../schema/01_dimensions.sql)
- [02_facts.sql](../schema/02_facts.sql)
- [03_staging.sql](../schema/03_staging.sql)
