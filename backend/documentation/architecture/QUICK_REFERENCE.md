# Quick Reference Guide - Data Warehouse Schema

## File Locations

### SQL Schema Files
```
backend/
└── database/
    └── schema/
        ├── 01_dimensions.sql        ← Dimension tables (7 tables)
        ├── 02_facts.sql             ← Fact tables (8 tables)
        └── 03_staging.sql           ← Staging tables (25+ tables)
```

### Documentation Files
```
backend/
└── documentation/
    └── architecture/
        ├── ER_DIAGRAMS.md           ← 8 visual ER diagrams
        ├── SCHEMA_DESIGN_GUIDE.md   ← Complete design guide
        ├── ETL_MAPPING_GUIDE.md     ← Source-to-target mappings
        ├── IMPLEMENTATION_ROADMAP.md ← 16-week implementation plan
        └── QUICK_REFERENCE.md       ← This file
```

---

## Table Summary

### Dimension Tables (7 Tables)

| Table | Type | Records | Purpose |
|-------|------|---------|---------|
| **dim_customer** | SCD Type 2 | 100K | Customer master with history |
| **dim_product** | SCD Type 2 | 500K | Product master with pricing |
| **dim_employee** | SCD Type 2 | 50K | Employee master with org hierarchy |
| **dim_geography** | SCD Type 2 | 10K | Geographic hierarchy |
| **dim_department** | SCD Type 2 | 100 | Organization structure |
| **dim_date** | Type 1 | 7,300 | Calendar (20 years) |
| **dim_time** | Type 1 | 1,440 | Time of day (daily) |

### Fact Tables (8 Tables)

| Table | Grain | Records/Day | Update Frequency | Purpose |
|-------|-------|-------------|------------------|---------|
| **fact_sales** | Order line item | 500K | Real-time | Sales transactions |
| **fact_revenue** | Daily aggregate | 365 | Daily | Revenue aggregates |
| **fact_inventory** | Warehouse-location | 1M | Real-time | Inventory snapshots |
| **fact_customer_interactions** | Interaction event | 2M | Real-time | Customer touchpoints |
| **fact_hr_metrics** | Employee-day | 2K | Daily | HR metrics |
| **fact_production_metrics** | Production event | 1M | Real-time | Manufacturing metrics |
| **fact_support_metrics** | Support ticket | 100K | Real-time | Support tickets |
| **fact_marketing_performance** | Campaign-day | 50K | Daily | Marketing campaigns |

### Staging Tables (25+ Tables)

| Source | Staging Tables | Purpose |
|--------|---|---------|
| **ERP** | stg_orders, stg_inventory | Raw sales & inventory data |
| **CRM** | stg_customers, stg_opportunities, stg_activities | Raw customer & opportunity data |
| **Finance** | stg_transactions, stg_gl_accounts | Raw financial transactions |
| **HRMS** | stg_employees, stg_payroll | Raw employee & payroll data |
| **Operations** | stg_production | Raw production metrics |
| **Support** | stg_tickets | Raw support tickets |
| **Marketing** | stg_campaigns | Raw marketing campaign data |
| **Metadata** | stg_cdc_logs, stg_data_quality_metrics | CDC tracking & quality metrics |

### Bridge Tables (1 Table)

| Table | Purpose |
|-------|---------|
| **bridge_customer_product** | Many-to-many: Track which products each customer uses |

---

## Key Relationships

### Star Schema (fact_sales centered)

```
dim_date ──┐
           ├──→ fact_sales ←──┬── dim_customer
           │                  ├── dim_product
dim_time ──→ (optional)        ├── dim_employee
                               └── dim_geography
```

### SCD Type 2 Attributes

All slowly-changing dimensions include:
- `effective_date` - When the change took effect
- `end_date` - When the change ended (NULL if current)
- `is_current` - Boolean flag (TRUE for current record)
- `dw_insert_ts` - DW load timestamp
- `dw_update_ts` - DW last update timestamp

---

## Common Queries

### Total Revenue by Segment
```sql
SELECT 
    dc.customer_segment,
    SUM(fs.net_sales_amount) as total_revenue,
    COUNT(DISTINCT fs.order_id) as order_count
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
WHERE dc.is_current = TRUE
GROUP BY dc.customer_segment;
```

### Revenue by Month
```sql
SELECT 
    dd.year,
    dd.month_name,
    SUM(fr.total_revenue) as monthly_revenue
FROM fact_revenue fr
JOIN dim_date dd ON fr.date_key = dd.date_key
WHERE dd.year >= YEAR(GETDATE()) - 1
GROUP BY dd.year, dd.month_name, dd.month
ORDER BY dd.year, dd.month;
```

### Customer Interaction Sentiment
```sql
SELECT 
    dc.customer_name,
    fci.interaction_type,
    AVG(fci.satisfaction_score) as avg_satisfaction,
    fci.sentiment
FROM fact_customer_interactions fci
JOIN dim_customer dc ON fci.customer_key = dc.customer_key
WHERE dc.is_current = TRUE
GROUP BY dc.customer_name, fci.interaction_type, fci.sentiment;
```

### Production Efficiency
```sql
SELECT 
    dd.date_value,
    dp.product_name,
    fpm.efficiency_percent,
    fpm.first_pass_yield,
    fpm.defect_rate
FROM fact_production_metrics fpm
JOIN dim_date dd ON fpm.date_key = dd.date_key
JOIN dim_product dp ON fpm.product_key = dp.product_key
WHERE dd.date_value >= DATEADD(day, -30, GETDATE())
ORDER BY dd.date_value DESC, fpm.efficiency_percent DESC;
```

### Support KPIs
```sql
SELECT 
    dc.customer_segment,
    AVG(fsm.time_to_first_response) as avg_first_response_min,
    AVG(fsm.time_to_resolution) as avg_resolution_hours,
    AVG(fsm.customer_satisfaction_score) as avg_satisfaction,
    COUNT(*) as total_tickets
FROM fact_support_metrics fsm
JOIN dim_customer dc ON fsm.customer_key = dc.customer_key
WHERE dc.is_current = TRUE
GROUP BY dc.customer_segment;
```

### Marketing ROI by Channel
```sql
SELECT 
    fmp.campaign_channel,
    SUM(fmp.campaign_cost) as total_cost,
    SUM(fmp.impressions) as total_impressions,
    SUM(fmp.clicks) as total_clicks,
    AVG(fmp.click_through_rate) as avg_ctr,
    SUM(fmp.leads_generated) as total_leads,
    AVG(fmp.roi_percent) as avg_roi
FROM fact_marketing_performance fmp
WHERE fmp.campaign_status = 'Active'
GROUP BY fmp.campaign_channel;
```

---

## Performance Tips

### 1. Use `is_current = TRUE` for Dimension Queries
```sql
-- ✅ Fast: Filtered dimension lookup
JOIN dim_customer dc ON fs.customer_key = dc.customer_key 
                    AND dc.is_current = TRUE

-- ❌ Slow: Without is_current filter
JOIN dim_customer dc ON fs.customer_key = dc.customer_key
```

### 2. Use Date Keys for Range Queries
```sql
-- ✅ Fast: Integer comparison (date_key is INT)
WHERE fs.order_date_key BETWEEN 20260101 AND 20260131

-- ❌ Slow: Date function prevents index use
WHERE MONTH(CONVERT(DATE, fs.order_date_key)) = 1
```

### 3. Use Aggregate Tables When Available
```sql
-- ✅ Fast: Pre-aggregated daily data
SELECT SUM(fr.total_revenue)
FROM fact_revenue fr
WHERE fr.date_key >= 20260101

-- ❌ Slow: Aggregating from transactional data (500K rows/day)
SELECT SUM(fs.net_sales_amount)
FROM fact_sales fs
WHERE fs.order_date_key >= 20260101
```

### 4. Filter Early
```sql
-- ✅ Good: Filter at source
WHERE dc.is_current = TRUE
  AND dc.customer_segment = 'Enterprise'

-- Less efficient: Filter after join
WHERE dc.customer_segment = 'Enterprise'
```

---

## Data Dictionary

### Key Columns Across Tables

| Column | Type | Purpose | Notes |
|--------|------|---------|-------|
| `*_key` | BIGINT | Surrogate key | Primary key for dimension |
| `*_id` | VARCHAR(50) | Natural/business key | Links to source system |
| `date_key` | INT | Date reference | Format: YYYYMMDD (e.g., 20260518) |
| `is_current` | BOOLEAN | SCD Type 2 flag | TRUE = current record |
| `effective_date` | DATE | SCD Type 2 | When change took effect |
| `end_date` | DATE | SCD Type 2 | When change ended (NULL if current) |
| `dw_insert_ts` | TIMESTAMP | Metadata | When loaded to DW |
| `dw_update_ts` | TIMESTAMP | Metadata | When last updated in DW |
| `dw_hash` | VARCHAR(64) | Change detection | Hash of business key |

---

## Data Quality Checks

### Pre-Load Validation (Staging)
- ✅ Completeness: All NOT NULL columns populated
- ✅ Format: Email, phone, dates valid
- ✅ Range: Values within expected ranges
- ✅ Uniqueness: No duplicate business keys
- ✅ Referential: Foreign keys exist in source

### Post-Load Validation (Warehouse)
- ✅ No orphaned dimension keys
- ✅ No negative sales amounts
- ✅ No future order dates
- ✅ Fact-to-dimension ratios reasonable
- ✅ Data freshness within SLA

### Quality Scoring
```
Quality Score = 
    (40% × Completeness) + 
    (30% × Accuracy) + 
    (20% × Timeliness) + 
    (10% × Consistency)

Target: >98% quality score
```

---

## ETL Best Practices

### 1. Incremental Loading
- Only load changed records (CDC)
- Use `source_record_id` for deduplication
- Track via `dw_hash` for change detection

### 2. SCD Type 2 Implementation
```sql
IF EXISTS (SELECT 1 FROM dim_customer WHERE customer_id = @id AND is_current = TRUE)
BEGIN
    UPDATE dim_customer SET end_date = @today - 1, is_current = FALSE
    WHERE customer_id = @id AND is_current = TRUE;
    
    INSERT INTO dim_customer VALUES (..., @today, NULL, TRUE);
END
```

### 3. Batch Processing
- Process in 10K-100K batches
- Reduces memory overhead
- Enables restartability

### 4. Validation & Reconciliation
- Validate row counts: source vs staging vs warehouse
- Check sum validation: totals match source
- Date validation: no future dates

---

## Monitoring & Alerts

### Key Metrics
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Data Freshness | <15 min | >30 min |
| ETL Success Rate | 100% | <95% |
| Data Quality Score | >98% | <95% |
| Failed Records | <0.1% | >0.5% |
| Query Performance | <5 sec | >10 sec |

### Health Check Query
```sql
SELECT 
    source_system,
    source_table,
    MAX(load_ts) as last_load,
    DATEDIFF(minute, MAX(load_ts), GETDATE()) as minutes_stale,
    COUNT(*) as record_count,
    CAST(COUNT(*) FILTER (WHERE dw_hash IS NOT NULL) * 100.0 / COUNT(*) AS DECIMAL(5,2)) 
        as quality_score_pct
FROM stg_orders
GROUP BY source_system, source_table;
```

---

## Implementation Timeline

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| **Phase 1: Foundation** | 4 weeks | Database setup, master data, fact loading |
| **Phase 2: Expansion** | 4 weeks | All sources integrated, data quality monitoring |
| **Phase 3: Optimization** | 4 weeks | Performance tuning, BI layer, data marts |
| **Phase 4: Advanced** | 4 weeks | Predictive models, streaming, GoLive |

---

## Useful Links

- [ER_DIAGRAMS.md](./ER_DIAGRAMS.md) - Visual database architecture
- [SCHEMA_DESIGN_GUIDE.md](./SCHEMA_DESIGN_GUIDE.md) - Detailed design patterns
- [ETL_MAPPING_GUIDE.md](./ETL_MAPPING_GUIDE.md) - Source-to-target mappings
- [IMPLEMENTATION_ROADMAP.md](./IMPLEMENTATION_ROADMAP.md) - Week-by-week implementation plan

---

## Contact & Support

For implementation support or questions:
1. Review the comprehensive guides listed above
2. Check the relevant SQL schema files
3. Reference the ER diagrams for relationships
4. Consult the implementation roadmap for timeline

---

*Last Updated: 2026-05-18*  
*Version: 1.0*
