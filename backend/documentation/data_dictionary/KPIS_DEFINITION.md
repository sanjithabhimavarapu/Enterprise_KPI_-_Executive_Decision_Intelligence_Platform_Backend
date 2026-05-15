# KPIs Definition

## Overview
This document defines all Key Performance Indicators (KPIs) tracked by the Executive Decision Intelligence Platform.

## Financial KPIs

### Revenue Metrics

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Total Revenue | Sum of all sales transactions | SUM(sales_amount) | YoY Growth 10%+ | Daily |
| Revenue by Segment | Sales revenue categorized by business segment | SUM(sales_amount) GROUP BY segment | By segment | Daily |
| Average Deal Size | Average value per sales transaction | AVG(deal_value) | $50K+ | Weekly |
| Contract Value | Total contracted revenue | SUM(contract_value) | Variance <5% | Monthly |

### Profitability Metrics

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Gross Profit Margin | (Revenue - COGS) / Revenue * 100 | (revenue - cogs) / revenue * 100 | 40%+ | Monthly |
| Operating Margin | EBIT / Revenue * 100 | ebit / revenue * 100 | 15%+ | Monthly |
| Net Profit Margin | Net Income / Revenue * 100 | net_income / revenue * 100 | 8%+ | Monthly |
| EBITDA | Earnings Before Interest, Tax, Depreciation | ebit + depreciation + amortization | Positive | Monthly |

## Sales KPIs

### Sales Performance

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Sales Growth Rate | Month-over-month/Year-over-year sales change | (Current Period Sales - Prior Period) / Prior Period * 100 | 5%+ MoM | Weekly |
| Win Rate | Percentage of deals won vs total closed | Deals Won / Total Deals Closed * 100 | 30%+ | Weekly |
| Sales Cycle Length | Days from first contact to close | AVG(close_date - first_contact_date) | <90 days | Monthly |
| Pipeline Value | Total value of open opportunities | SUM(opportunity_value WHERE status = 'Open') | >3x monthly quota | Weekly |

### Customer Acquisition

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| New Customers Acquired | Count of new customer contracts | COUNT(customers WHERE first_sale_date = current_month) | 50+ | Monthly |
| Customer Acquisition Cost (CAC) | Total sales/marketing spend / new customers | marketing_spend / new_customers | <$5K per customer | Monthly |
| Sales per Rep | Average revenue per sales representative | total_revenue / number_of_reps | $2M+ annually | Monthly |

## Customer Success KPIs

### Customer Health

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Customer Retention Rate | Percentage of customers retained | (Customers EOY - New Customers) / Customers BOY * 100 | 95%+ | Monthly |
| Customer Churn Rate | Percentage of customers lost | Customers Lost / Customers BOY * 100 | <5% | Monthly |
| Net Revenue Retention (NRR) | Revenue from existing customers + expansion / prior period revenue | (prior_revenue + expansion - churn) / prior_revenue * 100 | 110%+ | Quarterly |
| Customer Satisfaction Score (CSAT) | Customer satisfaction rating | AVG(customer_rating) | 4.5+/5.0 | Monthly |

### Customer Engagement

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Product Usage Rate | Percentage of features used by customers | active_users / total_licensed_users * 100 | 70%+ | Weekly |
| Support Ticket Resolution Time | Average time to resolve support tickets | AVG(resolution_date - creation_date) | <24 hours | Daily |
| Customer Health Score | Composite metric of engagement and satisfaction | (usage_score + satisfaction_score + support_sentiment) / 3 | 75+ | Weekly |

## Operational KPIs

### Efficiency Metrics

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Order Fulfillment Time | Days from order to delivery | AVG(delivery_date - order_date) | <5 days | Daily |
| Inventory Turnover | Number of times inventory is sold and replaced | COGS / avg_inventory | 6+ times/year | Monthly |
| Operational Efficiency Ratio | Operating expenses / revenue | opex / revenue | <30% | Monthly |
| Process Compliance Rate | Percentage of processes meeting standards | compliant_processes / total_processes * 100 | 98%+ | Monthly |

### Quality Metrics

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Defect Rate | Percentage of defective units | defective_units / total_units * 100 | <1% | Daily |
| First Pass Yield (FPY) | Percentage of products meeting quality on first attempt | units_passed_first_time / total_units * 100 | >99% | Daily |
| On-time Delivery Rate | Percentage of orders delivered on schedule | on_time_deliveries / total_deliveries * 100 | 95%+ | Daily |

## HR & Team KPIs

### Employee Performance

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Employee Productivity | Revenue/output per employee | total_revenue / headcount | $500K+ per employee | Monthly |
| Employee Engagement Score | Engagement survey results | survey_average_score | 3.5+/5.0 | Quarterly |
| Training Hours per Employee | Average training hours per employee | total_training_hours / headcount | 40+ hours/year | Quarterly |
| Promotion Rate | Percentage of employees promoted | promotions / headcount * 100 | 5%+ annually | Annual |

### Talent Management

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Employee Turnover Rate | Percentage of employees who left | employees_departed / avg_headcount * 100 | <10% annually | Monthly |
| Time to Fill | Days to fill open positions | AVG(hire_date - posting_date) | <30 days | Monthly |
| Voluntary vs Involuntary Turnover | Breakdown of departure reasons | voluntary_departures / involuntary_departures | 80/20 | Monthly |

## Strategic KPIs

### Market Position

| KPI Name | Definition | Formula | Target | Frequency |
|----------|-----------|---------|--------|-----------|
| Market Share | Percentage of total addressable market | company_revenue / total_market_revenue * 100 | Increase 2%+ | Quarterly |
| Brand Awareness | Percentage of target market aware of brand | survey_awareness / target_population * 100 | 60%+ | Annual |
| Competitive Win Rate | Percentage of deals won vs specific competitors | deals_won_vs_competitor / deals_competed * 100 | 40%+ | Quarterly |

## Dashboard Summary

All KPIs are tracked via real-time dashboards accessible to executives with the following views:
- Executive Dashboard: Top 10 KPIs
- Departmental Dashboards: Department-specific metrics
- Detailed Analytics: Drill-down views for deep analysis
- Historical Trends: Year-over-year and month-over-month comparisons
