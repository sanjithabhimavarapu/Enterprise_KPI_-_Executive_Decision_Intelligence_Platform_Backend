"""Data ingestion module."""
from .data_ingestor import (
    BaseIngestor,
    ERPOrdersIngestor,
    SalesforceIngestor,
    InventoryIngestor,
    InteractionsIngestor,
    MasterIngestor,
    IngestorConfig
)

__all__ = [
    "BaseIngestor",
    "ERPOrdersIngestor",
    "SalesforceIngestor",
    "InventoryIngestor",
    "InteractionsIngestor",
    "MasterIngestor",
    "IngestorConfig"
]
