-- ============================================================================
-- DIMENSION TABLES
-- Enterprise KPI - Executive Decision Intelligence Platform
-- Purpose: Conformed dimensions for dimensional modeling
-- ============================================================================

-- ============================================================================
-- dim_date: Conformed Dimension Table (Type 1 - SCD Type 1)
-- Grain: One row per calendar day
-- Update Strategy: Static - loaded once
-- ============================================================================
CREATE TABLE dim_date (
    date_key                INT PRIMARY KEY,
    date_value              DATE NOT NULL UNIQUE,
    year                    INT NOT NULL,
    quarter                 INT NOT NULL,
    month                   INT NOT NULL,
    month_name              VARCHAR(20) NOT NULL,
    week_of_year            INT NOT NULL,
    day_of_month            INT NOT NULL,
    day_of_week             INT NOT NULL,
    day_name                VARCHAR(10) NOT NULL,
    fiscal_year             INT NOT NULL,
    fiscal_quarter          INT NOT NULL,
    fiscal_month            INT NOT NULL,
    is_weekend              BOOLEAN NOT NULL,
    is_holiday              BOOLEAN DEFAULT FALSE,
    is_business_day         BOOLEAN NOT NULL,
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_date_date_value ON dim_date(date_value);
CREATE INDEX idx_dim_date_year_month ON dim_date(year, month);

-- ============================================================================
-- dim_time: Conformed Dimension Table (Type 1 - SCD Type 1)
-- Grain: One row per minute
-- Update Strategy: Static - loaded once
-- ============================================================================
CREATE TABLE dim_time (
    time_key                INT PRIMARY KEY,
    time_value              TIME NOT NULL UNIQUE,
    hour_24                 INT NOT NULL,
    hour_12                 INT NOT NULL,
    minute                  INT NOT NULL,
    second                  INT NOT NULL,
    am_pm                   VARCHAR(2) NOT NULL,
    business_hours          BOOLEAN NOT NULL,
    time_period             VARCHAR(20) NOT NULL, -- Early Morning, Morning, Afternoon, Evening, Night
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_time_hour ON dim_time(hour_24);

-- ============================================================================
-- dim_customer: Slowly Changing Dimension (Type 2 - SCD Type 2)
-- Grain: One row per customer attribute version
-- Update Strategy: Daily - captures historical changes
-- ============================================================================
CREATE TABLE dim_customer (
    customer_key            BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_id             VARCHAR(50) NOT NULL,
    customer_name           VARCHAR(255) NOT NULL,
    customer_segment        VARCHAR(50), -- Enterprise, Mid-Market, SMB, Startup
    industry                VARCHAR(100),
    country                 VARCHAR(100),
    region                  VARCHAR(100),
    state_province          VARCHAR(100),
    city                    VARCHAR(100),
    postal_code             VARCHAR(20),
    account_type            VARCHAR(50), -- Direct, Partner, Reseller
    subscription_status     VARCHAR(50), -- Active, Inactive, Trial, Churned
    annual_contract_value   DECIMAL(15, 2),
    customer_lifetime_value DECIMAL(15, 2),
    acquisition_date        DATE,
    first_sale_date         DATE,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    end_date                DATE,
    is_current              BOOLEAN NOT NULL DEFAULT TRUE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_customer_id ON dim_customer(customer_id);
CREATE INDEX idx_dim_customer_current ON dim_customer(is_current);
CREATE INDEX idx_dim_customer_segment ON dim_customer(customer_segment);
CREATE INDEX idx_dim_customer_status ON dim_customer(subscription_status);

-- ============================================================================
-- dim_product: Slowly Changing Dimension (Type 2 - SCD Type 2)
-- Grain: One row per product attribute version
-- Update Strategy: Weekly - captures product changes
-- ============================================================================
CREATE TABLE dim_product (
    product_key             BIGINT PRIMARY KEY AUTO_INCREMENT,
    product_id              VARCHAR(50) NOT NULL,
    product_name            VARCHAR(255) NOT NULL,
    product_category        VARCHAR(100),
    product_subcategory     VARCHAR(100),
    product_type            VARCHAR(100),
    business_unit           VARCHAR(100),
    product_status          VARCHAR(50), -- Active, Inactive, Discontinued, Planned
    unit_of_measure         VARCHAR(20),
    list_price              DECIMAL(15, 2),
    cost                    DECIMAL(15, 2),
    gross_margin_percent    DECIMAL(5, 2),
    supplier_id             VARCHAR(50),
    supplier_name           VARCHAR(255),
    warehouse_location      VARCHAR(50),
    lead_time_days          INT,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    end_date                DATE,
    is_current              BOOLEAN NOT NULL DEFAULT TRUE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_product_id ON dim_product(product_id);
CREATE INDEX idx_dim_product_current ON dim_product(is_current);
CREATE INDEX idx_dim_product_category ON dim_product(product_category);
CREATE INDEX idx_dim_product_status ON dim_product(product_status);

-- ============================================================================
-- dim_employee: Slowly Changing Dimension (Type 2 - SCD Type 2)
-- Grain: One row per employee attribute version
-- Update Strategy: Weekly - captures employee changes
-- ============================================================================
CREATE TABLE dim_employee (
    employee_key            BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_id             VARCHAR(50) NOT NULL,
    employee_name           VARCHAR(255) NOT NULL,
    job_title               VARCHAR(100),
    department              VARCHAR(100),
    cost_center             VARCHAR(50),
    manager_id              VARCHAR(50),
    manager_name            VARCHAR(255),
    employment_status       VARCHAR(50), -- Active, Inactive, On Leave, Terminated
    employment_type         VARCHAR(50), -- Full-time, Part-time, Contract, Temporary
    hire_date               DATE,
    termination_date        DATE,
    salary_grade            VARCHAR(20),
    location                VARCHAR(100),
    country                 VARCHAR(100),
    region                  VARCHAR(100),
    email                   VARCHAR(255),
    direct_reports_count    INT DEFAULT 0,
    is_manager              BOOLEAN DEFAULT FALSE,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    end_date                DATE,
    is_current              BOOLEAN NOT NULL DEFAULT TRUE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_employee_id ON dim_employee(employee_id);
CREATE INDEX idx_dim_employee_current ON dim_employee(is_current);
CREATE INDEX idx_dim_employee_department ON dim_employee(department);
CREATE INDEX idx_dim_employee_status ON dim_employee(employment_status);

-- ============================================================================
-- dim_geography: Slowly Changing Dimension (Type 2 - SCD Type 2)
-- Grain: Geographic hierarchy from country to postal code
-- Update Strategy: Monthly - captures region/territory changes
-- ============================================================================
CREATE TABLE dim_geography (
    geography_key           BIGINT PRIMARY KEY AUTO_INCREMENT,
    geography_id            VARCHAR(50) NOT NULL,
    country                 VARCHAR(100),
    country_code            VARCHAR(5),
    region                  VARCHAR(100),
    state_province          VARCHAR(100),
    city                    VARCHAR(100),
    postal_code             VARCHAR(20),
    sales_territory         VARCHAR(100),
    district                VARCHAR(100),
    time_zone               VARCHAR(50),
    latitude                DECIMAL(10, 8),
    longitude               DECIMAL(11, 8),
    population              BIGINT,
    gdp_per_capita          DECIMAL(12, 2),
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    end_date                DATE,
    is_current              BOOLEAN NOT NULL DEFAULT TRUE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_geography_id ON dim_geography(geography_id);
CREATE INDEX idx_dim_geography_current ON dim_geography(is_current);
CREATE INDEX idx_dim_geography_country ON dim_geography(country);
CREATE INDEX idx_dim_geography_region ON dim_geography(region);

-- ============================================================================
-- dim_department: Slowly Changing Dimension (Type 2 - SCD Type 2)
-- Grain: Organization department/cost center
-- Update Strategy: Quarterly - captures org structure changes
-- ============================================================================
CREATE TABLE dim_department (
    department_key          BIGINT PRIMARY KEY AUTO_INCREMENT,
    department_id           VARCHAR(50) NOT NULL,
    department_name         VARCHAR(255) NOT NULL,
    department_code         VARCHAR(20),
    cost_center             VARCHAR(50),
    parent_department_id    VARCHAR(50),
    parent_department_name  VARCHAR(255),
    division                VARCHAR(100),
    business_unit           VARCHAR(100),
    department_manager_id   VARCHAR(50),
    department_manager_name VARCHAR(255),
    budget_annual           DECIMAL(15, 2),
    headcount               INT,
    location                VARCHAR(100),
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    end_date                DATE,
    is_current              BOOLEAN NOT NULL DEFAULT TRUE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_department_id ON dim_department(department_id);
CREATE INDEX idx_dim_department_current ON dim_department(is_current);
CREATE INDEX idx_dim_department_name ON dim_department(department_name);

-- ============================================================================
-- Bridge Table: bridge_customer_product
-- Purpose: Many-to-many relationship between customers and products
-- Use Case: Track which products each customer is using/has purchased
-- ============================================================================
CREATE TABLE bridge_customer_product (
    bridge_key              BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_key            BIGINT NOT NULL,
    product_key             BIGINT NOT NULL,
    first_purchase_date     DATE,
    last_purchase_date      DATE,
    total_units_purchased   INT,
    total_revenue           DECIMAL(15, 2),
    relationship_status     VARCHAR(50), -- Active, Churned, Trial
    is_active               BOOLEAN DEFAULT TRUE,
    dw_insert_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dw_update_ts            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    UNIQUE KEY uq_customer_product (customer_key, product_key)
);

CREATE INDEX idx_bridge_customer_key ON bridge_customer_product(customer_key);
CREATE INDEX idx_bridge_product_key ON bridge_customer_product(product_key);
