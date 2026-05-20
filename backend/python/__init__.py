"""
Enterprise KPI Platform - Python Backend
========================================
Complete data pipeline for ingestion, validation, and reconciliation.

Package Structure:
- database.py: SQLAlchemy configuration and connection management
- models.py: ORM models for all tables (staging, dimensions, facts)
- ingestion/: Data ingestion from source systems
- validation/: Data quality validation
- reconciliation/: ETL reconciliation and integrity checking
- logging/: Structured logging and monitoring
- automation/: Job scheduling and orchestration
"""

from .database import (
    DatabaseConfig,
    DatabaseConnection,
    init_db,
    get_db_session,
    close_db,
    Base
)

from .models import (
    # Staging
    StagingOrdersConformed,
    StagingCustomersConformed,
    StagingOpportunitiesConformed,
    StagingInventoryConformed,
    StagingCustomerInteractionsConformed,
    # Dimensions
    DimensionCustomer,
    DimensionProduct,
    DimensionDate,
    # Facts
    FactSales,
    FactRevenue,
    FactCustomerInteractions,
    # Support tables
    ETLLog,
    DataQualityScore,
    KPIResult,
    ReconciliationLog
)

__version__ = "1.0.0"
__author__ = "Enterprise KPI Platform Team"

__all__ = [
    # Database
    "DatabaseConfig",
    "DatabaseConnection",
    "init_db",
    "get_db_session",
    "close_db",
    "Base",
    # Models
    "StagingOrdersConformed",
    "StagingCustomersConformed",
    "StagingOpportunitiesConformed",
    "StagingInventoryConformed",
    "StagingCustomerInteractionsConformed",
    "DimensionCustomer",
    "DimensionProduct",
    "DimensionDate",
    "FactSales",
    "FactRevenue",
    "FactCustomerInteractions",
    "ETLLog",
    "DataQualityScore",
    "KPIResult",
    "ReconciliationLog",
]
