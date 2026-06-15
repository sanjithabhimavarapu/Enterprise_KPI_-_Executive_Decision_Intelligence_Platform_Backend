# Power BI Integration Setup Guide

## Overview
This guide walks through setting up Power BI to connect to the Enterprise KPI Data Warehouse for executive reporting and analytics.

---

## Prerequisites

- Power BI Desktop (latest version) or Power BI Service
- SQL Server credentials with read access to KPI_DataWarehouse
- Database connection details:
  - **Server**: Your SQL Server instance
  - **Database**: `KPI_DataWarehouse`
  - **Port**: 1433 (default)
  - **Authentication**: SQL Server or Azure AD

---

## Step 1: Configure Database Connection

### 1.1 In Power BI Desktop

1. Open **Power BI Desktop**
2. Click **Get Data** → **SQL Server**
3. Enter connection details:
   - **Server**: `your_server.database.windows.net` (for Azure SQL) or `your_server\SQLEXPRESS` (local)
   - **Database**: `KPI_DataWarehouse`
4. Click **OK**
5. Choose **Database** authentication
6. Enter credentials and click **Connect**

### 1.2 Connection String Format

For **Azure SQL Database**:
```
Server=tcp:your_server.database.windows.net,1433;
Database=KPI_DataWarehouse;
Encrypt=yes;
TrustServerCertificate=no;
Connection Timeout=30;
```

For **Local SQL Server**:
```
Server=.\SQLEXPRESS;
Database=KPI_DataWarehouse;
Trusted_Connection=yes;
```

---

## Step 2: Import Reporting Views

### 2.1 Available Views

The following optimized views are pre-built for Power BI consumption:

#### Executive Dashboard Views
| View Name | Purpose | Grain |
|-----------|---------|-------|
| `vw_daily_financial_summary` | Daily revenue, profit, margin metrics | Daily |
| `vw_monthly_financial_segment_summary` | Monthly financials by customer segment | Monthly/Segment |
| `vw_executive_kpi_dashboard` | Executive summary with KPI targets | Daily |
| `vw_financial_kpi_optimized` | Optimized financial KPI calculations | Daily |

#### Operational Views
| View Name | Purpose | Grain |
|-----------|---------|-------|
| `vw_employee_sales_performance` | Sales team performance metrics | Monthly/Employee |
| `vw_customer_revenue_analysis` | Customer profitability and trends | Monthly/Customer |
| `vw_inventory_kpi_summary` | Inventory turnover and health metrics | Daily |
| `vw_sla_operational_metrics` | Service level agreement compliance | Daily |

#### Data Quality Views
| View Name | Purpose | Grain |
|-----------|---------|-------|
| `vw_recent_orchestrations` | ETL pipeline execution status | Execution-level |
| `vw_data_quality_summary` | Data validation results | Daily |

### 2.2 Import Steps

1. In **Navigator** window (after database connection):
   - Check the box for desired views
   - **Recommended starting views**:
     - `vw_daily_financial_summary`
     - `vw_monthly_financial_segment_summary`
     - `vw_employee_sales_performance`
     - `vw_executive_kpi_dashboard`

2. Click **Load**

3. Power BI will import the data and create tables

---

## Step 3: Create Data Model Relationships

### 3.1 Auto-Detection

Most relationships should auto-detect based on foreign key constraints in the database. Verify in **Model** view:

- All dimension tables (dim_date, dim_customer, dim_employee, etc.) should link to fact tables
- Join columns should be clearly labeled

### 3.2 Manual Relationship Setup (if needed)

1. Go to **Model** view
2. Click **Manage Relationships**
3. For any missing links, create relationships:
   - From fact table to dimension table
   - Match on key columns (e.g., date_key, customer_key, employee_key)
   - Set relationship cardinality (typically 1:N)

---

## Step 4: Configure Automatic Refresh

### 4.1 In Power BI Desktop (Local Testing)

1. Click **File** → **Options and settings** → **Options**
2. Under **Load**, configure data refresh preferences
3. Set default behavior for handling large datasets

### 4.2 In Power BI Service (Production)

After publishing to Power BI Service:

1. Go to **My Workspace** → **Datasets**
2. Click **⋯** next to your dataset → **Settings**
3. Expand **Gateway and cloud connections**
4. Configure **Scheduled refresh**:
   - **Frequency**: Daily
   - **Time**: 03:00 (post-ETL completion at 02:00)
   - **Refresh frequency**: Daily (minimum recommended: every 6 hours)

### 4.3 Refresh Schedule Recommendations

| Data Type | Frequency | Time |
|-----------|-----------|------|
| Daily KPIs | Daily | 03:00 AM (after ETL) |
| Monthly Reports | Monthly | 1st of month, 04:00 AM |
| Operational Metrics | Every 6 hours | 03:00, 09:00, 15:00, 21:00 |

---

## Step 5: Build Initial Dashboards

### 5.1 Executive Dashboard

**Recommended Components**:

1. **KPI Cards** (from `vw_executive_kpi_dashboard`):
   - Revenue (month-to-date vs target)
   - Profit (month-to-date vs target)
   - Customer Count
   - Order Count

2. **Revenue Trend Line Chart**:
   - X-axis: Date
   - Y-axis: Daily Revenue
   - Legend: Year (to compare trends)

3. **Profitability Analysis**:
   - Stacked bar chart: Revenue, COGS, Profit by month
   - Data source: `vw_monthly_financial_segment_summary`

4. **Segment Performance Table**:
   - Rows: Customer Segment
   - Values: Revenue, Profit, Margin %, Customer Count
   - Filter: Date slicer for month selection

### 5.2 Operational Dashboard

**Recommended Components**:

1. **Employee Sales Leaderboard**:
   - Top 10 sales performers
   - Data: `vw_employee_sales_performance`
   - Columns: Employee, Total Sales, Profit, Deal Size

2. **Inventory Health KPIs**:
   - Inventory turnover ratio
   - Days inventory outstanding (DIO)
   - Data: `vw_inventory_kpi_summary`

3. **SLA Compliance Monitor**:
   - Service level achievement % (card visual)
   - Compliance trend (line chart)
   - Data: `vw_sla_operational_metrics`

### 5.3 Data Quality Dashboard

**Recommended Components**:

1. **ETL Pipeline Status**:
   - Recent pipeline executions
   - Success/Failure counts
   - Data: `vw_recent_orchestrations`

2. **Data Quality Metrics**:
   - Missing values %
   - Duplicate records
   - Data: `vw_data_quality_summary`

---

## Step 6: Apply Row-Level Security (RLS)

### 6.1 Enable RLS

1. In **Model** view, click **Manage Roles**
2. Create roles based on user responsibilities:
   - **Executive**: View all data
   - **Manager**: View own department/region
   - **Analyst**: View assigned customer segments

### 6.2 Create DAX Filters

Example - Regional Manager Role:

```dax
[Department] = USERNAME()
```

Example - Segment Analyst Role:

```dax
[Customer_Segment] IN ("Enterprise", "Mid-Market")
```

---

## Step 7: Publish to Power BI Service

### 7.1 Publishing Steps

1. In Power BI Desktop: Click **File** → **Publish**
2. Select workspace destination
3. Wait for deployment to complete
4. Click **Open in Power BI** to verify

### 7.2 Configure Service Settings

In Power BI Service:

1. Open published report
2. **Settings** ⚙️ → **Settings**
3. Configure:
   - **Data sensitivity label** (if using information protection)
   - **Featured content** (pin to workspace home)
   - **Sharing settings** (if needed)

---

## Step 8: Set Up Report Alerts & Subscriptions

### 8.1 Create Email Subscriptions

1. In Power BI Service, open report page with KPI card
2. Click ⋯ → **Subscribe**
3. Configure:
   - Recipients
   - Frequency (daily, weekly, monthly)
   - Specific filters if needed

### 8.2 Data Alerts

1. Click on KPI card/visual
2. Click ⋯ → **Alerts** (if available)
3. Set alert condition:
   - Alert when value exceeds threshold
   - Alert frequency

---

## Step 9: Performance Optimization

### 9.1 Enable Query Folding

In Power Query Editor:
- Review M formulas to ensure steps fold back to SQL
- Avoid custom functions that prevent folding
- Use native SQL functions when possible

### 9.2 Optimize Dataset Size

1. Remove unnecessary columns during import
2. Use appropriate data types (avoid text for numerics)
3. Consider using DirectQuery for very large tables (fact tables >1B rows)

### 9.3 Monitor Performance

In Power BI Desktop:
1. **View** → **Performance Analyzer**
2. Identify slow visuals
3. Optimize or use aggregations

In Power BI Service:
1. **Workspace** → **Premium metrics**
2. Monitor capacity usage
3. Identify bottlenecks

---

## Step 10: Share & Collaborate

### 10.1 Workspace Sharing

1. Go to workspace
2. **Access** → **Add members**
3. Assign roles:
   - **Admin**: Full control
   - **Member**: Create/edit content
   - **Contributor**: Edit only
   - **Viewer**: Read-only access

### 10.2 Report Sharing

1. Open report
2. **Share** → Configure permissions
3. Users get access to:
   - Report visuals
   - Underlying data (respects RLS)

---

## Troubleshooting

### Issue: "Unable to connect to database"

**Solutions**:
1. Verify database server is accessible
2. Check firewall rules allow SQL connection on port 1433
3. Confirm credentials have SELECT permissions
4. For Azure SQL: Check IP allowlist in firewall rules

### Issue: "Data refresh failed"

**Solutions**:
1. Check gateway status (Power BI Service)
2. Review refresh logs for errors
3. Verify credentials haven't expired
4. Check dataset size isn't exceeding capacity limits

### Issue: "Visuals loading very slowly"

**Solutions**:
1. Reduce query complexity
2. Add aggregation tables for common queries
3. Use DirectQuery for targeted visuals
4. Increase Power BI Premium capacity (if available)

### Issue: "Users seeing different data (RLS not working)"

**Solutions**:
1. Verify RLS roles are active
2. Test with specific user account
3. Check DAX formula syntax
4. Ensure USERNAME() function returns expected values

---

## Best Practices

- **Refresh Schedule**: Align with ETL completion (recommend 1 hour after ETL ends)
- **Incremental Refresh**: Enable for fact tables >100M rows
- **Data Models**: Keep model simple; use views for complex calculations
- **Performance**: Monitor dataset size; limit to <1GB for optimal performance
- **Security**: Always enable RLS for sensitive data
- **Documentation**: Add slicers and tooltips to explain metrics
- **Naming**: Use consistent naming conventions for measures and columns

---

## Support & Resources

- **SQL Views Documentation**: See `warehouse/01_optimized_reporting_views.sql`
- **KPI Definitions**: See `technical_docs/KPI_DEFINITIONS.md`
- **Data Dictionary**: See `data_dictionary/` folder
- **Power BI Documentation**: https://learn.microsoft.com/power-bi/

