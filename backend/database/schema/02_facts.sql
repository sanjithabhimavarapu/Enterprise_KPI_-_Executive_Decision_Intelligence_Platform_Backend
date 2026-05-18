-- ============================================================================
-- FACT TABLES
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Transactional and aggregate fact tables for dimensional analysis
-- ============================================================================

-- ============================================================================
-- fact_sales: Transactional Fact Table
-- Grain: One row per sales transaction line item
-- Update Frequency: Real-time (via CDC or API triggers)
-- Records/Day: ~500K
-- ============================================================================
CREATE TABLE fact_sales (
    sales_key               BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys (Dimensions)
    customer_key            BIGINT NOT NULL,
    product_key             BIGINT NOT NULL,
    employee_key            BIGINT NOT NULL, -- Sales rep
    geography_key           BIGINT NOT NULL,
    order_date_key          INT NOT NULL,
    order_time_key          INT,
    close_date_key          INT NOT NULL,
    
    -- Business Keys
    order_id                VARCHAR(50) NOT NULL,
    order_line_id           VARCHAR(50),
    sales_opportunity_id    VARCHAR(50),
    
    -- Measures (Facts)
    order_quantity          DECIMAL(12, 2) NOT NULL,
    unit_price              DECIMAL(15, 2) NOT NULL,
    line_amount             DECIMAL(15, 2) NOT NULL,
    discount_amount         DECIMAL(15, 2) DEFAULT 0,
    discount_percent        DECIMAL(5, 2) DEFAULT 0,
    net_sales_amount        DECIMAL(15, 2) NOT NULL,
    cost_amount             DECIMAL(15, 2),
    gross_profit            DECIMAL(15, 2),
    gross_profit_percent    DECIMAL(5, 2),
    
    -- Additional Measures
    shipping_cost           DECIMAL(15, 2),
    tax_amount              DECIMAL(15, 2),
    total_transaction_amt   DECIMAL(15, 2),
    
    -- Descriptive Attributes
    order_status            VARCHAR(50), -- Complete, Partial, Cancelled, Pending
    payment_status          VARCHAR(50), -- Paid, Unpaid, Partial
    fulfillment_status      VARCHAR(50), -- Fulfilled, Partial, Pending
    sales_channel           VARCHAR(50), -- Direct, Partner, Online, Retail
    order_type              VARCHAR(50), -- New, Renewal, Upsell, Cross-sell
    
    -- Dates
    delivery_date           DATE,
    days_to_delivery        INT,
    
    -- Metadata
    is_return               BOOLEAN DEFAULT FALSE,
    is_cancelled            BOOLEAN DEFAULT FALSE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    FOREIGN KEY (geography_key) REFERENCES dim_geography(geography_key),
    FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (close_date_key) REFERENCES dim_date(date_key)
);

CREATE INDEX idx_fact_sales_customer_key ON fact_sales(customer_key);
CREATE INDEX idx_fact_sales_product_key ON fact_sales(product_key);
CREATE INDEX idx_fact_sales_employee_key ON fact_sales(employee_key);
CREATE INDEX idx_fact_sales_order_date ON fact_sales(order_date_key);
CREATE INDEX idx_fact_sales_close_date ON fact_sales(close_date_key);
CREATE INDEX idx_fact_sales_order_id ON fact_sales(order_id);
CREATE INDEX idx_fact_sales_status ON fact_sales(order_status);

-- ============================================================================
-- fact_revenue: Aggregate Fact Table (Daily)
-- Grain: One row per day per customer per product
-- Update Frequency: Daily (End of Day)
-- Purpose: Pre-aggregated for fast executive reporting
-- ============================================================================
CREATE TABLE fact_revenue (
    revenue_key             BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys
    date_key                INT NOT NULL,
    customer_key            BIGINT NOT NULL,
    product_key             BIGINT NOT NULL,
    geography_key           BIGINT NOT NULL,
    employee_key            BIGINT NOT NULL,
    
    -- Aggregate Measures
    total_revenue           DECIMAL(15, 2) NOT NULL,
    revenue_count           INT NOT NULL, -- Number of transactions
    average_transaction_amt DECIMAL(15, 2),
    
    -- Revenue Components
    gross_sales             DECIMAL(15, 2),
    discounts               DECIMAL(15, 2),
    net_revenue             DECIMAL(15, 2),
    cost_of_goods           DECIMAL(15, 2),
    gross_profit            DECIMAL(15, 2),
    
    -- KPI Calculations
    gross_margin_percent    DECIMAL(5, 2),
    
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (geography_key) REFERENCES dim_geography(geography_key),
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    UNIQUE KEY uq_revenue_daily (date_key, customer_key, product_key, geography_key)
);

CREATE INDEX idx_fact_revenue_date ON fact_revenue(date_key);
CREATE INDEX idx_fact_revenue_customer ON fact_revenue(customer_key);
CREATE INDEX idx_fact_revenue_product ON fact_revenue(product_key);

-- ============================================================================
-- fact_inventory: Transactional Fact Table
-- Grain: Inventory snapshot per warehouse location per product per day
-- Update Frequency: Real-time to Hourly
-- Records/Day: ~1M
-- ============================================================================
CREATE TABLE fact_inventory (
    inventory_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys
    product_key             BIGINT NOT NULL,
    date_key                INT NOT NULL,
    warehouse_location_id   VARCHAR(50),
    geography_key           BIGINT,
    
    -- Business Keys
    product_id              VARCHAR(50),
    warehouse_id            VARCHAR(50),
    
    -- Inventory Measures
    beginning_balance       DECIMAL(12, 2),
    units_received          DECIMAL(12, 2),
    units_sold              DECIMAL(12, 2),
    units_returned          DECIMAL(12, 2),
    units_damaged           DECIMAL(12, 2),
    units_lost              DECIMAL(12, 2),
    ending_balance          DECIMAL(12, 2),
    
    -- Inventory Metrics
    inventory_value         DECIMAL(15, 2),
    days_on_hand            INT,
    reorder_level           DECIMAL(12, 2),
    is_low_stock            BOOLEAN DEFAULT FALSE,
    is_overstock            BOOLEAN DEFAULT FALSE,
    
    -- Quality Metrics
    defect_count            INT,
    defect_rate             DECIMAL(5, 2),
    
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (geography_key) REFERENCES dim_geography(geography_key)
);

CREATE INDEX idx_fact_inventory_product ON fact_inventory(product_key);
CREATE INDEX idx_fact_inventory_date ON fact_inventory(date_key);
CREATE INDEX idx_fact_inventory_warehouse ON fact_inventory(warehouse_id);

-- ============================================================================
-- fact_customer_interactions: Transactional Fact Table
-- Grain: One row per customer interaction event
-- Update Frequency: Real-time (via CRM events)
-- Records/Day: ~2M
-- ============================================================================
CREATE TABLE fact_customer_interactions (
    interaction_key         BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys
    customer_key            BIGINT NOT NULL,
    employee_key            BIGINT, -- Employee who handled interaction
    product_key             BIGINT,
    interaction_date_key    INT NOT NULL,
    interaction_time_key    INT,
    
    -- Business Keys
    interaction_id          VARCHAR(50) NOT NULL,
    opportunity_id          VARCHAR(50),
    case_id                 VARCHAR(50),
    
    -- Interaction Details
    interaction_type        VARCHAR(50), -- Call, Email, Meeting, Chat, Demo, etc.
    interaction_channel     VARCHAR(50), -- Phone, Email, Web, Social, In-person
    interaction_direction   VARCHAR(20), -- Inbound, Outbound
    interaction_status      VARCHAR(50), -- Completed, Pending, Cancelled
    sentiment               VARCHAR(50), -- Positive, Neutral, Negative
    
    -- Duration & Engagement
    duration_seconds        INT,
    notes                   TEXT,
    
    -- Outcome Measures
    interaction_result      VARCHAR(50), -- Success, Partial, Failed
    next_action_required    BOOLEAN DEFAULT FALSE,
    follow_up_date          DATE,
    
    -- Satisfaction Metrics
    satisfaction_score      DECIMAL(3, 1),
    nps_score               INT, -- Net Promoter Score
    
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (interaction_date_key) REFERENCES dim_date(date_key)
);

CREATE INDEX idx_fact_interactions_customer ON fact_customer_interactions(customer_key);
CREATE INDEX idx_fact_interactions_employee ON fact_customer_interactions(employee_key);
CREATE INDEX idx_fact_interactions_date ON fact_customer_interactions(interaction_date_key);
CREATE INDEX idx_fact_interactions_type ON fact_customer_interactions(interaction_type);

-- ============================================================================
-- fact_hr_metrics: Aggregate Fact Table (Daily)
-- Grain: One row per employee per day
-- Update Frequency: Daily (End of Day)
-- Purpose: HR analytics and employee performance tracking
-- ============================================================================
CREATE TABLE fact_hr_metrics (
    hr_metric_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys
    employee_key            BIGINT NOT NULL,
    department_key          BIGINT NOT NULL,
    date_key                INT NOT NULL,
    
    -- Business Keys
    employee_id             VARCHAR(50),
    
    -- Attendance
    is_present              BOOLEAN,
    is_vacation             BOOLEAN,
    is_sick_leave           BOOLEAN,
    is_personal_leave       BOOLEAN,
    is_work_from_home       BOOLEAN,
    hours_worked            DECIMAL(5, 2),
    
    -- Performance
    tasks_completed         INT,
    tasks_in_progress       INT,
    revenue_generated       DECIMAL(15, 2),
    
    -- Engagement
    emails_sent             INT,
    meetings_attended       INT,
    training_hours          DECIMAL(5, 2),
    
    -- HR Outcomes
    performance_rating      DECIMAL(3, 1),
    promotion_eligible      BOOLEAN DEFAULT FALSE,
    
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    FOREIGN KEY (department_key) REFERENCES dim_department(department_key),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    UNIQUE KEY uq_hr_metrics_daily (employee_key, date_key)
);

CREATE INDEX idx_fact_hr_date ON fact_hr_metrics(date_key);
CREATE INDEX idx_fact_hr_employee ON fact_hr_metrics(employee_key);
CREATE INDEX idx_fact_hr_department ON fact_hr_metrics(department_key);

-- ============================================================================
-- fact_production_metrics: Transactional Fact Table
-- Grain: One row per production event/shift
-- Update Frequency: Real-time to Hourly
-- Records/Day: ~1M
-- Purpose: Operations and manufacturing analytics
-- ============================================================================
CREATE TABLE fact_production_metrics (
    production_key          BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys
    product_key             BIGINT NOT NULL,
    date_key                INT NOT NULL,
    time_key                INT,
    employee_key            BIGINT, -- Shift supervisor
    geography_key           BIGINT, -- Production facility location
    
    -- Business Keys
    production_batch_id     VARCHAR(50),
    line_id                 VARCHAR(50),
    
    -- Production Measures
    units_started           DECIMAL(12, 2),
    units_completed         DECIMAL(12, 2),
    units_defective         DECIMAL(12, 2),
    first_pass_yield        DECIMAL(5, 2),
    production_time_hrs     DECIMAL(8, 2),
    
    -- Quality Metrics
    defect_rate             DECIMAL(5, 2),
    quality_score           DECIMAL(5, 1),
    rework_hours            DECIMAL(8, 2),
    
    -- Efficiency Metrics
    efficiency_percent      DECIMAL(5, 2),
    downtime_minutes        INT,
    maintenance_required    BOOLEAN DEFAULT FALSE,
    
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    FOREIGN KEY (geography_key) REFERENCES dim_geography(geography_key)
);

CREATE INDEX idx_fact_production_date ON fact_production_metrics(date_key);
CREATE INDEX idx_fact_production_product ON fact_production_metrics(product_key);
CREATE INDEX idx_fact_production_batch ON fact_production_metrics(production_batch_id);

-- ============================================================================
-- fact_support_metrics: Transactional Fact Table
-- Grain: One row per support ticket
-- Update Frequency: Real-time (via ticketing system)
-- Records/Day: ~100K
-- Purpose: Customer support and service level analytics
-- ============================================================================
CREATE TABLE fact_support_metrics (
    support_key             BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys
    customer_key            BIGINT NOT NULL,
    employee_key            BIGINT, -- Support agent
    product_key             BIGINT,
    created_date_key        INT NOT NULL,
    resolved_date_key       INT,
    
    -- Business Keys
    ticket_id               VARCHAR(50) NOT NULL,
    
    -- Support Metrics
    ticket_priority         VARCHAR(20), -- Critical, High, Medium, Low
    ticket_category         VARCHAR(100),
    ticket_status           VARCHAR(50), -- Open, In Progress, Resolved, Closed, Reopened
    
    -- Time Metrics
    time_to_first_response  INT, -- Minutes
    time_to_resolution      INT, -- Hours
    total_interactions      INT,
    escalations             INT,
    
    -- Resolution Metrics
    resolution_type         VARCHAR(50), -- Resolved, Workaround, Escalated, Closed
    root_cause              VARCHAR(255),
    
    -- Satisfaction
    customer_satisfaction_score DECIMAL(3, 1),
    resolution_quality      VARCHAR(50), -- Successful, Partial, Failed
    
    -- Cost
    support_cost            DECIMAL(12, 2),
    
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (created_date_key) REFERENCES dim_date(date_key)
);

CREATE INDEX idx_fact_support_customer ON fact_support_metrics(customer_key);
CREATE INDEX idx_fact_support_date ON fact_support_metrics(created_date_key);
CREATE INDEX idx_fact_support_status ON fact_support_metrics(ticket_status);
CREATE INDEX idx_fact_support_agent ON fact_support_metrics(employee_key);

-- ============================================================================
-- fact_marketing_performance: Aggregate Fact Table (Daily)
-- Grain: One row per campaign per day
-- Update Frequency: Daily (Real-time to Daily)
-- Records/Day: ~50K
-- Purpose: Marketing campaign and lead generation analytics
-- ============================================================================
CREATE TABLE fact_marketing_performance (
    marketing_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- Foreign Keys
    date_key                INT NOT NULL,
    campaign_date_key       INT NOT NULL,
    geography_key           BIGINT,
    employee_key            BIGINT, -- Campaign owner
    
    -- Business Keys
    campaign_id             VARCHAR(50) NOT NULL,
    channel_id              VARCHAR(50),
    
    -- Campaign Details
    campaign_name           VARCHAR(255),
    campaign_type           VARCHAR(50), -- Email, Social, Webinar, Event, Paid Search, etc.
    campaign_channel        VARCHAR(50), -- Email, Social Media, Web, Direct, etc.
    campaign_status         VARCHAR(50), -- Active, Ended, Paused
    
    -- Performance Metrics
    impressions             BIGINT,
    clicks                  BIGINT,
    click_through_rate      DECIMAL(5, 2),
    
    leads_generated         INT,
    leads_qualified         INT,
    lead_conversion_rate    DECIMAL(5, 2),
    
    opportunities_created   INT,
    won_opportunities       INT,
    opportunity_value       DECIMAL(15, 2),
    
    -- Cost Metrics
    campaign_cost           DECIMAL(15, 2),
    cost_per_lead           DECIMAL(12, 2),
    cost_per_acquisition    DECIMAL(12, 2),
    roi_percent             DECIMAL(8, 2),
    
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (campaign_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (geography_key) REFERENCES dim_geography(geography_key),
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key)
);

CREATE INDEX idx_fact_marketing_date ON fact_marketing_performance(date_key);
CREATE INDEX idx_fact_marketing_campaign ON fact_marketing_performance(campaign_id);
CREATE INDEX idx_fact_marketing_channel ON fact_marketing_performance(campaign_channel);
