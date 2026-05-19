-- ============================================================
-- KPI REFERENCE & CALCULATION SPECIFICATIONS
-- ============================================================
-- Complete KPI definitions, formulas, targets, and calculations
-- Updated: 2024-01-15
-- ============================================================

/*
ENTERPRISE KPI PLATFORM - KPI SPECIFICATIONS
==============================================

This document defines all 32+ KPIs with:
  - Business definitions
  - Mathematical formulas
  - Data sources
  - Calculation intervals
  - Target thresholds
  - Status indicators (Green/Yellow/Red)

*/

-- ============================================================
-- FINANCIAL KPIs (Profitability, Revenue, Margins)
-- ============================================================

/*
1. TOTAL REVENUE
   Definition: Sum of all net sales revenue for the period
   Formula: SUM(Order.NetAmount) for period
   Source: fact_sales, fact_revenue
   Frequency: Daily, Weekly, Monthly, Quarterly, YTD, Annual
   Target: Growth from prior period
   Status Thresholds: Green >= Target, Yellow >= 90% Target, Red < 90%
   
   SQL View: vw_kpi_financial_summary
   Business Impact: Core revenue metric for stakeholder reporting
*/

SELECT 
    'Total Revenue' AS KPI,
    'SUM of all net sales amounts' AS Definition,
    'Daily, Weekly, Monthly, YTD' AS Frequency,
    'Previous period comparison' AS Target,
    'Financial > Operations > Sales' AS Hierarchy;

/*
2. REVENUE BY SEGMENT
   Definition: Revenue broken down by customer segment (A, B, C, D)
   Formula: SUM(Order.NetAmount) WHERE Customer.Segment = 'X'
   Source: fact_revenue INNER JOIN dim_customer
   Segments: 
     - Segment A: Enterprise (ACVs >$500K)
     - Segment B: Mid-market (ACVs $100K-$500K)
     - Segment C: SMB (ACVs $10K-$100K)
     - Segment D: Other (ACVs <$10K)
   Frequency: Daily, Monthly
   Target: 40% from A, 35% from B, 20% from C, 5% from D
   
   Business Impact: Product mix and market positioning
*/

/*
3. GROSS PROFIT MARGIN (%)
   Definition: Profitability after direct product costs
   Formula: ((Total Revenue - Total COGS) / Total Revenue) * 100
   Components:
     - Total Revenue: SUM(net_amount)
     - COGS: SUM(product_cost + freight_cost + duty_cost)
   Source: fact_revenue, fact_sales
   Target: >= 45%
   Thresholds: Green >= 45%, Yellow >= 40%, Red < 40%
   Frequency: Daily, Weekly, Monthly
   
   Variance Analysis:
     - Product margin variance (price vs cost changes)
     - Freight cost variance (logistics efficiency)
     - Duty/tax variance (compliance tracking)
   
   Business Impact: Core profitability indicator, pricing strategy
*/

SELECT 
    'Gross Profit Margin %' AS KPI,
    'ROUND(SUM(gross_profit) / SUM(net_revenue) * 100, 2)' AS Formula,
    '45%' AS Target,
    'Green: >=45%, Yellow: >=40%, Red: <40%' AS Thresholds;

/*
4. OPERATING MARGIN (%)
   Definition: Profitability after operating expenses
   Formula: ((Gross Profit - Operating Expenses) / Revenue) * 100
   Components:
     - Gross Profit: Revenue - COGS
     - Operating Expenses: Freight, Duty, Handling
   Target: >= 25%
   Thresholds: Green >= 25%, Yellow >= 20%, Red < 20%
   Frequency: Monthly
   
   Business Impact: Operational efficiency, cost control
*/

/*
5. NET PROFIT MARGIN (%)
   Definition: Final profitability after all expenses
   Formula: (Net Income / Total Revenue) * 100
   Target: >= 15%
   Thresholds: Green >= 15%, Yellow >= 10%, Red < 10%
   Frequency: Monthly, Quarterly, Annual
*/

/*
6. EBITDA (Earnings Before Interest, Tax, Depreciation, Amortization)
   Definition: Operating profit before financing & tax items
   Formula: Operating Income + D&A
   Source: Financial GL accounts + calculated fields
   Target: Varies by company size
   Frequency: Quarterly, Annual
*/

-- ============================================================
-- SALES KPIs (Growth, Pipeline, Win Rates, CAC)
-- ============================================================

/*
7. SALES GROWTH RATE (YoY %)
   Definition: Year-over-year revenue growth percentage
   Formula: ((Current Year Revenue - Prior Year Revenue) / Prior Year Revenue) * 100
   
   Calculation:
     Current Year: SUM(fact_sales.net_amount) WHERE YEAR(order_date) = YEAR(GETDATE())
     Prior Year: SUM(fact_sales.net_amount) WHERE YEAR(order_date) = YEAR(GETDATE())-1
   
   Target: >= 20% growth YoY
   Thresholds: Green >= 20%, Yellow >= 10%, Red < 10%
   Frequency: Monthly, Quarterly, Annual
   
   Drill-down Analysis:
     - Growth by segment
     - Growth by product line
     - Growth by region
     - Growth by customer
   
   Business Impact: Strategic performance, market position
*/

SELECT
    'Sales Growth Rate (YoY)' AS KPI,
    'Measures year-over-year revenue expansion' AS Definition,
    '20% annual growth' AS Target,
    'Green: >=20%, Yellow: >=10%, Red: <10%' AS Thresholds,
    'vw_kpi_sales_summary' AS ViewName;

/*
8. WIN RATE (%)
   Definition: Percentage of sales opportunities that close as won
   Formula: (Closed Won / Total Closed) * 100
   
   Calculation:
     Closed Won: COUNT(opportunity) WHERE is_won = 1 
                 AND close_date BETWEEN period_start AND period_end
     Total Closed: COUNT(opportunity) WHERE close_date BETWEEN period_start AND period_end
   
   Target: >= 30%
   Thresholds: Green >= 30%, Yellow >= 25%, Red < 25%
   Frequency: Daily, Weekly, Monthly
   Source: stg_opportunities_conformed
   
   Factors:
     - Sales rep skill/experience
     - Territory size
     - Deal complexity
     - Competition
   
   Business Impact: Sales team effectiveness, pipeline quality
*/

/*
9. SALES CYCLE LENGTH (Days)
   Definition: Average number of days from opportunity creation to close
   Formula: AVG(close_date - created_date) for won opportunities
   
   Calculation:
     SELECT AVG(DATEDIFF(DAY, created_date, close_date))
     FROM stg_opportunities_conformed
     WHERE is_won = 1
   
   Target: <= 60 days
   Thresholds: Green <= 60, Yellow <= 75, Red > 75
   Frequency: Monthly, Quarterly
   Source: stg_opportunities_conformed
   
   Variance Drivers:
     - Deal size (larger deals take longer)
     - Product complexity
     - Customer decision-making process
     - Competitive pressure
   
   Business Impact: Cash flow timing, forecast accuracy, sales efficiency
*/

/*
10. PIPELINE VALUE (USD)
    Definition: Total value of open opportunities in pipeline
    Formula: SUM(opportunity_amount * (probability / 100))
    
    Pipeline Stages:
      - Prospecting: 10% probability
      - Qualification: 25% probability
      - Proposal: 50% probability
      - Negotiation: 75% probability
      - Evaluation: 60% probability
    
    Calculation:
      SELECT SUM(amount * (probability / 100)) 
      FROM stg_opportunities_conformed 
      WHERE is_won = 0 AND is_lost = 0
    
    Target: >= 3x quarterly quota
    Frequency: Daily, Weekly
    
    Health Checks:
      - Pipeline fill ratio (pipeline / quota)
      - Velocity (stage progression speed)
      - Conversion rates by stage
*/

/*
11. NEW CUSTOMERS ACQUIRED (MTD/YTD)
    Definition: Count of new customers added in period
    Formula: COUNT(DISTINCT customer_key) WHERE effective_date IN period
    
    Calculation:
      SELECT COUNT(DISTINCT customer_key)
      FROM dim_customer
      WHERE MONTH(effective_date) = MONTH(GETDATE())
      AND YEAR(effective_date) = YEAR(GETDATE())
    
    Target: >= 50 per month
    Frequency: Daily, Monthly
    Source: dim_customer
    
    Breakdown:
      - By acquisition channel (direct, partner, channel)
      - By customer segment
      - By geography
      - By product
    
    Business Impact: Market penetration, growth engine
*/

/*
12. CUSTOMER ACQUISITION COST (CAC) (USD)
    Definition: Average cost to acquire one new customer
    Formula: Total Sales & Marketing Spend / New Customers Acquired
    
    Simplified Calculation (using revenue proxy):
      SELECT SUM(total_net_revenue) * 0.15 / COUNT(DISTINCT customer_key)
      FROM fact_revenue fr
      LEFT JOIN dim_customer dc ON fr.customer_key = dc.customer_key
      WHERE dc.effective_date >= DATEADD(MONTH, -1, GETDATE())
      -- Assumes 15% of revenue goes to S&M for new customer acquisition
    
    Target: < $2,000 per customer
    Frequency: Monthly
    
    Payback Analysis:
      - Payback Period = CAC / (Monthly ARPU * Gross Margin %)
      - Acceptable payback: <= 12 months
    
    Business Impact: Sustainable growth, profitability timeline
*/

/*
13. SALES PER REP (USD)
    Definition: Average revenue generated per sales representative
    Formula: Total Sales / Number of Active Sales Reps
    
    Calculation:
      SELECT SUM(fs.net_amount) / COUNT(DISTINCT dteam.owner_id)
      FROM fact_sales fs
      LEFT JOIN dim_employee dteam ON fs.sales_rep_key = dteam.employee_key
    
    Target: >= $500K per rep per year
    Frequency: Monthly, Quarterly, Annual
    
    Productivity Factors:
      - Ramp time (new reps)
      - Territory potential
      - Product mix
      - Experience level
    
    Business Impact: Sales force capacity planning, efficiency
*/

-- ============================================================
-- CUSTOMER SUCCESS KPIs (Retention, Satisfaction, Health)
-- ============================================================

/*
14. CUSTOMER RETENTION RATE (%)
    Definition: Percentage of customers retained from prior period
    Formula: (Customers at End of Period - New Customers) / Customers at Start * 100
    
    Calculation (Monthly):
      Customers Start of Month: dim_customer WHERE is_current = 1 
                                AND effective_date <= month_start
      Customers End of Month: dim_customer WHERE is_current = 1 
                              AND effective_date <= month_end
      New Customers: dim_customer WHERE effective_date BETWEEN month_start AND month_end
      
      Retention = ((End - New) / Start) * 100
    
    Target: >= 95%
    Thresholds: Green >= 95%, Yellow >= 90%, Red < 90%
    Frequency: Monthly, Quarterly
    
    Causes of Churn:
      - Support quality
      - Product fit
      - Competitive pressure
      - Budget cuts (customer side)
      - Consolidation
    
    Business Impact: Revenue stability, lifetime value, growth
*/

/*
15. CHURN RATE (%)
    Definition: Percentage of customers lost in period
    Formula: Lost Customers / Starting Customers * 100
    
    Inverse: Churn Rate = 100 - Retention Rate
    
    Calculation:
      SELECT COUNT(CASE WHEN subscription_status = 'Churned' THEN 1 END) * 100.0 /
             COUNT(*) 
      FROM dim_customer 
      WHERE is_current = 1 
      AND MONTH(effective_date) = MONTH(GETDATE())
    
    Target: <= 5% monthly (60% annual retention)
    Thresholds: Green <= 5%, Yellow <= 7%, Red > 7%
    Frequency: Monthly, Quarterly
    
    Churn Classification:
      - Voluntary churn (customer choice)
      - Involuntary churn (failed payment, support issues)
      - Downgrade churn (moving to lower tier)
    
    Business Impact: Core metric for SaaS/subscription models
*/

/*
16. NET REVENUE RETENTION (NRR) (%)
    Definition: Expansion revenue from existing customers (includes upsell/cross-sell)
    Formula: (Month N Revenue from Cohort - Month 0 Revenue from Cohort) / Month 0 Revenue
    
    Cohort Analysis:
      - Month 0 Revenue: Customers' revenue in month signed up
      - Month N Revenue: Same customers' revenue N months later
      - Includes: Expansion, contraction, churn effects
    
    Target: >= 110% (showing strong expansion)
    Thresholds: Green >= 110%, Yellow >= 100%, Red < 100%
    Frequency: Monthly, Quarterly
    
    Components:
      - Organic Retention: Revenue from retained customers (no change)
      - Expansion Revenue: Upsells, cross-sells, higher tier moves
      - Contraction Revenue: Downgrades, feature removal
      - Churn Revenue: Lost from churned customers
    
    Business Impact: Efficiency of growth engine, product-market fit
*/

/*
17. CUSTOMER SATISFACTION (CSAT) (Score 0-5)
    Definition: Customer satisfaction with products/services
    Formula: AVG(satisfaction_rating) from surveys/interactions
    
    Calculation:
      SELECT ROUND(AVG(satisfaction_score), 2)
      FROM dim_customer
      WHERE is_current = 1 AND satisfaction_score > 0
    
    Target: >= 4.5
    Thresholds: Green >= 4.5, Yellow >= 4.0, Red < 4.0
    Frequency: Continuous (real-time as surveys collected)
    
    Measurement Methods:
      - Post-interaction surveys (1-5 scale)
      - Net Promoter Score (NPS) (-100 to +100)
      - Customer Effort Score (CES) (1-7 scale)
    
    Business Impact: Predictive of churn, brand health, referrals
*/

/*
18. SUPPORT RESOLUTION TIME (Minutes/Hours)
    Definition: Average time to resolve support tickets
    Formula: AVG(resolution_time) for all tickets in period
    
    Calculation:
      SELECT ROUND(AVG(interaction_duration_minutes), 1)
      FROM stg_customer_interactions_conformed
      WHERE interaction_type = 'Support'
      AND source_load_date >= DATEADD(DAY, -7, GETDATE())
    
    Target: < 24 hours (1,440 minutes)
    Thresholds: Green < 24h, Yellow < 48h, Red > 48h
    Frequency: Daily, Weekly
    
    Tier Analysis:
      - Critical Issues: < 1 hour
      - High Priority: < 4 hours
      - Normal: < 24 hours
      - Low Priority: < 5 days
    
    Business Impact: Customer satisfaction, retention, cost efficiency
*/

/*
19. PRODUCT USAGE RATE (%)
    Definition: % of active users using product features regularly
    Formula: Active Users / Licensed Users * 100
    
    Calculation:
      Active Users: Users with >0 interactions in last 30 days
      Licensed Users: Total users with active subscriptions
    
    Target: >= 70%
    Thresholds: Green >= 70%, Yellow >= 50%, Red < 50%
    Frequency: Weekly, Monthly
    
    Implications:
      - Usage < 30%: High churn risk
      - Usage 30-50%: Adoption issues
      - Usage 50-70%: Growing engagement
      - Usage > 70%: Healthy, expansion ready
    
    Business Impact: Expansion opportunities, churn prevention
*/

/*
20. CUSTOMER HEALTH SCORE (0-100)
    Definition: Composite metric predicting churn/expansion
    Formula: Weighted combination of:
      - Usage Score (40% weight): product_usage_rate
      - Engagement Score (30% weight): interaction_count / expected_baseline
      - Satisfaction Score (20% weight): csat_rating * 20
      - Account Growth (10% weight): (current_acv - prior_acv) / prior_acv
    
    Thresholds:
      - Green (70-100): Healthy, expansion ready
      - Yellow (40-70): At risk, needs attention
      - Red (0-40): High churn risk, intervention required
    
    Business Impact: Proactive account management, retention program
*/

-- ============================================================
-- OPERATIONAL KPIs (Fulfillment, Inventory, Quality, Efficiency)
-- ============================================================

/*
21. ORDER FULFILLMENT TIME (Days)
    Definition: Average days from order placement to delivery
    Formula: AVG(delivery_days) = AVG(actual_delivery_date - order_date)
    
    Calculation:
      SELECT ROUND(AVG(DATEDIFF(DAY, order_date, actual_delivery_date)), 1)
      FROM fact_sales
      WHERE load_date >= DATEADD(DAY, -30, GETDATE())
      AND actual_delivery_date IS NOT NULL
    
    Target: < 5 days
    Thresholds: Green <= 5, Yellow <= 7, Red > 7
    Frequency: Daily, Weekly, Monthly
    
    Factors:
      - Warehouse processing: 1 day
      - Packing/QC: 0.5 day
      - Logistics: 2-3 days
      - Customer delivery: 1-1.5 days
    
    Business Impact: Customer satisfaction, working capital efficiency
*/

/*
22. ON-TIME DELIVERY RATE (%)
    Definition: % of orders delivered by requested delivery date
    Formula: (On-Time Orders / Total Orders) * 100
    
    Calculation:
      SELECT ROUND(
          SUM(CASE WHEN on_time_delivery_flag = 1 THEN 1 ELSE 0 END) * 100.0 /
          COUNT(*), 2)
      FROM fact_sales
      WHERE load_date >= DATEADD(DAY, -30, GETDATE())
    
    Target: >= 95%
    Thresholds: Green >= 95%, Yellow >= 90%, Red < 90%
    Frequency: Daily, Weekly, Monthly
    
    Late Orders Analysis:
      - 1-3 days late: Acceptable variance
      - 3-7 days late: Investigation needed
      - >7 days late: Major issue
    
    Business Impact: Customer satisfaction, contractual compliance, SLA metrics
*/

/*
23. INVENTORY TURNOVER (Times per Year)
    Definition: How many times inventory is sold and replenished
    Formula: COGS / Average Inventory Value
    
    Calculation:
      SELECT ROUND(
          SUM(fs.order_quantity * dp.unit_price) / 
          AVG(fim.inventory_value), 2)
      FROM fact_sales fs
      LEFT JOIN dim_product dp ON fs.product_key = dp.product_key
      LEFT JOIN fact_inventory fim ON fs.product_key = fim.product_key
      WHERE fs.load_date >= DATEADD(MONTH, -12, GETDATE())
    
    Target: >= 6x per year (monthly inventory refresh)
    Thresholds: Green >= 6, Yellow >= 4, Red < 4
    Frequency: Monthly, Quarterly
    
    Interpretation:
      - High turnover: Efficient inventory, liquidity
      - Low turnover: Overstock, capital tie-up, obsolescence risk
      - By product: Vary targets by product lifecycle
    
    Business Impact: Working capital efficiency, cash conversion cycle
*/

/*
24. INVENTORY ACCURACY (%)
    Definition: % of physical inventory matches system records
    Formula: Accurate Count Locations / Total Locations * 100
    
    Target: >= 98%
    Thresholds: Green >= 98%, Yellow >= 95%, Red < 95%
    Frequency: Monthly (physical cycle counts), Continuous (system accuracy)
    
    Drivers:
      - Process discipline
      - System integration
      - Training quality
      - Technology accuracy
    
    Business Impact: Order fulfillment reliability, financial accuracy
*/

/*
25. OPERATIONAL EFFICIENCY RATIO (%)
    Definition: Operational expenses as % of revenue
    Formula: (Freight Cost + Duty Cost) / Total Revenue * 100
    
    Calculation:
      SELECT ROUND(
          (SUM(fr.total_freight_cost) + SUM(fr.total_duty_cost)) / 
          SUM(fr.total_net_revenue) * 100, 2)
      FROM fact_revenue fr
      WHERE fr.load_date >= DATEADD(DAY, -30, GETDATE())
    
    Target: <= 30%
    Thresholds: Green <= 30%, Yellow <= 35%, Red > 35%
    Frequency: Daily, Weekly, Monthly
    
    Cost Breakdown:
      - Inbound freight: 5-10%
      - Outbound/delivery: 10-15%
      - Duties/taxes: 2-5%
      - Handling/warehousing: 5-10%
    
    Business Impact: Profitability, competitive pricing, cost management
*/

/*
26. PROCESS COMPLIANCE (%)
    Definition: % of transactions following defined processes
    Formula: Compliant Transactions / Total Transactions * 100
    
    Compliance Checks:
      - Orders have all required fields
      - Pricing follows approval matrix
      - Delivery locations are valid
      - Customer credit verified
    
    Target: >= 98%
    Thresholds: Green >= 98%, Yellow >= 95%, Red < 95%
    Frequency: Daily, Weekly
    
    Business Impact: Risk management, audit readiness, control effectiveness
*/

/*
27. DEFECT RATE (%)
    Definition: % of units failing quality inspection
    Formula: (Units Failed QC / Units Produced) * 100
    
    Calculation:
      SELECT ROUND(
          SUM(CASE WHEN units_failed_qc > 0 THEN units_failed_qc ELSE 0 END) * 100.0 /
          SUM(units_produced), 2)
      FROM stg_production_quality_conformed
    
    Target: < 1%
    Thresholds: Green < 1%, Yellow < 2%, Red >= 2%
    Frequency: Daily, Batch-level
    Source: stg_production_quality_conformed
    
    Failure Modes:
      - Material defects
      - Assembly errors
      - Dimensional tolerance
      - Cosmetic damage
    
    Business Impact: Quality reputation, cost of quality, customer satisfaction
*/

/*
28. FIRST PASS YIELD (%)
    Definition: % of units passing QC on first inspection (no rework)
    Formula: (Units Passed First Time / Units Produced) * 100
    
    Calculation:
      SELECT ROUND(
          AVG(first_pass_yield_percent), 2)
      FROM stg_production_quality_conformed
    
    Target: > 99%
    Thresholds: Green > 99%, Yellow > 98%, Red <= 98%
    Frequency: Daily, Shift-level
    
    Business Impact: Cost reduction, on-time delivery, capacity utilization
*/

-- ============================================================
-- HR & STRATEGIC KPIs
-- ============================================================

/*
29. EMPLOYEE PRODUCTIVITY (Revenue per Employee)
    Definition: Annual revenue generated per employee
    Formula: Total Annual Revenue / Number of Employees
    
    Calculation:
      SELECT SUM(fs.net_amount) / COUNT(DISTINCT de.employee_key)
      FROM fact_sales fs
      LEFT JOIN dim_employee de
      WHERE YEAR(fs.order_date_key) = YEAR(GETDATE())
    
    Target: >= $500K per employee per year
    Thresholds: Green >= $500K, Yellow >= $400K, Red < $400K
    Frequency: Monthly, Quarterly, Annual
    
    Variation by Role:
      - Sales: $750K-1M per rep
      - Support: $300-400K per agent
      - Operations: $400-600K per specialist
    
    Business Impact: Headcount ROI, compensation benchmarking
*/

/*
30. EMPLOYEE ENGAGEMENT SCORE (0-100)
    Definition: Composite metric of employee satisfaction and engagement
    Formula: Weighted combination of:
      - Task completion rate (40%)
      - Attendance (20%)
      - Training participation (20%)
      - Manager rating (20%)
    
    Target: >= 75
    Frequency: Quarterly, Annual
    
    Business Impact: Retention, productivity, customer experience quality
*/

/*
31. TRAINING HOURS PER EMPLOYEE
    Definition: Average professional development hours per employee per year
    Formula: Total Training Hours / Number of Employees
    
    Target: >= 40 hours per employee per year
    Thresholds: Green >= 40, Yellow >= 20, Red < 20
    Frequency: Monthly, Quarterly, Annual
    
    Training Categories:
      - Product training
      - Skill development
      - Compliance training
      - Leadership development
    
    Business Impact: Capability development, retention, performance
*/

/*
32. EMPLOYEE TURNOVER RATE (%)
    Definition: % of employees leaving the organization
    Formula: (Employees Separated / Average Total Employees) * 100
    
    Target: < 10% annually
    Thresholds: Green < 10%, Yellow < 15%, Red >= 15%
    Frequency: Monthly, Quarterly, Annual
    
    Turnover Types:
      - Voluntary turnover: Resignation, retirement
      - Involuntary turnover: Termination, layoff
    
    Department Analysis:
      - Sales: Higher turnover (8-12% normal)
      - Support: Moderate turnover (12-15% normal)
      - Engineering: Lower turnover (5-8% normal)
    
    Business Impact: Organizational stability, recruitment costs, institutional knowledge
*/

/*
33. TIME TO FILL POSITIONS (Days)
    Definition: Average days to fill open positions
    Formula: AVG(hire_date - job_opened_date)
    
    Target: < 30 days
    Thresholds: Green < 30, Yellow < 45, Red >= 45
    Frequency: Monthly, Quarterly
    
    Factors:
      - Role seniority
      - Market conditions
      - Recruitment process efficiency
      - Geographic location
    
    Business Impact: Organizational continuity, cost per hire
*/

-- ============================================================
-- IMPLEMENTATION NOTES
-- ============================================================

/*
CALCULATION SCHEDULING:
  - Daily KPIs: Calculated post-ETL (8 AM, Noon, 6 PM)
  - Weekly KPIs: Calculated every Monday 8 AM
  - Monthly KPIs: Calculated on 1st of month 8 AM
  - Quarterly KPIs: Calculated 1st day of quarter 8 AM

DATA FRESHNESS:
  - Real-time KPIs: Updated within 15 minutes
  - Daily KPIs: Updated within 2 hours
  - Weekly KPIs: Updated within 4 hours
  - Monthly KPIs: Updated within 24 hours

ALERTING THRESHOLDS:
  - Red status KPIs: Alert immediately
  - Yellow status KPIs: Alert daily
  - Green status KPIs: No alert

DRILL-DOWN CAPABILITIES:
  All KPIs should support drill-down by:
    - Date (daily, weekly, monthly, quarterly, annual)
    - Geography (region, territory, country)
    - Customer Segment (A, B, C, D)
    - Product Line
    - Department/Team
    - Sales Rep/Employee

*/

PRINT 'KPI Reference Documentation Loaded';
GO
