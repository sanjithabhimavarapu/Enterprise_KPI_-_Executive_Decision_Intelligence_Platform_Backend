-- ============================================================================
-- STAGING TABLES
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Extract raw source data before transformation and loading
-- Retention: 7-30 days
-- ============================================================================

-- ============================================================================
-- SAP/Oracle ERP Source Staging Tables
-- ============================================================================

-- stg_orders: Raw sales orders from ERP
CREATE TABLE stg_orders (
    stg_order_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'ERP',
    source_record_id        VARCHAR(100),
    
    order_id                VARCHAR(50),
    order_line_id           VARCHAR(50),
    order_date              DATE,
    order_time              TIME,
    customer_id             VARCHAR(50),
    product_id              VARCHAR(50),
    quantity                DECIMAL(12, 2),
    unit_price              DECIMAL(15, 2),
    line_amount             DECIMAL(15, 2),
    discount_amount         DECIMAL(15, 2),
    discount_percent        DECIMAL(5, 2),
    tax_amount              DECIMAL(15, 2),
    total_amount            DECIMAL(15, 2),
    
    order_status            VARCHAR(50),
    payment_status          VARCHAR(50),
    fulfillment_status      VARCHAR(50),
    delivery_date           DATE,
    
    sales_rep_id            VARCHAR(50),
    sales_channel           VARCHAR(50),
    order_type              VARCHAR(50),
    purchase_order          VARCHAR(100),
    
    is_return               BOOLEAN,
    is_cancelled            BOOLEAN,
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64), -- For change detection
    UNIQUE KEY uq_stg_orders (source_system, source_record_id)
);

CREATE INDEX idx_stg_orders_order_id ON stg_orders(order_id);
CREATE INDEX idx_stg_orders_load_ts ON stg_orders(load_ts);

-- stg_inventory: Raw inventory data from ERP
CREATE TABLE stg_inventory (
    stg_inventory_key       BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'ERP',
    source_record_id        VARCHAR(100),
    
    product_id              VARCHAR(50),
    warehouse_id            VARCHAR(50),
    warehouse_location      VARCHAR(50),
    snapshot_date           DATE,
    
    beginning_balance       DECIMAL(12, 2),
    units_received          DECIMAL(12, 2),
    units_sold              DECIMAL(12, 2),
    units_returned          DECIMAL(12, 2),
    units_damaged           DECIMAL(12, 2),
    units_lost              DECIMAL(12, 2),
    ending_balance          DECIMAL(12, 2),
    
    inventory_value         DECIMAL(15, 2),
    days_on_hand            INT,
    reorder_level           DECIMAL(12, 2),
    defect_count            INT,
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_inventory (source_system, source_record_id)
);

CREATE INDEX idx_stg_inventory_product ON stg_inventory(product_id);
CREATE INDEX idx_stg_inventory_date ON stg_inventory(snapshot_date);

-- ============================================================================
-- Salesforce CRM Source Staging Tables
-- ============================================================================

-- stg_customers: Raw customer data from CRM
CREATE TABLE stg_customers (
    stg_customer_key        BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'SALESFORCE',
    source_record_id        VARCHAR(100),
    
    customer_id             VARCHAR(50),
    customer_name           VARCHAR(255),
    customer_segment        VARCHAR(50),
    industry                VARCHAR(100),
    
    billing_address         VARCHAR(500),
    billing_city            VARCHAR(100),
    billing_state           VARCHAR(100),
    billing_postal_code     VARCHAR(20),
    billing_country         VARCHAR(100),
    
    shipping_address        VARCHAR(500),
    shipping_city           VARCHAR(100),
    shipping_state          VARCHAR(100),
    shipping_postal_code    VARCHAR(20),
    shipping_country        VARCHAR(100),
    
    account_type            VARCHAR(50),
    subscription_status     VARCHAR(50),
    annual_contract_value   DECIMAL(15, 2),
    
    acquisition_date        DATE,
    first_sale_date         DATE,
    last_activity_date      DATE,
    
    primary_contact_name    VARCHAR(255),
    primary_contact_email   VARCHAR(255),
    primary_contact_phone   VARCHAR(20),
    
    account_owner_id        VARCHAR(50),
    account_owner_name      VARCHAR(255),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_customers (source_system, source_record_id)
);

CREATE INDEX idx_stg_customers_customer_id ON stg_customers(customer_id);
CREATE INDEX idx_stg_customers_load_ts ON stg_customers(load_ts);

-- stg_opportunities: Raw sales opportunities from CRM
CREATE TABLE stg_opportunities (
    stg_opportunity_key     BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'SALESFORCE',
    source_record_id        VARCHAR(100),
    
    opportunity_id          VARCHAR(50),
    opportunity_name        VARCHAR(255),
    customer_id             VARCHAR(50),
    customer_name           VARCHAR(255),
    
    product_id              VARCHAR(50),
    product_name            VARCHAR(255),
    
    amount                  DECIMAL(15, 2),
    expected_revenue        DECIMAL(15, 2),
    probability             DECIMAL(3, 1),
    
    stage                   VARCHAR(100),
    opportunity_type        VARCHAR(50),
    
    close_date              DATE,
    actual_close_date       DATE,
    created_date            DATE,
    last_modified_date      DATE,
    
    owner_id                VARCHAR(50),
    owner_name              VARCHAR(255),
    
    status                  VARCHAR(50), -- Open, Won, Lost, Closed
    reason_lost             VARCHAR(255),
    competitor              VARCHAR(255),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_opportunities (source_system, source_record_id)
);

CREATE INDEX idx_stg_opportunities_customer_id ON stg_opportunities(customer_id);
CREATE INDEX idx_stg_opportunities_stage ON stg_opportunities(stage);

-- stg_activities: Raw activities/interactions from CRM
CREATE TABLE stg_activities (
    stg_activity_key        BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'SALESFORCE',
    source_record_id        VARCHAR(100),
    
    activity_id             VARCHAR(50),
    customer_id             VARCHAR(50),
    opportunity_id          VARCHAR(50),
    account_id              VARCHAR(50),
    
    activity_type           VARCHAR(50), -- Call, Email, Meeting, Task, Event
    activity_date           DATE,
    activity_time           TIME,
    
    subject                 VARCHAR(500),
    description             TEXT,
    
    duration_minutes        INT,
    status                  VARCHAR(50),
    outcome                 VARCHAR(50),
    
    owner_id                VARCHAR(50),
    owner_name              VARCHAR(255),
    attendees               VARCHAR(500),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_activities (source_system, source_record_id)
);

CREATE INDEX idx_stg_activities_customer_id ON stg_activities(customer_id);
CREATE INDEX idx_stg_activities_activity_date ON stg_activities(activity_date);

-- ============================================================================
-- Financial System (NetSuite) Staging Tables
-- ============================================================================

-- stg_transactions: Raw transactions from financial system
CREATE TABLE stg_transactions (
    stg_transaction_key     BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'NETSUITE',
    source_record_id        VARCHAR(100),
    
    transaction_id          VARCHAR(50),
    transaction_date        DATE,
    transaction_type        VARCHAR(50), -- Invoice, Bill, Payment, Credit Memo
    
    entity_id               VARCHAR(50),
    entity_name             VARCHAR(255),
    
    amount                  DECIMAL(15, 2),
    currency                VARCHAR(10),
    
    status                  VARCHAR(50),
    payment_status          VARCHAR(50),
    due_date                DATE,
    paid_date               DATE,
    
    gl_account              VARCHAR(50),
    department              VARCHAR(100),
    
    created_date            DATE,
    created_by              VARCHAR(100),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_transactions (source_system, source_record_id)
);

CREATE INDEX idx_stg_transactions_date ON stg_transactions(transaction_date);
CREATE INDEX idx_stg_transactions_entity ON stg_transactions(entity_id);

-- stg_gl_accounts: General ledger accounts from financial system
CREATE TABLE stg_gl_accounts (
    stg_gl_key              BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'NETSUITE',
    source_record_id        VARCHAR(100),
    
    gl_account              VARCHAR(50),
    account_name            VARCHAR(255),
    account_type            VARCHAR(50), -- Asset, Liability, Revenue, Expense
    
    account_balance         DECIMAL(15, 2),
    period                  VARCHAR(20),
    fiscal_year             INT,
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_gl (source_system, source_record_id)
);

-- ============================================================================
-- HR System (Workday) Staging Tables
-- ============================================================================

-- stg_employees: Raw employee data from HRMS
CREATE TABLE stg_employees (
    stg_employee_key        BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'WORKDAY',
    source_record_id        VARCHAR(100),
    
    employee_id             VARCHAR(50),
    employee_name           VARCHAR(255),
    first_name              VARCHAR(100),
    last_name               VARCHAR(100),
    email                   VARCHAR(255),
    phone                   VARCHAR(20),
    
    job_title               VARCHAR(100),
    department              VARCHAR(100),
    department_id           VARCHAR(50),
    cost_center             VARCHAR(50),
    
    manager_id              VARCHAR(50),
    manager_name            VARCHAR(255),
    
    employment_status       VARCHAR(50), -- Active, Inactive, On Leave, Terminated
    employment_type         VARCHAR(50), -- Full-time, Part-time, Contract
    
    hire_date               DATE,
    termination_date        DATE,
    
    salary_grade            VARCHAR(20),
    salary_amount           DECIMAL(12, 2),
    
    location                VARCHAR(100),
    country                 VARCHAR(100),
    region                  VARCHAR(100),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_employees (source_system, source_record_id)
);

CREATE INDEX idx_stg_employees_employee_id ON stg_employees(employee_id);
CREATE INDEX idx_stg_employees_department ON stg_employees(department);

-- stg_payroll: Raw payroll data from HRMS
CREATE TABLE stg_payroll (
    stg_payroll_key         BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'WORKDAY',
    source_record_id        VARCHAR(100),
    
    employee_id             VARCHAR(50),
    payroll_period          VARCHAR(50),
    pay_date                DATE,
    
    gross_pay               DECIMAL(12, 2),
    base_salary             DECIMAL(12, 2),
    bonuses                 DECIMAL(12, 2),
    commissions             DECIMAL(12, 2),
    
    income_tax              DECIMAL(12, 2),
    social_security         DECIMAL(12, 2),
    benefits_deduction      DECIMAL(12, 2),
    
    net_pay                 DECIMAL(12, 2),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_payroll (source_system, source_record_id)
);

-- ============================================================================
-- Operations/Manufacturing Staging Tables
-- ============================================================================

-- stg_production: Raw production data from operational systems
CREATE TABLE stg_production (
    stg_production_key      BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'OPERATIONS',
    source_record_id        VARCHAR(100),
    
    production_batch_id     VARCHAR(50),
    line_id                 VARCHAR(50),
    equipment_id            VARCHAR(50),
    
    product_id              VARCHAR(50),
    production_date         DATE,
    production_time         TIMESTAMP,
    
    shift_id                VARCHAR(20),
    supervisor_id           VARCHAR(50),
    
    units_started           DECIMAL(12, 2),
    units_completed         DECIMAL(12, 2),
    units_defective         DECIMAL(12, 2),
    
    production_time_hrs     DECIMAL(8, 2),
    downtime_minutes        INT,
    
    defect_rate             DECIMAL(5, 2),
    quality_score           DECIMAL(5, 1),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_production (source_system, source_record_id)
);

CREATE INDEX idx_stg_production_date ON stg_production(production_date);
CREATE INDEX idx_stg_production_product ON stg_production(product_id);

-- ============================================================================
-- Support/Ticketing System Staging Tables
-- ============================================================================

-- stg_tickets: Raw support tickets from ticketing system
CREATE TABLE stg_tickets (
    stg_ticket_key          BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'SERVICENOW',
    source_record_id        VARCHAR(100),
    
    ticket_id               VARCHAR(50),
    customer_id             VARCHAR(50),
    product_id              VARCHAR(50),
    
    created_date            DATE,
    created_time            TIME,
    resolved_date           DATE,
    resolved_time           TIME,
    
    priority                VARCHAR(20),
    severity                VARCHAR(20),
    category                VARCHAR(100),
    subcategory             VARCHAR(100),
    
    status                  VARCHAR(50),
    description             TEXT,
    resolution              TEXT,
    
    assigned_to_id          VARCHAR(50),
    assigned_to_name        VARCHAR(255),
    
    total_interactions      INT,
    time_to_first_response  INT, -- Minutes
    resolution_time         INT, -- Hours
    
    satisfaction_score      DECIMAL(3, 1),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_tickets (source_system, source_record_id)
);

CREATE INDEX idx_stg_tickets_customer_id ON stg_tickets(customer_id);
CREATE INDEX idx_stg_tickets_created_date ON stg_tickets(created_date);

-- ============================================================================
-- Marketing Automation Staging Tables
-- ============================================================================

-- stg_campaigns: Raw campaign data from marketing automation
CREATE TABLE stg_campaigns (
    stg_campaign_key        BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50) DEFAULT 'HUBSPOT',
    source_record_id        VARCHAR(100),
    
    campaign_id             VARCHAR(50),
    campaign_name           VARCHAR(255),
    campaign_type           VARCHAR(50), -- Email, Social, Webinar, Event, Paid Search
    
    start_date              DATE,
    end_date                DATE,
    
    impressions             BIGINT,
    clicks                  BIGINT,
    conversions             INT,
    
    leads_generated         INT,
    opportunities_created   INT,
    
    budget                  DECIMAL(15, 2),
    spend                   DECIMAL(15, 2),
    
    status                  VARCHAR(50),
    
    load_ts                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_load_ts          TIMESTAMP,
    dw_hash                 VARCHAR(64),
    UNIQUE KEY uq_stg_campaigns (source_system, source_record_id)
);

-- ============================================================================
-- CDC (Change Data Capture) Tracking Table
-- ============================================================================

CREATE TABLE stg_cdc_logs (
    cdc_log_id              BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50),
    source_table            VARCHAR(100),
    source_record_id        VARCHAR(100),
    operation_type          VARCHAR(20), -- INSERT, UPDATE, DELETE
    captured_timestamp      TIMESTAMP,
    processed_flag          BOOLEAN DEFAULT FALSE,
    processed_timestamp     TIMESTAMP,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_cdc_log (source_system, source_table, source_record_id, captured_timestamp)
);

CREATE INDEX idx_cdc_processed ON stg_cdc_logs(processed_flag);
CREATE INDEX idx_cdc_source_table ON stg_cdc_logs(source_system, source_table);

-- ============================================================================
-- Data Quality Metrics Tracking
-- ============================================================================

CREATE TABLE stg_data_quality_metrics (
    quality_metric_id       BIGINT PRIMARY KEY AUTO_INCREMENT,
    source_system           VARCHAR(50),
    source_table            VARCHAR(100),
    load_date               DATE,
    load_time               TIMESTAMP,
    
    total_records_loaded    BIGINT,
    duplicate_records       BIGINT,
    null_values_found       BIGINT,
    validation_errors       BIGINT,
    
    completeness_percent    DECIMAL(5, 2),
    accuracy_percent        DECIMAL(5, 2),
    timeliness_percent      DECIMAL(5, 2),
    
    quality_score           DECIMAL(5, 2),
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_quality_metrics_date ON stg_data_quality_metrics(load_date);
CREATE INDEX idx_quality_metrics_source ON stg_data_quality_metrics(source_system, source_table);
