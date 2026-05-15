# Source System List

## Overview
This document outlines all source systems feeding data into the Executive Decision Intelligence Platform.

## Source Systems Directory

### 1. Enterprise Resource Planning (ERP)

| Field | Details |
|-------|---------|
| **System Name** | SAP S/4HANA / Oracle EBS |
| **Data Categories** | Orders, Inventory, Purchase orders, Procurement |
| **Update Frequency** | Real-time (via APIs), Batch (nightly) |
| **Data Volume** | 100GB+ daily |
| **Connection Type** | Direct database, API, File exports |
| **Owner** | Finance/Operations |

### 2. Customer Relationship Management (CRM)

| Field | Details |
|-------|---------|
| **System Name** | Salesforce / Dynamics 365 |
| **Data Categories** | Customer profiles, Leads, Opportunities, Interactions |
| **Update Frequency** | Real-time sync every 15 minutes |
| **Data Volume** | 10GB+ daily |
| **Connection Type** | REST APIs, Webhooks |
| **Owner** | Sales/Marketing |

### 3. Financial Systems

| Field | Details |
|-------|---------|
| **System Name** | NetSuite / QuickBooks |
| **Data Categories** | P&L, GL accounts, AP/AR, Cash flow |
| **Update Frequency** | Batch - End of day |
| **Data Volume** | 5GB+ daily |
| **Connection Type** | SFTP, APIs, Direct export |
| **Owner** | Finance |

### 4. Human Resources Management System (HRMS)

| Field | Details |
|-------|---------|
| **System Name** | Workday / SuccessFactors |
| **Data Categories** | Employee data, Payroll, Performance, Attendance |
| **Update Frequency** | Batch - Weekly |
| **Data Volume** | 1GB+ weekly |
| **Connection Type** | APIs, Scheduled exports |
| **Owner** | HR |

### 5. Business Intelligence / Analytics

| Field | Details |
|-------|---------|
| **System Name** | Tableau Server / Power BI |
| **Data Categories** | User interactions, Report views, Dashboards used |
| **Update Frequency** | Real-time logging |
| **Data Volume** | 2GB+ daily |
| **Connection Type** | Event streaming, API logs |
| **Owner** | Analytics |

### 6. Operational Systems

| Field | Details |
|-------|---------|
| **System Name** | Custom Applications, IoT sensors |
| **Data Categories** | Production metrics, Quality data, Equipment status |
| **Update Frequency** | Real-time streams (every 5 mins) |
| **Data Volume** | 50GB+ daily |
| **Connection Type** | Message queues (Kafka/RabbitMQ), MQTT |
| **Owner** | Operations |

### 7. Marketing Automation

| Field | Details |
|-------|---------|
| **System Name** | HubSpot / Marketo |
| **Data Categories** | Campaigns, Email interactions, Web analytics |
| **Update Frequency** | Real-time |
| **Data Volume** | 15GB+ daily |
| **Connection Type** | APIs, Webhooks |
| **Owner** | Marketing |

### 8. Support/Ticketing System

| Field | Details |
|-------|---------|
| **System Name** | Jira / ServiceNow |
| **Data Categories** | Issues, Incidents, Resolutions, SLA metrics |
| **Update Frequency** | Real-time |
| **Data Volume** | 3GB+ daily |
| **Connection Type** | REST APIs |
| **Owner** | Support/Operations |

## Data Mapping Summary

| Source System | Target Staging Tables | Target Fact Tables |
|--------------|----------------------|-------------------|
| ERP | stg_orders, stg_inventory | fact_sales, fact_inventory |
| CRM | stg_customers, stg_opportunities | fact_customer_interactions |
| Finance | stg_transactions, stg_gl | fact_revenue, fact_expenses |
| HRMS | stg_employees, stg_payroll | fact_hr_metrics |
| BI Logs | stg_analytics_logs | fact_analytics_usage |
| Operations | stg_equipment, stg_production | fact_production_metrics |
| Marketing | stg_campaigns, stg_leads | fact_marketing_performance |
| Support | stg_tickets, stg_incidents | fact_support_metrics |

## Data Quality Checks

- **Completeness**: All mandatory fields populated
- **Accuracy**: Values within expected ranges
- **Timeliness**: Data arrival within SLA
- **Consistency**: Cross-source data validation
- **Uniqueness**: No duplicate records
