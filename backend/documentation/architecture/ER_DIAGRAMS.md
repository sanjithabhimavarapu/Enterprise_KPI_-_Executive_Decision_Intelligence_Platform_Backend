# Entity-Relationship Diagrams - Enterprise KPI Platform

## Overview
This document contains all ER diagrams for the Enterprise KPI data warehouse, showing:
1. Core Star Schema for Sales Analytics
2. Customer Master Data Model
3. Time Dimensions (Date & Time)
4. Staging Layer Architecture
5. Complete Warehouse Architecture with all fact tables

---

## Diagram 1: Core Star Schema - Sales Analytics

```mermaid
erDiagram
    FACT_SALES ||--o{ DIM_CUSTOMER : references
    FACT_SALES ||--o{ DIM_PRODUCT : references
    FACT_SALES ||--o{ DIM_EMPLOYEE : references
    FACT_SALES ||--o{ DIM_GEOGRAPHY : references
    FACT_SALES ||--o{ DIM_DATE : "order_date"
    FACT_SALES ||--o{ DIM_DATE : "close_date"
    
    DIM_CUSTOMER {
        bigint customer_key PK
        string customer_id UK
        string customer_name
        string customer_segment
        string industry
        string country
        decimal annual_contract_value
        date acquisition_date
        date effective_date
        date end_date
        boolean is_current
    }
    
    DIM_PRODUCT {
        bigint product_key PK
        string product_id UK
        string product_name
        string product_category
        string product_subcategory
        decimal list_price
        decimal cost
        date effective_date
        date end_date
        boolean is_current
    }
    
    DIM_EMPLOYEE {
        bigint employee_key PK
        string employee_id UK
        string employee_name
        string job_title
        string department
        string employment_status
        date hire_date
        date effective_date
        date end_date
        boolean is_current
    }
    
    DIM_GEOGRAPHY {
        bigint geography_key PK
        string country
        string region
        string state_province
        string city
        decimal latitude
        decimal longitude
        date effective_date
        date end_date
        boolean is_current
    }
    
    DIM_DATE {
        int date_key PK
        date date_value UK
        int year
        int month
        string month_name
        int day_of_month
        string day_name
        int fiscal_year
        boolean is_weekend
        boolean is_holiday
    }
    
    FACT_SALES {
        bigint sales_key PK
        bigint customer_key FK
        bigint product_key FK
        bigint employee_key FK
        bigint geography_key FK
        int order_date_key FK
        int close_date_key FK
        string order_id UK
        decimal order_quantity
        decimal unit_price
        decimal line_amount
        decimal discount_amount
        decimal net_sales_amount
        decimal cost_amount
        decimal gross_profit
        string order_status
        string payment_status
        date delivery_date
        boolean is_return
        timestamp dw_insert_ts
    }
```

---

## Diagram 2: Customer Master Data with Hierarchy

```mermaid
erDiagram
    DIM_CUSTOMER ||--o{ BRIDGE_CUSTOMER_PRODUCT : uses
    DIM_CUSTOMER ||--o{ DIM_GEOGRAPHY : located_in
    DIM_PRODUCT ||--o{ BRIDGE_CUSTOMER_PRODUCT : uses
    
    DIM_CUSTOMER {
        bigint customer_key PK
        string customer_id UK
        string customer_name
        string customer_segment "Enterprise|Mid-Market|SMB"
        string industry
        string country
        string region
        string state_province
        string city
        string account_type
        string subscription_status
        decimal annual_contract_value
        date first_sale_date
        boolean is_active
        date effective_date
        boolean is_current "SCD Type 2"
    }
    
    DIM_GEOGRAPHY {
        bigint geography_key PK
        string geography_id UK
        string country
        string region
        string state_province
        string city
        string sales_territory
        date effective_date
        boolean is_current
    }
    
    DIM_PRODUCT {
        bigint product_key PK
        string product_id UK
        string product_name
        string product_category
        string business_unit
        decimal list_price
        decimal cost
        string supplier_name
        date effective_date
        boolean is_current
    }
    
    BRIDGE_CUSTOMER_PRODUCT {
        bigint bridge_key PK
        bigint customer_key FK
        bigint product_key FK
        date first_purchase_date
        date last_purchase_date
        int total_units_purchased
        decimal total_revenue
        string relationship_status
        boolean is_active
    }
```

---

## Diagram 3: Time Dimensions Architecture

```mermaid
erDiagram
    DIM_DATE ||--o{ FACT_SALES : "order_date"
    DIM_DATE ||--o{ FACT_SALES : "close_date"
    DIM_DATE ||--o{ FACT_REVENUE : references
    DIM_TIME ||--o{ FACT_SALES : "optional"
    DIM_TIME ||--o{ FACT_CUSTOMER_INTERACTIONS : references
    
    DIM_DATE {
        int date_key PK
        date date_value UK
        int year
        int quarter
        int month
        string month_name
        int week_of_year
        int day_of_month
        int day_of_week
        string day_name
        int fiscal_year
        int fiscal_quarter
        int fiscal_month
        boolean is_weekend
        boolean is_holiday
        boolean is_business_day
    }
    
    DIM_TIME {
        int time_key PK
        time time_value UK
        int hour_24
        int hour_12
        int minute
        int second
        string am_pm
        boolean business_hours
        string time_period "Early Morning|Morning|Afternoon|Evening|Night"
    }
    
    FACT_SALES {
        int order_date_key FK
        int order_time_key FK
        int close_date_key FK
    }
    
    FACT_REVENUE {
        int date_key FK
    }
    
    FACT_CUSTOMER_INTERACTIONS {
        int interaction_date_key FK
        int interaction_time_key FK
    }
```

---

## Diagram 4: Staging Layer Architecture (Source Systems)

```mermaid
erDiagram
    ERP_SYSTEMS ||--o{ STG_ORDERS : exports
    ERP_SYSTEMS ||--o{ STG_INVENTORY : exports
    SALESFORCE ||--o{ STG_CUSTOMERS : exports
    SALESFORCE ||--o{ STG_OPPORTUNITIES : exports
    SALESFORCE ||--o{ STG_ACTIVITIES : exports
    FINANCIAL_SYSTEM ||--o{ STG_TRANSACTIONS : exports
    HRMS ||--o{ STG_EMPLOYEES : exports
    OPERATIONS ||--o{ STG_PRODUCTION : exports
    TICKETING ||--o{ STG_TICKETS : exports
    MARKETING ||--o{ STG_CAMPAIGNS : exports
    
    ERP_SYSTEMS {
        string name "SAP|Oracle EBS"
        string connection_type "API|Direct DB|SFTP"
        string update_frequency "Real-time|Batch"
    }
    
    SALESFORCE {
        string name "Salesforce CRM"
        string connection_type "REST API|Webhooks"
        string update_frequency "Real-time"
    }
    
    FINANCIAL_SYSTEM {
        string name "NetSuite|QuickBooks"
        string connection_type "API|SFTP"
        string update_frequency "Batch EOD"
    }
    
    HRMS {
        string name "Workday|SuccessFactors"
        string connection_type "API|Scheduled Export"
        string update_frequency "Weekly"
    }
    
    OPERATIONS {
        string name "IoT|Custom Apps|Kafka"
        string connection_type "Message Queue|MQTT"
        string update_frequency "Real-time"
    }
    
    TICKETING {
        string name "Jira|ServiceNow"
        string connection_type "REST API"
        string update_frequency "Real-time"
    }
    
    MARKETING {
        string name "HubSpot|Marketo"
        string connection_type "API|Webhooks"
        string update_frequency "Real-time"
    }
    
    STG_ORDERS {
        bigint stg_order_key PK
        string source_system FK
        string order_id
        decimal quantity
        decimal line_amount
        timestamp load_ts
    }
    
    STG_INVENTORY {
        bigint stg_inventory_key PK
        string source_system FK
        string product_id
        decimal ending_balance
        timestamp load_ts
    }
    
    STG_CUSTOMERS {
        bigint stg_customer_key PK
        string source_system FK
        string customer_id
        string industry
        timestamp load_ts
    }
    
    STG_OPPORTUNITIES {
        bigint stg_opportunity_key PK
        string source_system FK
        string opportunity_id
        decimal amount
        timestamp load_ts
    }
    
    STG_ACTIVITIES {
        bigint stg_activity_key PK
        string source_system FK
        string activity_id
        string activity_type
        timestamp load_ts
    }
    
    STG_TRANSACTIONS {
        bigint stg_transaction_key PK
        string source_system FK
        string transaction_id
        decimal amount
        timestamp load_ts
    }
    
    STG_EMPLOYEES {
        bigint stg_employee_key PK
        string source_system FK
        string employee_id
        string department
        timestamp load_ts
    }
    
    STG_PRODUCTION {
        bigint stg_production_key PK
        string source_system FK
        string production_batch_id
        decimal units_completed
        timestamp load_ts
    }
    
    STG_TICKETS {
        bigint stg_ticket_key PK
        string source_system FK
        string ticket_id
        string status
        timestamp load_ts
    }
    
    STG_CAMPAIGNS {
        bigint stg_campaign_key PK
        string source_system FK
        string campaign_id
        bigint clicks
        timestamp load_ts
    }
```

---

## Diagram 5: Fact Tables - Complete Overview

```mermaid
erDiagram
    FACT_SALES ||--o{ DIM_CUSTOMER : customer
    FACT_SALES ||--o{ DIM_PRODUCT : product
    FACT_SALES ||--o{ DIM_EMPLOYEE : sales_rep
    FACT_SALES ||--o{ DIM_GEOGRAPHY : location
    FACT_SALES ||--o{ DIM_DATE : date
    
    FACT_REVENUE ||--o{ DIM_CUSTOMER : customer
    FACT_REVENUE ||--o{ DIM_PRODUCT : product
    FACT_REVENUE ||--o{ DIM_EMPLOYEE : employee
    FACT_REVENUE ||--o{ DIM_GEOGRAPHY : location
    FACT_REVENUE ||--o{ DIM_DATE : date
    
    FACT_INVENTORY ||--o{ DIM_PRODUCT : product
    FACT_INVENTORY ||--o{ DIM_GEOGRAPHY : warehouse
    FACT_INVENTORY ||--o{ DIM_DATE : date
    
    FACT_CUSTOMER_INTERACTIONS ||--o{ DIM_CUSTOMER : customer
    FACT_CUSTOMER_INTERACTIONS ||--o{ DIM_EMPLOYEE : employee
    FACT_CUSTOMER_INTERACTIONS ||--o{ DIM_PRODUCT : product
    FACT_CUSTOMER_INTERACTIONS ||--o{ DIM_DATE : date
    
    FACT_HR_METRICS ||--o{ DIM_EMPLOYEE : employee
    FACT_HR_METRICS ||--o{ DIM_DEPARTMENT : department
    FACT_HR_METRICS ||--o{ DIM_DATE : date
    
    FACT_PRODUCTION_METRICS ||--o{ DIM_PRODUCT : product
    FACT_PRODUCTION_METRICS ||--o{ DIM_EMPLOYEE : supervisor
    FACT_PRODUCTION_METRICS ||--o{ DIM_GEOGRAPHY : facility
    FACT_PRODUCTION_METRICS ||--o{ DIM_DATE : date
    
    FACT_SUPPORT_METRICS ||--o{ DIM_CUSTOMER : customer
    FACT_SUPPORT_METRICS ||--o{ DIM_EMPLOYEE : agent
    FACT_SUPPORT_METRICS ||--o{ DIM_PRODUCT : product
    FACT_SUPPORT_METRICS ||--o{ DIM_DATE : created_date
    
    FACT_MARKETING_PERFORMANCE ||--o{ DIM_EMPLOYEE : owner
    FACT_MARKETING_PERFORMANCE ||--o{ DIM_GEOGRAPHY : location
    FACT_MARKETING_PERFORMANCE ||--o{ DIM_DATE : date
    
    FACT_SALES {
        string order_id "PK"
        decimal net_sales_amount
        decimal gross_profit
        string order_status
    }
    
    FACT_REVENUE {
        decimal total_revenue "aggregate"
        decimal gross_profit
        int revenue_count
    }
    
    FACT_INVENTORY {
        decimal ending_balance
        decimal inventory_value
        int days_on_hand
    }
    
    FACT_CUSTOMER_INTERACTIONS {
        string interaction_id
        string interaction_type
        int duration_seconds
        decimal satisfaction_score
    }
    
    FACT_HR_METRICS {
        string employee_id
        int hours_worked
        int tasks_completed
        decimal revenue_generated
    }
    
    FACT_PRODUCTION_METRICS {
        decimal units_completed
        decimal defect_rate
        decimal efficiency_percent
    }
    
    FACT_SUPPORT_METRICS {
        string ticket_id
        int time_to_resolution
        decimal satisfaction_score
    }
    
    FACT_MARKETING_PERFORMANCE {
        bigint impressions
        bigint clicks
        int leads_generated
        decimal roi_percent
    }
    
    DIM_CUSTOMER {
        string customer_id "UK"
        string customer_segment
    }
    
    DIM_PRODUCT {
        string product_id "UK"
        string category
    }
    
    DIM_EMPLOYEE {
        string employee_id "UK"
        string department
    }
    
    DIM_GEOGRAPHY {
        string country
        string region
    }
    
    DIM_DATE {
        date date_value "UK"
        int year
        int month
    }
    
    DIM_DEPARTMENT {
        string department_id
        string division
    }
```

---

## Diagram 6: Warehouse Layers Architecture

```mermaid
graph TB
    subgraph SOURCES["Source Systems"]
        ERP["ERP<br/>SAP/Oracle"]
        CRM["CRM<br/>Salesforce"]
        FINANCE["Finance<br/>NetSuite"]
        HR["HRMS<br/>Workday"]
        OPS["Operations<br/>IoT/Custom"]
        SUPPORT["Support<br/>ServiceNow"]
        MARKETING["Marketing<br/>HubSpot"]
    end
    
    subgraph RAW["Layer 1: Raw/Staging<br/>(7-30 days retention)"]
        STG_ORD["stg_orders"]
        STG_INV["stg_inventory"]
        STG_CUST["stg_customers"]
        STG_OPP["stg_opportunities"]
        STG_EMP["stg_employees"]
        STG_PROD["stg_production"]
    end
    
    subgraph CLEANSED["Layer 2: Cleansed<br/>(90 days retention)"]
        CLN_ORD["Cleaned Orders"]
        CLN_INV["Cleaned Inventory"]
        CLN_CUST["Cleaned Customers"]
        CLN_OPP["Cleaned Opportunities"]
        CLN_EMP["Cleaned Employees"]
    end
    
    subgraph WAREHOUSE["Layer 3: Warehouse Core<br/>(Star Schema - 5 years)"]
        DIM_CUST["dim_customer<br/>Type 2 SCD"]
        DIM_PROD["dim_product<br/>Type 2 SCD"]
        DIM_EMP["dim_employee<br/>Type 2 SCD"]
        DIM_DATE["dim_date<br/>Conformed"]
        FACT_SALES["fact_sales"]
        FACT_REV["fact_revenue"]
        FACT_INV["fact_inventory"]
        FACT_CUST_INT["fact_customer_interactions"]
        FACT_HR["fact_hr_metrics"]
        FACT_PROD["fact_production_metrics"]
        FACT_SUP["fact_support_metrics"]
        FACT_MKT["fact_marketing_performance"]
    end
    
    subgraph MARTS["Layer 4: Data Marts<br/>(Current + 2 years)"]
        FINANCIAL_MART["Financial Mart<br/>Revenue, P&L, Cash Flow"]
        SALES_MART["Sales Mart<br/>Orders, Pipelines"]
        OPS_MART["Operations Mart<br/>Inventory, Production"]
        HR_MART["HR Mart<br/>Headcount, Metrics"]
        CUSTOMER_MART["Customer Mart<br/>360 View, Interactions"]
    end
    
    subgraph ANALYTICS["Layer 5: Analytics & BI"]
        DASHBOARDS["Executive Dashboards"]
        ANALYTICS_REPORTS["Analytics Reports"]
        AD_HOC["Ad-hoc Queries"]
        ML["ML/Predictive Models"]
    end
    
    ERP --> STG_ORD
    ERP --> STG_INV
    CRM --> STG_CUST
    CRM --> STG_OPP
    FINANCE --> STG_ORD
    HR --> STG_EMP
    OPS --> STG_PROD
    SUPPORT --> STG_CUST
    MARKETING --> STG_OPP
    
    STG_ORD --> CLN_ORD
    STG_INV --> CLN_INV
    STG_CUST --> CLN_CUST
    STG_OPP --> CLN_OPP
    STG_EMP --> CLN_EMP
    
    CLN_ORD --> DIM_CUST
    CLN_ORD --> DIM_PROD
    CLN_ORD --> FACT_SALES
    CLN_INV --> FACT_INV
    CLN_CUST --> DIM_CUST
    CLN_OPP --> FACT_CUST_INT
    CLN_EMP --> DIM_EMP
    
    DIM_CUST --> FACT_SALES
    DIM_PROD --> FACT_SALES
    DIM_DATE --> FACT_SALES
    FACT_SALES --> FACT_REV
    
    FACT_SALES --> FINANCIAL_MART
    FACT_SALES --> SALES_MART
    FACT_INV --> OPS_MART
    FACT_PROD --> OPS_MART
    FACT_HR --> HR_MART
    FACT_CUST_INT --> CUSTOMER_MART
    
    FINANCIAL_MART --> DASHBOARDS
    SALES_MART --> DASHBOARDS
    OPS_MART --> DASHBOARDS
    HR_MART --> DASHBOARDS
    CUSTOMER_MART --> DASHBOARDS
    
    DASHBOARDS --> ANALYTICS_REPORTS
    DASHBOARDS --> AD_HOC
    DASHBOARDS --> ML
```

---

## Diagram 7: Slowly Changing Dimensions (SCD Type 2) Flow

```mermaid
sequenceDiagram
    participant Source as Source System
    participant Staging as Staging Layer
    participant DW as Data Warehouse<br/>Dimension Table
    
    Source->>Staging: Customer data changes
    Staging->>Staging: Extract changed records
    Staging->>DW: Compare with current row
    
    alt No Changes
        DW->>DW: is_current remains TRUE
    else Data Changed
        DW->>DW: Set end_date on current row
        DW->>DW: Set is_current = FALSE
        DW->>DW: Insert new row with new data
        DW->>DW: Set is_current = TRUE
        DW->>DW: Set effective_date = change date
    end
    
    Note over DW: Full history maintained<br/>Enables time-travel queries
```

---

## Diagram 8: Data Quality & Metadata Tracking

```mermaid
erDiagram
    STG_CDC_LOGS ||--o{ STG_DATA_QUALITY_METRICS : tracks
    STG_ORDERS ||--o{ STG_CDC_LOGS : monitored_by
    STG_CUSTOMERS ||--o{ STG_CDC_LOGS : monitored_by
    
    STG_CDC_LOGS {
        bigint cdc_log_id PK
        string source_system
        string source_table
        string operation_type "INSERT|UPDATE|DELETE"
        timestamp captured_timestamp
        boolean processed_flag
        timestamp processed_timestamp
    }
    
    STG_DATA_QUALITY_METRICS {
        bigint quality_metric_id PK
        string source_system
        string source_table
        date load_date
        bigint total_records_loaded
        bigint duplicate_records
        bigint null_values_found
        decimal completeness_percent
        decimal accuracy_percent
        decimal timeliness_percent
        decimal quality_score
    }
    
    STG_ORDERS {
        string order_id UK
        string source_system
    }
    
    STG_CUSTOMERS {
        string customer_id UK
        string source_system
    }
```

