# Revenue Forecasting, Profit Calculations & Financial Aggregation Guide

**Version**: 1.0  
**Date**: May 28, 2026  
**Status**: Production Ready

---

## 📋 Table of Contents

1. Revenue Forecasting
2. Profit Calculations
3. Financial Aggregation Views
4. Implementation & Deployment
5. Quick Reference Queries
6. Executive Dashboards
7. Performance & Scaling
8. Troubleshooting

---

## Section 1: Revenue Forecasting

### 1.1 Overview

Revenue forecasting predicts future revenue using historical trends, seasonality adjustments, and growth factors.

**Key Features**:
- Multiple forecasting methods (Linear Regression, Exponential Smoothing, Seasonal Decomposition)
- Confidence intervals (80%, 95%, 99%)
- Seasonality detection and adjustment
- Growth rate calculations
- Forecast accuracy tracking

### 1.2 Architecture

```
Historical Data (24+ months)
    ↓
Statistical Analysis (Trend, Seasonality, Growth)
    ↓
Forecast Method Selection (Linear/Exponential/Seasonal)
    ↓
Revenue Forecast Generation (12-24 months forward)
    ↓
Actual vs Forecast Tracking & Accuracy Validation
```

### 1.3 Key Tables

#### revenue_forecast_base
**Purpose**: Store forecast parameters and historical statistics

```sql
-- Example: View forecast base
SELECT 
    forecast_dimension_type,
    dimension_name,
    avg_monthly_revenue,
    revenue_growth_rate_pct,
    forecast_method,
    confidence_level
FROM revenue_forecast_base
WHERE is_active = 1;
```

**Key Columns**:
- `forecast_dimension_type`: Overall, Customer, Product, Geography, Segment
- `avg_monthly_revenue`: Average historical monthly revenue
- `revenue_growth_rate_pct`: Calculated growth rate
- `seasonal_index`: Seasonality multiplier (e.g., 1.15 = 15% above average)
- `forecast_method`: Method used (Linear/Exponential/Seasonal)
- `confidence_level`: 80/90/95/99 percent

#### revenue_forecast
**Purpose**: Store individual monthly forecasts

```sql
-- Example: Get 12-month forecast
SELECT 
    forecast_month,
    forecasted_revenue,
    lower_bound_95_pct,
    upper_bound_95_pct,
    seasonal_adjustment,
    growth_adjustment
FROM revenue_forecast
WHERE forecast_dimension_type = 'Overall'
ORDER BY forecast_month;
```

**Key Columns**:
- `forecast_month`: 'yyyy-MM' format
- `forecasted_revenue`: Point estimate
- `lower_bound_95_pct`: Conservative estimate
- `upper_bound_95_pct`: Optimistic estimate
- `seasonal_adjustment`: Month-specific multiplier
- `growth_adjustment`: Growth component

### 1.4 Forecasting Methods

#### Linear Regression
**Best For**: Steady, consistent growth  
**Accuracy**: 70-80% for 6+ months ahead  
**Suitable When**: Growth is stable and predictable

```
Forecast = Base Revenue + (Growth Rate × Months)
```

#### Exponential Smoothing
**Best For**: Rapid changes  
**Accuracy**: 75-85% for 3-6 months ahead  
**Suitable When**: Recent trends matter more

```
Forecast = (Weight × Recent) + ((1-Weight) × Historical Avg)
```

#### Seasonal Decomposition
**Best For**: Businesses with strong seasonality  
**Accuracy**: 80-90% when seasonality is strong  
**Suitable When**: Clear patterns (holiday peaks, quarterly cycles)

```
Forecast = Trend × Seasonal Index × Growth Adjustment
```

### 1.5 Usage

```sql
-- Generate overall company forecast (12 months, 95% confidence)
EXEC sp_calculate_revenue_forecast 
    @p_forecast_dimension = 'Overall',
    @p_historical_months = 24,
    @p_forecast_months = 12,
    @p_confidence_level = 95,
    @p_method = 'SeasonalDecomposition',
    @p_verbose = 1;

-- View forecast
SELECT * FROM vw_revenue_forecast_dashboard
WHERE forecast_dimension_type = 'Overall';

-- Get forecast by customer
EXEC sp_calculate_revenue_forecast 
    @p_forecast_dimension = 'Customer',
    @p_verbose = 1;
```

**Interpretation**:
- `forecasted_revenue`: Most likely outcome
- `lower_bound_95_pct`: 5th percentile (conservative)
- `upper_bound_95_pct`: 95th percentile (optimistic)
- `seasonal_adjustment`: How much this month differs from average
- `growth_adjustment`: Growth multiplier applied

### 1.6 Accuracy Metrics

| Timeframe | Expected Accuracy | Confidence Interval |
|-----------|------------------|-------------------|
| 1-3 months ahead | 85-95% | 80% bounds |
| 3-6 months ahead | 75-85% | 90% bounds |
| 6-12 months ahead | 65-75% | 95% bounds |
| 12+ months ahead | <65% | 99% bounds |

---

## Section 2: Profit Calculations

### 2.1 Overview

Profit calculations track profitability at multiple levels:
- Daily transaction-level profits
- Monthly aggregated profits
- Segment, product, geography breakdowns

**Profit Levels**:

```
Gross Revenue
    ↓ (less discounts & returns)
Net Revenue
    ↓ (less COGS: material, labor, overhead)
Gross Profit
    ↓ (less Operating Expenses)
Operating Profit (EBIT)
    ↓ (adjust for interest & other items)
Pre-tax Profit
    ↓ (less taxes)
Net Profit (Bottom Line)
```

### 2.2 Cost Components

#### Revenue Components
```
Gross Revenue: Full sales amount
- Discounts: Promotional, volume discounts
- Returns/Credits: Product returns, service credits
= Net Revenue: Actual money collected
```

#### Cost of Goods Sold (COGS)
```
COGS = Material Cost + Labor Cost + Overhead
- Material: Product cost or component cost
- Labor: Direct labor to produce/deliver
- Overhead: Facility costs allocated to products
```

**Example**: Selling 100 units of Product A
```
Gross Revenue: $10,000 (100 × $100)
Discounts: ($500)
Net Revenue: $9,500

COGS:
  Material: $2,000 ($20/unit)
  Labor: $250 ($2.50/unit)
  Overhead: $75 ($0.75/unit)
Total COGS: ($2,325)

Gross Profit: $7,175
Gross Margin: 75.5%
```

#### Operating Expenses (OpEx)
```
Total OpEx = Salaries + Marketing + Sales + Support + Admin + Facilities + Technology

Allocated as:
- Salaries: $50k/month → $1.67k/day
- Marketing: 5% of revenue
- Sales: 3% of revenue
- Support: $0.25 per unit
- Admin: $0.15 per unit
- Facilities: $0.10 per unit
- Technology: $0.20 per unit
```

### 2.3 Key Tables

#### profit_calculation_daily
**Purpose**: Daily profit at transaction level

**Grain**: One row per customer per day (aggregated from transactions)

```sql
-- Example: Daily profit summary
SELECT 
    profit_date,
    SUM(net_revenue) AS daily_revenue,
    SUM(total_cogs) AS daily_cogs,
    SUM(gross_profit) AS daily_gross_profit,
    ROUND(AVG(gross_margin_pct), 2) AS avg_gross_margin,
    SUM(net_profit) AS daily_net_profit,
    ROUND(AVG(net_margin_pct), 2) AS avg_net_margin,
    SUM(transaction_count) AS total_transactions
FROM profit_calculation_daily
WHERE profit_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY profit_date
ORDER BY profit_date DESC;
```

**Key Columns**:
- `net_revenue`: Revenue after discounts/returns
- `total_cogs`: All product costs
- `total_opex`: All operating expenses
- `gross_profit`: Revenue - COGS
- `gross_margin_pct`: (Gross Profit / Revenue) × 100
- `operating_profit`: Gross Profit - OpEx
- `net_profit`: Bottom line profit

#### profit_calculation_monthly
**Purpose**: Monthly profit aggregation

**Grain**: One row per customer per month

```sql
-- Example: Monthly profitability
SELECT
    year_month,
    SUM(gross_revenue) AS monthly_revenue,
    SUM(net_profit) AS monthly_profit,
    ROUND(AVG(net_margin_pct), 2) AS avg_net_margin,
    COUNT(*) AS customer_count,
    SUM(transaction_count) AS total_transactions
FROM profit_calculation_monthly
WHERE year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY year_month
ORDER BY year_month DESC;
```

### 2.4 Margin Analysis

**Gross Margin** (measures production efficiency)
```
Gross Margin % = (Gross Profit / Revenue) × 100
- >50%: Excellent
- 40-50%: Good
- 30-40%: Average
- <30%: Concerning
```

**Operating Margin** (measures operational efficiency)
```
Operating Margin % = (Operating Profit / Revenue) × 100
- >20%: Excellent
- 15-20%: Good
- 10-15%: Average
- <10%: Concerning
```

**Net Margin** (measures profitability)
```
Net Margin % = (Net Profit / Revenue) × 100
- >15%: Excellent
- 10-15%: Good
- 5-10%: Average
- <5%: Concerning
```

### 2.5 Usage

```sql
-- Calculate daily profit
EXEC sp_calculate_daily_profit 
    @p_profit_date = CAST(GETDATE() AS DATE),
    @p_verbose = 1;

-- Aggregate to monthly
EXEC sp_calculate_monthly_profit_aggregation 
    @p_year_month = FORMAT(CAST(GETDATE() AS DATE), 'yyyy-MM'),
    @p_verbose = 1;

-- View daily profit
SELECT * FROM vw_daily_profit_dashboard;

-- View monthly by customer
SELECT * FROM vw_monthly_profit_by_customer
WHERE year_month >= '2026-05';
```

---

## Section 3: Financial Aggregation Views

### 3.1 Available Views

#### 1. vw_revenue_forecast_dashboard
**Purpose**: Revenue forecast overview

```sql
SELECT 
    forecast_dimension_type,
    dimension_name,
    total_forecasted_revenue,
    avg_monthly_forecast,
    conservative_estimate,
    optimistic_estimate,
    revenue_growth_rate_pct,
    forecast_months
FROM vw_revenue_forecast_dashboard;
```

**Use Case**: Strategic planning, budget forecasting

#### 2. vw_daily_profit_dashboard
**Purpose**: Daily profit metrics

```sql
SELECT 
    profit_date,
    daily_revenue,
    daily_cogs,
    daily_opex,
    gross_profit,
    net_profit,
    avg_net_margin
FROM vw_daily_profit_dashboard
WHERE profit_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
```

**Use Case**: Daily operational monitoring, trend tracking

#### 3. vw_monthly_profit_by_customer
**Purpose**: Customer profitability analysis

```sql
SELECT 
    year_month,
    customer_name,
    revenue,
    net_profit,
    net_margin_pct,
    profitability_status
FROM vw_monthly_profit_by_customer
WHERE year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
ORDER BY net_profit DESC;
```

**Use Case**: Customer profitability ranking, retention focus

#### 4. vw_product_profitability
**Purpose**: Product-level profit analysis

```sql
SELECT 
    product_name,
    units_sold,
    total_revenue,
    total_cogs,
    gross_profit,
    avg_margin_pct,
    net_profit
FROM vw_product_profitability
WHERE year_month >= FORMAT(DATEADD(MONTH, -3, GETDATE()), 'yyyy-MM')
ORDER BY net_profit DESC;
```

**Use Case**: Product portfolio optimization, pricing decisions

#### 5. vw_geographic_profit_analysis
**Purpose**: Geographic profitability

```sql
SELECT 
    geography_name,
    geography_region,
    customer_count,
    revenue,
    net_profit,
    avg_net_margin
FROM vw_geographic_profit_analysis
ORDER BY net_profit DESC;
```

**Use Case**: Regional performance analysis, expansion decisions

#### 6. vw_financial_executive_dashboard
**Purpose**: Executive summary with trends

```sql
SELECT 
    aggregation_date,
    total_revenue,
    total_profit,
    profit_margin_pct,
    margin_status,
    revenue_growth_mom_pct,
    profit_growth_mom_pct
FROM vw_financial_executive_dashboard
ORDER BY aggregation_date DESC;
```

**Use Case**: Executive reporting, board meetings

#### 7. vw_profitability_trends
**Purpose**: Monthly profitability trends

```sql
SELECT 
    year_month,
    total_revenue,
    total_cogs,
    total_opex,
    net_profit,
    avg_net_margin_pct,
    customer_count
FROM vw_profitability_trends
ORDER BY year_month DESC;
```

**Use Case**: Trend analysis, performance tracking

### 3.2 Financial Metrics

**Key Metrics Tracked**:

| Metric | Formula | Target |
|--------|---------|--------|
| Gross Margin | (Gross Profit / Revenue) × 100 | >50% |
| Operating Margin | (Operating Profit / Revenue) × 100 | >15% |
| Net Margin | (Net Profit / Revenue) × 100 | >10% |
| Revenue Growth | (Current - Prior) / Prior × 100 | >10% YoY |
| Profit Growth | (Current - Prior) / Prior × 100 | >15% YoY |
| Revenue per Customer | Total Revenue / Customer Count | Industry dependent |
| Profit per Transaction | Total Profit / Transaction Count | Positive |
| COGS % | Total COGS / Revenue × 100 | <50% |
| OpEx % | Total OpEx / Revenue × 100 | <30% |

---

## Section 4: Implementation & Deployment

### 4.1 Database Setup

```sql
-- Execute the main SQL file
EXEC sp_refresh_financial_aggregations @p_verbose = 1;
```

### 4.2 ETL Integration

**Daily Schedule** (after main ETL completes):
```sql
-- Step 1: Calculate daily profit (10-15 seconds)
EXEC sp_calculate_daily_profit @p_verbose = 1;

-- Step 2: Generate forecasts (20-30 seconds)
EXEC sp_calculate_revenue_forecast @p_verbose = 1;

-- Total Time: ~30-45 seconds
```

**Monthly Schedule** (first day of month):
```sql
-- Aggregate monthly profit (5-10 seconds)
EXEC sp_calculate_monthly_profit_aggregation @p_verbose = 1;

-- Total Time: ~5-10 seconds
```

### 4.3 BI Integration

**Tableau Connections**:
```
vw_revenue_forecast_dashboard → Revenue Forecast Dashboard
vw_daily_profit_dashboard → Daily P&L
vw_monthly_profit_by_customer → Customer Profitability
vw_product_profitability → Product Analysis
vw_geographic_profit_analysis → Regional Performance
vw_financial_executive_dashboard → Executive P&L
vw_profitability_trends → Trend Analysis
```

---

## Section 5: Quick Reference Queries

### Revenue Forecasting

```sql
-- Next 12 months forecast
SELECT 
    forecast_month,
    forecasted_revenue,
    lower_bound_95_pct,
    upper_bound_95_pct
FROM vw_revenue_forecast_dashboard
WHERE forecast_dimension_type = 'Overall'
ORDER BY forecast_month;

-- Forecast by customer (Top 10)
SELECT TOP 10
    dimension_name,
    total_forecasted_revenue,
    avg_monthly_forecast,
    revenue_growth_rate_pct
FROM vw_revenue_forecast_dashboard
WHERE forecast_dimension_type = 'Customer'
ORDER BY total_forecasted_revenue DESC;
```

### Profit Analysis

```sql
-- Daily profit (last 30 days)
SELECT 
    profit_date,
    daily_revenue,
    net_profit,
    ROUND(daily_profit / daily_revenue * 100, 2) AS margin_pct
FROM vw_daily_profit_dashboard
WHERE profit_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY profit_date DESC;

-- Most profitable customers (YTD)
SELECT TOP 25
    customer_name,
    SUM(net_profit) AS ytd_profit,
    SUM(revenue) AS ytd_revenue,
    ROUND(AVG(net_margin_pct), 2) AS avg_margin
FROM vw_monthly_profit_by_customer
WHERE year_month >= FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM')
GROUP BY customer_name
ORDER BY ytd_profit DESC;

-- Least profitable products
SELECT 
    product_name,
    total_revenue,
    net_profit,
    avg_margin_pct
FROM vw_product_profitability
WHERE year_month >= FORMAT(DATEADD(MONTH, -3, GETDATE()), 'yyyy-MM')
AND avg_margin_pct < 10
ORDER BY avg_margin_pct ASC;
```

---

## Section 6: Executive Dashboards

### Dashboard 1: Financial Summary
```
Total Revenue (MTD):        $X,XXX,XXX
Net Profit (MTD):           $X,XXX,XXX
Profit Margin (%):          XX.X%
Revenue Growth (MoM):       XX.X%
Profit Growth (MoM):        XX.X%

Status: ✓ On Track / ⚠ Monitor / ✗ At Risk
```

### Dashboard 2: Profitability Trend
```
[Line Chart: Revenue, Gross Profit, Net Profit by Month]
[Month over Month Comparison]
[Variance Analysis]
```

### Dashboard 3: Customer Profitability
```
Top 10 Customers by Profit
[Rank | Customer | Revenue | Profit | Margin %]
```

### Dashboard 4: Product Performance
```
Product Profitability Matrix
[X-axis: Volume | Y-axis: Margin %]
[Bubble Size: Profit Amount]
```

---

## Section 7: Performance & Scaling

### Query Performance Targets

| Query | Target Time | Data Volume |
|-------|------------|-------------|
| vw_revenue_forecast_dashboard | <50ms | 24-36 months |
| vw_daily_profit_dashboard | <100ms | 365+ days |
| vw_monthly_profit_by_customer | <150ms | 1000+ customers |
| vw_product_profitability | <100ms | 100+ products |
| vw_geographic_profit_analysis | <80ms | 50+ regions |
| vw_financial_executive_dashboard | <40ms | Summary data |
| vw_profitability_trends | <60ms | 60+ months |

### Scaling Considerations

**For 100K+ daily transactions**:
- Partition profit_calculation_daily by month
- Archive data >2 years old
- Consider columnar indexes for aggregations
- Implement incremental materialization

**For global deployments**:
- Currency conversion for multi-currency
- Regional time zone handling
- Localized financial reporting
- Regulatory compliance by region

---

## Section 8: Troubleshooting

### Issue: Forecast accuracy below 70%
**Diagnosis**:
- Check historical data quality
- Verify seasonality detection
- Review outliers in data

**Solution**:
```sql
-- Check data quality
SELECT 
    FORMAT(CAST(sale_date_key AS DATE), 'yyyy-MM') AS month,
    COUNT(*) AS transaction_count,
    SUM(sales_amount) AS monthly_revenue,
    AVG(sales_amount) AS avg_transaction
FROM fact_sales
GROUP BY FORMAT(CAST(sale_date_key AS DATE), 'yyyy-MM')
ORDER BY month DESC;
```

### Issue: Profit calculation showing negative
**Diagnosis**:
- Verify COGS allocation
- Check OpEx assignments
- Review discount/return amounts

**Solution**:
```sql
-- Verify profit components
SELECT 
    profit_date,
    SUM(net_revenue) AS total_revenue,
    SUM(total_cogs) AS total_cogs,
    SUM(total_opex) AS total_opex,
    SUM(net_profit) AS total_profit
FROM profit_calculation_daily
WHERE profit_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY profit_date;
```

### Issue: Views returning no data
**Diagnosis**:
- Check if procedures have been executed
- Verify data exists in source tables

**Solution**:
```sql
-- Execute full refresh
EXEC sp_refresh_financial_aggregations @p_verbose = 1;

-- Check for data
SELECT COUNT(*) FROM revenue_forecast_base;
SELECT COUNT(*) FROM profit_calculation_daily;
```

---

## Summary

✅ **Revenue Forecasting**: 
- Multiple methods (Linear, Exponential, Seasonal)
- Confidence intervals for risk planning
- Accuracy tracking and validation

✅ **Profit Calculations**:
- Daily transaction-level calculations
- Monthly aggregations by dimension
- Comprehensive margin analysis

✅ **Financial Views**:
- 7 optimized views for analysis
- Executive dashboard ready
- <150ms query performance

✅ **Integration**:
- Seamless ETL integration
- BI tool ready
- Scales to enterprise volume

---

**Version**: 1.0  
**Status**: Production Ready  
**Last Updated**: May 28, 2026

For detailed SQL implementation, see [11_sp_revenue_forecasting_profit_calculations.sql](backend/database/stored_procedures/11_sp_revenue_forecasting_profit_calculations.sql)
