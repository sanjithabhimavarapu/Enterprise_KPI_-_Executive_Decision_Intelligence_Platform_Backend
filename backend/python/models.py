"""
SQLAlchemy ORM Models
====================
Database models for staging tables, dimensions, and facts.
"""

from datetime import datetime, date
from typing import Optional
from sqlalchemy import Column, Integer, String, Float, DateTime, Date, Boolean, BigInteger, DECIMAL, Text, ForeignKey, Index
from sqlalchemy.orm import relationship
from database import Base


# ============================================================
# STAGING MODELS
# ============================================================

class StagingOrdersConformed(Base):
    """Conformed staging table for ERP orders."""
    __tablename__ = 'stg_orders_conformed'
    __table_args__ = (
        Index('idx_order_id', 'order_id'),
        Index('idx_customer_key', 'customer_business_key'),
        Index('idx_order_date', 'order_date'),
        Index('idx_product_sku', 'product_sku'),
    )

    order_sk = Column(BigInteger, primary_key=True, autoincrement=True)
    order_id = Column(String(50), nullable=False, unique=True)
    order_source_id = Column(String(50))
    order_date = Column(Date, nullable=False)
    order_timestamp = Column(DateTime, nullable=False)
    customer_business_key = Column(String(100), nullable=False)
    product_sku = Column(String(50), nullable=False)
    warehouse_code = Column(String(10))
    
    # Order Details
    order_quantity = Column(DECIMAL(12, 2), nullable=False)
    unit_price = Column(DECIMAL(12, 4), nullable=False)
    gross_amount = Column(DECIMAL(14, 2))
    discount_percent = Column(DECIMAL(5, 2))
    discount_amount = Column(DECIMAL(12, 2))
    net_amount = Column(DECIMAL(14, 2))
    
    # Cost & Margin
    product_cost = Column(DECIMAL(12, 4))
    freight_cost = Column(DECIMAL(10, 2))
    duty_cost = Column(DECIMAL(10, 2))
    gross_profit = Column(DECIMAL(14, 2))
    gross_margin_percent = Column(DECIMAL(5, 2))
    
    # Delivery
    requested_delivery_date = Column(Date)
    actual_delivery_date = Column(Date)
    delivery_days = Column(Integer)
    on_time_delivery_flag = Column(Boolean, default=False)
    
    # Status
    order_status_code = Column(String(20))
    is_cancelled = Column(Boolean, default=False)
    is_returned = Column(Boolean, default=False)
    return_reason_code = Column(String(50))
    
    # Metadata
    record_load_timestamp = Column(DateTime, default=datetime.utcnow)
    source_load_date = Column(Date)
    source_system_code = Column(String(20))
    dq_validation_status = Column(String(20))
    dq_validation_message = Column(Text)

    def __repr__(self) -> str:
        return f"<StagingOrder {self.order_id}: ${self.net_amount}>"


class StagingCustomersConformed(Base):
    """Conformed staging table for Salesforce customers."""
    __tablename__ = 'stg_customers_conformed'
    __table_args__ = (
        Index('idx_customer_id', 'customer_id'),
        Index('idx_customer_segment', 'customer_segment'),
        Index('idx_subscription_status', 'subscription_status'),
    )

    customer_sk = Column(BigInteger, primary_key=True, autoincrement=True)
    customer_id = Column(String(100), nullable=False, unique=True)
    customer_source_id = Column(String(100))
    customer_name = Column(String(200), nullable=False)
    customer_type = Column(String(50))
    
    # Contact Info
    primary_contact_name = Column(String(200))
    primary_contact_email = Column(String(100))
    primary_contact_phone = Column(String(20))
    billing_address = Column(String(500))
    billing_city = Column(String(100))
    billing_state = Column(String(50))
    billing_country = Column(String(100))
    billing_postal_code = Column(String(20))
    
    # Profile
    industry = Column(String(100))
    annual_revenue = Column(DECIMAL(14, 2))
    employee_count = Column(Integer)
    annual_contract_value = Column(DECIMAL(14, 2))
    lifetime_value = Column(DECIMAL(14, 2))
    customer_segment = Column(String(50))
    customer_sub_segment = Column(String(100))
    
    # Engagement
    accounts_created_date = Column(Date)
    first_purchase_date = Column(Date)
    last_purchase_date = Column(Date)
    total_purchases = Column(Integer)
    days_since_last_purchase = Column(Integer)
    
    # Support & Satisfaction
    support_tier = Column(String(50))
    satisfaction_score = Column(DECIMAL(3, 1))
    nps_score = Column(Integer)
    open_support_tickets = Column(Integer)
    
    # Subscription
    is_active_customer = Column(Boolean, default=True)
    subscription_status = Column(String(50))
    subscription_end_date = Column(Date)
    
    # Metadata
    record_load_timestamp = Column(DateTime, default=datetime.utcnow)
    source_load_date = Column(Date)
    source_system_code = Column(String(20))

    def __repr__(self) -> str:
        return f"<Customer {self.customer_id}: {self.customer_name}>"


class StagingOpportunitiesConformed(Base):
    """Conformed staging table for Salesforce opportunities."""
    __tablename__ = 'stg_opportunities_conformed'
    __table_args__ = (
        Index('idx_opportunity_id', 'opportunity_id'),
        Index('idx_customer_id', 'customer_id'),
        Index('idx_opportunity_stage', 'opportunity_stage'),
        Index('idx_close_date', 'close_date'),
    )

    opportunity_sk = Column(BigInteger, primary_key=True, autoincrement=True)
    opportunity_id = Column(String(100), nullable=False, unique=True)
    opportunity_source_id = Column(String(100))
    customer_id = Column(String(100), nullable=False)
    
    # Details
    opportunity_name = Column(String(500))
    opportunity_stage = Column(String(100))
    close_date = Column(Date)
    close_month = Column(String(7))
    
    # Financial
    opportunity_amount = Column(DECIMAL(14, 2))
    weighted_forecast = Column(DECIMAL(14, 2))
    probability_percent = Column(DECIMAL(5, 2))
    expected_value = Column(DECIMAL(14, 2))
    
    # Deal
    deal_type = Column(String(50))
    competition_level = Column(String(50))
    
    # Dates
    opportunity_created_date = Column(Date)
    opportunity_created_timestamp = Column(DateTime)
    last_activity_date = Column(Date)
    sales_cycle_days = Column(Integer)
    
    # Sales Info
    account_owner_id = Column(String(100))
    account_owner_name = Column(String(200))
    sales_region = Column(String(100))
    
    # Outcomes
    is_won = Column(Boolean, default=False)
    is_lost = Column(Boolean, default=False)
    loss_reason = Column(String(500))
    
    # Metadata
    record_load_timestamp = Column(DateTime, default=datetime.utcnow)
    source_load_date = Column(Date)
    source_system_code = Column(String(20))

    def __repr__(self) -> str:
        return f"<Opportunity {self.opportunity_id}: ${self.opportunity_amount}>"


class StagingInventoryConformed(Base):
    """Conformed staging table for warehouse inventory."""
    __tablename__ = 'stg_inventory_conformed'
    __table_args__ = (
        Index('idx_warehouse_product', 'warehouse_code', 'product_sku'),
        Index('idx_inventory_date', 'inventory_date'),
    )

    inventory_sk = Column(BigInteger, primary_key=True, autoincrement=True)
    inventory_business_key = Column(String(100), nullable=False)
    warehouse_code = Column(String(10))
    product_sku = Column(String(50))
    inventory_date = Column(Date, nullable=False)
    
    # Quantities
    opening_quantity = Column(DECIMAL(12, 2))
    receipts_quantity = Column(DECIMAL(12, 2))
    issues_quantity = Column(DECIMAL(12, 2))
    adjustments_quantity = Column(DECIMAL(12, 2))
    closing_quantity = Column(DECIMAL(12, 2))
    
    # Values
    inventory_value = Column(DECIMAL(14, 2))
    obsolete_value = Column(DECIMAL(12, 2))
    
    # Metrics
    days_on_hand = Column(Integer)
    inventory_turnover = Column(DECIMAL(10, 2))
    slow_moving_flag = Column(Boolean, default=False)
    obsolete_flag = Column(Boolean, default=False)
    
    # Metadata
    source_load_date = Column(Date)
    source_system_code = Column(String(20))

    def __repr__(self) -> str:
        return f"<Inventory {self.product_sku} @ {self.warehouse_code}>"


class StagingCustomerInteractionsConformed(Base):
    """Conformed staging table for customer interactions."""
    __tablename__ = 'stg_customer_interactions_conformed'
    __table_args__ = (
        Index('idx_customer_id', 'customer_id'),
        Index('idx_interaction_date', 'interaction_date'),
        Index('idx_interaction_type', 'interaction_type'),
    )

    interaction_sk = Column(BigInteger, primary_key=True, autoincrement=True)
    interaction_id = Column(String(100), nullable=False, unique=True)
    customer_id = Column(String(100))
    employee_id = Column(String(100))
    interaction_type = Column(String(50))
    interaction_date = Column(Date)
    interaction_timestamp = Column(DateTime)
    
    # Duration
    interaction_duration_minutes = Column(Integer)
    wait_time_minutes = Column(Integer)
    
    # Details
    interaction_topic = Column(String(200))
    interaction_outcome = Column(String(100))
    is_successful = Column(Boolean)
    
    # Engagement
    engagement_score = Column(DECIMAL(3, 1))
    sentiment_score = Column(DECIMAL(3, 1))
    satisfaction_rating = Column(DECIMAL(3, 1))
    
    # Follow-up
    requires_followup = Column(Boolean, default=False)
    followup_date = Column(Date)
    
    # Metadata
    source_load_date = Column(Date)
    source_system_code = Column(String(20))

    def __repr__(self) -> str:
        return f"<Interaction {self.interaction_id}: {self.interaction_type}>"


# ============================================================
# DIMENSION MODELS
# ============================================================

class DimensionCustomer(Base):
    """Customer dimension with SCD Type 2 tracking."""
    __tablename__ = 'dim_customer'
    __table_args__ = (
        Index('idx_business_key', 'business_key'),
        Index('idx_is_current', 'is_current'),
        Index('idx_effective_date', 'effective_date'),
    )

    customer_key = Column(BigInteger, primary_key=True, autoincrement=True)
    business_key = Column(String(100), nullable=False)
    customer_name = Column(String(200))
    customer_type = Column(String(50))
    industry = Column(String(100))
    
    # SCD Type 2 Attributes (tracked)
    annual_contract_value = Column(DECIMAL(14, 2))
    customer_segment = Column(String(50))
    subscription_status = Column(String(50))
    
    # Type 1 Attributes (overwritten)
    is_active_customer = Column(Boolean, default=True)
    
    # SCD tracking
    effective_date = Column(Date, nullable=False)
    end_date = Column(Date, default=date(9999, 12, 31))
    is_current = Column(Boolean, default=True, index=True)
    
    # Audit
    created_date = Column(DateTime, default=datetime.utcnow)
    last_update_date = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<DimCustomer {self.business_key}>"


class DimensionProduct(Base):
    """Product dimension with SCD Type 2 tracking."""
    __tablename__ = 'dim_product'
    __table_args__ = (
        Index('idx_business_key', 'business_key'),
        Index('idx_is_current', 'is_current'),
    )

    product_key = Column(BigInteger, primary_key=True, autoincrement=True)
    business_key = Column(String(100), nullable=False)
    product_name = Column(String(200))
    product_category = Column(String(100))
    
    # SCD Type 2 Attributes
    unit_price = Column(DECIMAL(12, 4))
    supplier_id = Column(String(100))
    lead_time_days = Column(Integer)
    
    # Type 1 Attributes
    is_active = Column(Boolean, default=True)
    
    # SCD tracking
    effective_date = Column(Date, nullable=False)
    end_date = Column(Date, default=date(9999, 12, 31))
    is_current = Column(Boolean, default=True, index=True)
    
    # Audit
    created_date = Column(DateTime, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<DimProduct {self.business_key}>"


class DimensionDate(Base):
    """Date reference dimension."""
    __tablename__ = 'dim_date'

    date_key = Column(Integer, primary_key=True)
    date_value = Column(Date, nullable=False, unique=True)
    year_number = Column(Integer)
    month_number = Column(Integer)
    day_of_month = Column(Integer)
    day_of_week = Column(Integer)
    week_of_year = Column(Integer)
    quarter_number = Column(Integer)
    fiscal_year = Column(Integer)
    date_description = Column(String(50))
    is_weekend = Column(Boolean, default=False)
    is_holiday = Column(Boolean, default=False)

    def __repr__(self) -> str:
        return f"<DimDate {self.date_value}>"


# ============================================================
# FACT MODELS
# ============================================================

class FactSales(Base):
    """Sales fact table - transactional grain (one row per order line)."""
    __tablename__ = 'fact_sales'
    __table_args__ = (
        Index('idx_order_id', 'order_business_key'),
        Index('idx_order_date_key', 'order_date_key'),
        Index('idx_customer_key', 'customer_key'),
        Index('idx_load_date', 'load_date'),
    )

    sales_key = Column(BigInteger, primary_key=True, autoincrement=True)
    order_business_key = Column(String(50), nullable=False)
    order_date_key = Column(Integer)
    order_timestamp = Column(DateTime)
    
    # Dimension keys
    customer_key = Column(BigInteger, default=-1)
    product_key = Column(BigInteger, default=-1)
    warehouse_key = Column(BigInteger, default=-1)
    
    # Metrics
    order_quantity = Column(DECIMAL(12, 2))
    unit_price = Column(DECIMAL(12, 4))
    gross_amount = Column(DECIMAL(14, 2))
    discount_percent = Column(DECIMAL(5, 2))
    discount_amount = Column(DECIMAL(12, 2))
    net_amount = Column(DECIMAL(14, 2))
    
    # Costs & Margins
    product_cost = Column(DECIMAL(12, 4))
    freight_cost = Column(DECIMAL(10, 2))
    duty_cost = Column(DECIMAL(10, 2))
    gross_profit = Column(DECIMAL(14, 2))
    gross_margin_percent = Column(DECIMAL(5, 2))
    
    # Fulfillment
    delivery_days = Column(Integer)
    on_time_delivery_flag = Column(Boolean, default=False)
    
    # Status
    order_status = Column(String(20))
    is_cancelled = Column(Boolean, default=False)
    is_returned = Column(Boolean, default=False)
    
    # Metadata
    load_date = Column(Date)
    etl_load_timestamp = Column(DateTime, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<FactSales {self.order_business_key}: ${self.net_amount}>"


class FactRevenue(Base):
    """Revenue fact table - daily aggregates."""
    __tablename__ = 'fact_revenue'
    __table_args__ = (
        Index('idx_date_key', 'date_key'),
        Index('idx_customer_key', 'customer_key'),
        Index('idx_load_date', 'load_date'),
    )

    revenue_key = Column(BigInteger, primary_key=True, autoincrement=True)
    date_key = Column(Integer)
    customer_key = Column(BigInteger)
    product_key = Column(BigInteger)
    warehouse_key = Column(BigInteger)
    
    # Aggregates
    total_orders = Column(Integer)
    total_quantity = Column(DECIMAL(14, 2))
    total_gross_amount = Column(DECIMAL(14, 2))
    total_discount_amount = Column(DECIMAL(14, 2))
    total_net_revenue = Column(DECIMAL(14, 2))
    
    # Costs
    total_product_cost = Column(DECIMAL(14, 2))
    total_freight_cost = Column(DECIMAL(14, 2))
    total_duty_cost = Column(DECIMAL(14, 2))
    total_gross_profit = Column(DECIMAL(14, 2))
    avg_margin_percent = Column(DECIMAL(5, 2))
    
    # Fulfillment
    avg_delivery_days = Column(DECIMAL(5, 2))
    on_time_count = Column(Integer)
    late_count = Column(Integer)
    
    # Metadata
    load_date = Column(Date)
    etl_load_timestamp = Column(DateTime, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<FactRevenue ${self.total_net_revenue}>"


class FactCustomerInteractions(Base):
    """Customer interactions fact table."""
    __tablename__ = 'fact_customer_interactions'
    __table_args__ = (
        Index('idx_interaction_id', 'interaction_business_key'),
        Index('idx_customer_key', 'customer_key'),
        Index('idx_interaction_date_key', 'interaction_date_key'),
    )

    interaction_key = Column(BigInteger, primary_key=True, autoincrement=True)
    interaction_business_key = Column(String(100))
    interaction_date_key = Column(Integer)
    interaction_type = Column(String(50))
    
    # Dimension keys
    customer_key = Column(BigInteger, default=-1)
    employee_key = Column(BigInteger, default=-1)
    
    # Details
    interaction_timestamp = Column(DateTime)
    interaction_duration_minutes = Column(Integer)
    interaction_outcome = Column(String(100))
    is_successful = Column(Boolean)
    
    # Engagement
    engagement_score = Column(DECIMAL(3, 1))
    
    # Metadata
    created_date = Column(Date)
    etl_load_timestamp = Column(DateTime, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<FactInteraction {self.interaction_business_key}>"


# ============================================================
# SUPPORT/TRACKING MODELS
# ============================================================

class ETLLog(Base):
    """ETL execution logs."""
    __tablename__ = 'etl_logs'
    __table_args__ = (
        Index('idx_process_name', 'process_name'),
        Index('idx_status', 'status'),
        Index('idx_log_date', 'log_date'),
    )

    log_id = Column(BigInteger, primary_key=True, autoincrement=True)
    process_name = Column(String(200), nullable=False)
    process_step = Column(String(200))
    record_count = Column(Integer)
    status = Column(String(20))  # SUCCESS, FAILED, WARNING
    log_date = Column(Date)
    log_timestamp = Column(DateTime, default=datetime.utcnow)
    details = Column(Text)

    def __repr__(self) -> str:
        return f"<ETLLog {self.process_name}: {self.status}>"


class DataQualityScore(Base):
    """Data quality scores per load."""
    __tablename__ = 'dq_scores'
    __table_args__ = (
        Index('idx_load_date', 'load_date'),
    )

    dq_score_id = Column(BigInteger, primary_key=True, autoincrement=True)
    load_date = Column(Date)
    calculation_timestamp = Column(DateTime, default=datetime.utcnow)
    
    # Component scores
    completeness_score = Column(DECIMAL(5, 2))
    accuracy_score = Column(DECIMAL(5, 2))
    consistency_score = Column(DECIMAL(5, 2))
    timeliness_score = Column(DECIMAL(5, 2))
    validity_score = Column(DECIMAL(5, 2))
    
    # Overall
    overall_dq_score = Column(DECIMAL(5, 2))
    dq_status = Column(String(20))  # Excellent, Good, Fair, Poor

    def __repr__(self) -> str:
        return f"<DQScore {self.load_date}: {self.overall_dq_score}%>"


class KPIResult(Base):
    """KPI calculation results."""
    __tablename__ = 'kpi_results'
    __table_args__ = (
        Index('idx_kpi_name', 'kpi_name'),
        Index('idx_kpi_category', 'kpi_category'),
        Index('idx_calculation_date', 'calculation_date'),
    )

    kpi_result_id = Column(BigInteger, primary_key=True, autoincrement=True)
    kpi_name = Column(String(200), nullable=False)
    kpi_category = Column(String(100))  # Financial, Sales, Customer, Operational, HR
    kpi_value = Column(DECIMAL(18, 4))
    unit_of_measure = Column(String(50))
    calculation_date = Column(Date)
    target_value = Column(DECIMAL(18, 4))
    actual_value = Column(DECIMAL(18, 4))
    variance = Column(DECIMAL(18, 4))
    status = Column(String(20))  # Green, Yellow, Red
    calculation_timestamp = Column(DateTime, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<KPI {self.kpi_name}: {self.kpi_value} {self.status}>"


class ReconciliationLog(Base):
    """ETL reconciliation tracking."""
    __tablename__ = 'etl_reconciliation'
    __table_args__ = (
        Index('idx_load_date', 'load_date'),
        Index('idx_reconciliation_type', 'reconciliation_type'),
    )

    reconciliation_id = Column(BigInteger, primary_key=True, autoincrement=True)
    load_date = Column(Date)
    reconciliation_type = Column(String(50))  # Orders, Customers, etc.
    source_name = Column(String(100))
    
    # Record counts
    source_record_count = Column(Integer)
    staging_record_count = Column(Integer)
    fact_record_count = Column(Integer)
    
    # Amounts
    source_total_amount = Column(DECIMAL(14, 2))
    staging_total_amount = Column(DECIMAL(14, 2))
    fact_total_amount = Column(DECIMAL(14, 2))
    
    # Variance
    record_variance = Column(Integer)
    amount_variance_percent = Column(DECIMAL(5, 2))
    reconciliation_status = Column(String(20))  # PASS, FAIL
    reconciliation_notes = Column(Text)

    def __repr__(self) -> str:
        return f"<Reconciliation {self.reconciliation_type}: {self.reconciliation_status}>"
