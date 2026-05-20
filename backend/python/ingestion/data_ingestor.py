"""
Data Ingestion Scripts
======================
Extract and load data from various source systems into staging tables.
Handles ERP, Salesforce, Finance, and other source systems.
"""

import logging
from datetime import datetime, timedelta, date
from typing import List, Dict, Optional, Any, Tuple
from dataclasses import dataclass
import json
import pandas as pd
from sqlalchemy.orm import Session
from sqlalchemy import text
import requests

from database import get_db_session
from models import (
    StagingOrdersConformed, StagingCustomersConformed,
    StagingOpportunitiesConformed, StagingInventoryConformed,
    StagingCustomerInteractionsConformed, ETLLog
)

logger = logging.getLogger(__name__)


@dataclass
class IngestorConfig:
    """Configuration for data ingestion."""
    batch_size: int = 1000
    max_retries: int = 3
    retry_delay: int = 5  # seconds
    timeout: int = 300  # seconds
    log_level: str = "INFO"


class BaseIngestor:
    """Base class for all data ingestors."""
    
    def __init__(self, config: Optional[IngestorConfig] = None):
        self.config = config or IngestorConfig()
        self.session: Optional[Session] = None
        self.logger = logging.getLogger(self.__class__.__name__)
        self.logger.setLevel(getattr(logging, self.config.log_level))

    def __enter__(self):
        """Context manager entry."""
        self.session = get_db_session()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        if self.session:
            self.session.close()

    def get_session(self) -> Session:
        """Get or create database session."""
        if self.session is None:
            self.session = get_db_session()
        return self.session

    def bulk_insert(self, objects: List[Any], model_name: str = "Records") -> int:
        """Insert multiple objects in batches."""
        session = self.get_session()
        inserted = 0
        
        try:
            for i in range(0, len(objects), self.config.batch_size):
                batch = objects[i:i + self.config.batch_size]
                session.add_all(batch)
                session.commit()
                inserted += len(batch)
                self.logger.info(f"Inserted {inserted}/{len(objects)} {model_name}")
            
            return inserted
        
        except Exception as e:
            session.rollback()
            self.logger.error(f"Error during bulk insert: {e}")
            raise

    def log_etl_event(self, process_name: str, step: str, record_count: int,
                      status: str = "SUCCESS", details: str = "") -> None:
        """Log ETL execution event."""
        session = self.get_session()
        
        try:
            log = ETLLog(
                process_name=process_name,
                process_step=step,
                record_count=record_count,
                status=status,
                log_date=date.today(),
                details=details
            )
            session.add(log)
            session.commit()
            self.logger.info(f"ETL Log: {process_name} - {step} - {status}")
        
        except Exception as e:
            session.rollback()
            self.logger.error(f"Error logging ETL event: {e}")

    def truncate_staging_table(self, table_name: str) -> None:
        """Truncate staging table."""
        session = self.get_session()
        
        try:
            session.execute(text(f"TRUNCATE TABLE {table_name}"))
            session.commit()
            self.logger.info(f"Truncated {table_name}")
        except Exception as e:
            session.rollback()
            self.logger.error(f"Error truncating {table_name}: {e}")
            raise


class ERPOrdersIngestor(BaseIngestor):
    """Ingest order data from ERP systems (SAP/Oracle)."""
    
    def ingest_from_query(self, sql_query: str, load_date: Optional[date] = None) -> int:
        """
        Load orders from ERP system via SQL query.
        
        Args:
            sql_query: SQL query to extract orders
            load_date: Date to assign to source_load_date
        
        Returns:
            Number of records inserted
        """
        load_date = load_date or date.today()
        session = self.get_session()
        
        try:
            self.logger.info(f"Executing ERP query for {load_date}")
            
            # Execute query to get raw data
            result = session.execute(text(sql_query))
            rows = result.fetchall()
            
            self.logger.info(f"Retrieved {len(rows)} orders from ERP")
            
            # Transform and create model instances
            orders = []
            for row in rows:
                # Assuming row structure from stg_raw_erp_orders
                order = StagingOrdersConformed(
                    order_id=row[0],
                    order_source_id=row[1],
                    order_date=row[2],
                    order_timestamp=row[3],
                    customer_business_key=row[4] or 'UNKNOWN',
                    product_sku=row[5],
                    warehouse_code=row[6],
                    order_quantity=row[7],
                    unit_price=row[8],
                    gross_amount=row[9],
                    discount_percent=row[10] or 0,
                    discount_amount=row[11] or 0,
                    net_amount=row[12],
                    product_cost=row[13] or 0,
                    freight_cost=row[14] or 0,
                    duty_cost=row[15] or 0,
                    order_status_code=row[16],
                    requested_delivery_date=row[17],
                    actual_delivery_date=row[18],
                    source_load_date=load_date,
                    source_system_code='ERP',
                    dq_validation_status='PENDING'
                )
                orders.append(order)
            
            # Bulk insert
            inserted = self.bulk_insert(orders, "ERP Orders")
            
            # Log event
            self.log_etl_event(
                process_name="sp_ingest_erp_orders",
                step="Load",
                record_count=inserted,
                status="SUCCESS",
                details=f"Loaded {inserted} orders from ERP"
            )
            
            return inserted
        
        except Exception as e:
            self.logger.error(f"Error ingesting ERP orders: {e}")
            self.log_etl_event(
                process_name="sp_ingest_erp_orders",
                step="Load",
                record_count=0,
                status="FAILED",
                details=str(e)
            )
            raise

    def ingest_from_csv(self, csv_file: str, load_date: Optional[date] = None) -> int:
        """Load orders from CSV file."""
        load_date = load_date or date.today()
        
        try:
            self.logger.info(f"Loading orders from CSV: {csv_file}")
            
            df = pd.read_csv(csv_file)
            self.logger.info(f"Read {len(df)} rows from CSV")
            
            orders = []
            for idx, row in df.iterrows():
                order = StagingOrdersConformed(
                    order_id=row['order_id'],
                    order_source_id=row.get('order_source_id'),
                    order_date=pd.to_datetime(row['order_date']).date(),
                    order_timestamp=pd.to_datetime(row['order_timestamp']),
                    customer_business_key=row.get('customer_code', 'UNKNOWN'),
                    product_sku=row['product_code'],
                    warehouse_code=row.get('warehouse_code'),
                    order_quantity=float(row['quantity']),
                    unit_price=float(row['unit_price']),
                    gross_amount=float(row.get('gross_amount', 0)),
                    discount_percent=float(row.get('discount_percent', 0)),
                    discount_amount=float(row.get('discount_amount', 0)),
                    net_amount=float(row.get('net_amount', 0)),
                    product_cost=float(row.get('product_cost', 0)),
                    freight_cost=float(row.get('freight_cost', 0)),
                    duty_cost=float(row.get('duty_cost', 0)),
                    order_status_code=row.get('status'),
                    requested_delivery_date=pd.to_datetime(row.get('requested_delivery_date')).date() if pd.notna(row.get('requested_delivery_date')) else None,
                    actual_delivery_date=pd.to_datetime(row.get('actual_delivery_date')).date() if pd.notna(row.get('actual_delivery_date')) else None,
                    source_load_date=load_date,
                    source_system_code='ERP',
                    dq_validation_status='PENDING'
                )
                orders.append(order)
            
            inserted = self.bulk_insert(orders, "ERP Orders from CSV")
            return inserted
        
        except Exception as e:
            self.logger.error(f"Error ingesting ERP orders from CSV: {e}")
            raise


class SalesforceIngestor(BaseIngestor):
    """Ingest data from Salesforce via API."""
    
    def __init__(self, config: Optional[IngestorConfig] = None, api_token: Optional[str] = None,
                 instance_url: Optional[str] = None):
        super().__init__(config)
        self.api_token = api_token or ""
        self.instance_url = instance_url or ""
        self.headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json"
        }

    def ingest_customers(self, load_date: Optional[date] = None) -> int:
        """Ingest customer data from Salesforce."""
        load_date = load_date or date.today()
        
        try:
            self.logger.info("Fetching customers from Salesforce")
            
            # Example: Query Salesforce SOQL API
            soql_query = (
                "SELECT Id, Name, Industry, Type, AnnualRevenue, NumberOfEmployees, "
                "CreatedDate, LastActivityDate FROM Account LIMIT 10000"
            )
            
            url = f"{self.instance_url}/services/data/v57.0/query"
            params = {"q": soql_query}
            
            response = requests.get(url, headers=self.headers, params=params, timeout=self.config.timeout)
            response.raise_for_status()
            
            data = response.json()
            records = data.get('records', [])
            
            self.logger.info(f"Retrieved {len(records)} customers from Salesforce")
            
            customers = []
            for record in records:
                customer = StagingCustomersConformed(
                    customer_id=record['Id'],
                    customer_source_id=record['Id'],
                    customer_name=record['Name'],
                    customer_type=record.get('Type'),
                    industry=record.get('Industry'),
                    annual_revenue=record.get('AnnualRevenue'),
                    employee_count=record.get('NumberOfEmployees'),
                    accounts_created_date=pd.to_datetime(record['CreatedDate']).date(),
                    source_load_date=load_date,
                    source_system_code='SALESFORCE'
                )
                customers.append(customer)
            
            inserted = self.bulk_insert(customers, "Salesforce Customers")
            return inserted
        
        except requests.RequestException as e:
            self.logger.error(f"Salesforce API error: {e}")
            raise
        except Exception as e:
            self.logger.error(f"Error ingesting Salesforce customers: {e}")
            raise

    def ingest_opportunities(self, load_date: Optional[date] = None) -> int:
        """Ingest opportunity data from Salesforce."""
        load_date = load_date or date.today()
        
        try:
            self.logger.info("Fetching opportunities from Salesforce")
            
            soql_query = (
                "SELECT Id, AccountId, Name, StageName, Amount, Probability, "
                "CloseDate, CreatedDate, IsClosed, IsWon FROM Opportunity "
                "WHERE CreatedDate = THIS_MONTH"
            )
            
            url = f"{self.instance_url}/services/data/v57.0/query"
            params = {"q": soql_query}
            
            response = requests.get(url, headers=self.headers, params=params, timeout=self.config.timeout)
            response.raise_for_status()
            
            data = response.json()
            records = data.get('records', [])
            
            self.logger.info(f"Retrieved {len(records)} opportunities from Salesforce")
            
            opportunities = []
            for record in records:
                opp = StagingOpportunitiesConformed(
                    opportunity_id=record['Id'],
                    opportunity_source_id=record['Id'],
                    customer_id=record['AccountId'],
                    opportunity_name=record['Name'],
                    opportunity_stage=record['StageName'],
                    opportunity_amount=record.get('Amount'),
                    probability_percent=record.get('Probability'),
                    close_date=pd.to_datetime(record['CloseDate']).date() if record.get('CloseDate') else None,
                    opportunity_created_date=pd.to_datetime(record['CreatedDate']).date(),
                    opportunity_created_timestamp=pd.to_datetime(record['CreatedDate']),
                    is_won=record.get('IsWon', False),
                    is_lost=record.get('IsClosed', False) and not record.get('IsWon', False),
                    source_load_date=load_date,
                    source_system_code='SALESFORCE'
                )
                opportunities.append(opp)
            
            inserted = self.bulk_insert(opportunities, "Salesforce Opportunities")
            return inserted
        
        except Exception as e:
            self.logger.error(f"Error ingesting Salesforce opportunities: {e}")
            raise


class InventoryIngestor(BaseIngestor):
    """Ingest warehouse inventory data."""
    
    def ingest_from_json(self, json_file: str, load_date: Optional[date] = None) -> int:
        """Load inventory data from JSON file."""
        load_date = load_date or date.today()
        
        try:
            self.logger.info(f"Loading inventory from JSON: {json_file}")
            
            with open(json_file, 'r') as f:
                data = json.load(f)
            
            records = data if isinstance(data, list) else data.get('records', [])
            self.logger.info(f"Read {len(records)} inventory records from JSON")
            
            inventories = []
            for record in records:
                inv = StagingInventoryConformed(
                    inventory_business_key=record.get('inventory_id'),
                    warehouse_code=record['warehouse_code'],
                    product_sku=record['product_code'],
                    inventory_date=pd.to_datetime(record['inventory_date']).date(),
                    opening_quantity=float(record.get('opening_qty', 0)),
                    receipts_quantity=float(record.get('receipt_qty', 0)),
                    issues_quantity=float(record.get('issue_qty', 0)),
                    adjustments_quantity=float(record.get('adjustment_qty', 0)),
                    closing_quantity=float(record.get('closing_qty', 0)),
                    inventory_value=float(record.get('inventory_value', 0)),
                    days_on_hand=int(record.get('days_on_hand', 0)),
                    source_load_date=load_date,
                    source_system_code='WAREHOUSE_OPS'
                )
                inventories.append(inv)
            
            inserted = self.bulk_insert(inventories, "Inventory Records")
            return inserted
        
        except Exception as e:
            self.logger.error(f"Error ingesting inventory from JSON: {e}")
            raise


class InteractionsIngestor(BaseIngestor):
    """Ingest customer interaction data."""
    
    def ingest_from_api(self, api_url: str, api_token: str, 
                       load_date: Optional[date] = None) -> int:
        """Load interactions from API endpoint."""
        load_date = load_date or date.today()
        
        try:
            self.logger.info(f"Fetching interactions from API: {api_url}")
            
            headers = {"Authorization": f"Bearer {api_token}"}
            params = {
                "start_date": (load_date - timedelta(days=1)).isoformat(),
                "end_date": load_date.isoformat(),
                "limit": 10000
            }
            
            response = requests.get(api_url, headers=headers, params=params, 
                                   timeout=self.config.timeout)
            response.raise_for_status()
            
            data = response.json()
            records = data.get('interactions', [])
            
            self.logger.info(f"Retrieved {len(records)} interactions")
            
            interactions = []
            for record in records:
                interaction = StagingCustomerInteractionsConformed(
                    interaction_id=record['id'],
                    customer_id=record.get('customer_id'),
                    employee_id=record.get('agent_id'),
                    interaction_type=record['type'],
                    interaction_date=pd.to_datetime(record['created_at']).date(),
                    interaction_timestamp=pd.to_datetime(record['created_at']),
                    interaction_duration_minutes=int(record.get('duration_seconds', 0) / 60),
                    interaction_outcome=record.get('outcome'),
                    is_successful=record.get('outcome') == 'Resolved',
                    engagement_score=float(record.get('engagement_score', 0)),
                    satisfaction_rating=float(record.get('satisfaction_rating', 0)),
                    source_load_date=load_date,
                    source_system_code='CONTACT_CENTER'
                )
                interactions.append(interaction)
            
            inserted = self.bulk_insert(interactions, "Customer Interactions")
            return inserted
        
        except Exception as e:
            self.logger.error(f"Error ingesting interactions from API: {e}")
            raise


class MasterIngestor:
    """Orchestrate all data ingestion tasks."""
    
    def __init__(self, config: Optional[IngestorConfig] = None):
        self.config = config or IngestorConfig()
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(getattr(logging, self.config.log_level))

    def ingest_all(self, load_date: Optional[date] = None) -> Dict[str, int]:
        """Execute all ingestion tasks."""
        load_date = load_date or date.today()
        results = {}
        
        try:
            self.logger.info(f"Starting master ingestion for {load_date}")
            
            # Ingest ERP Orders
            try:
                with ERPOrdersIngestor(self.config) as ingestor:
                    results['erp_orders'] = ingestor.ingest_from_query(
                        sql_query="SELECT * FROM stg_raw_erp_orders WHERE CAST(LOAD_DATE AS DATE) = CAST(GETDATE() AS DATE)",
                        load_date=load_date
                    )
            except Exception as e:
                self.logger.error(f"Failed to ingest ERP orders: {e}")
                results['erp_orders'] = 0
            
            # Ingest Salesforce data
            try:
                with SalesforceIngestor(self.config) as ingestor:
                    results['salesforce_customers'] = ingestor.ingest_customers(load_date)
                    results['salesforce_opportunities'] = ingestor.ingest_opportunities(load_date)
            except Exception as e:
                self.logger.error(f"Failed to ingest Salesforce data: {e}")
                results['salesforce_customers'] = 0
                results['salesforce_opportunities'] = 0
            
            # Ingest Inventory
            try:
                with InventoryIngestor(self.config) as ingestor:
                    results['inventory'] = ingestor.ingest_from_json(
                        json_file="data/inventory.json",
                        load_date=load_date
                    )
            except Exception as e:
                self.logger.error(f"Failed to ingest inventory: {e}")
                results['inventory'] = 0
            
            self.logger.info(f"Master ingestion complete: {results}")
            return results
        
        except Exception as e:
            self.logger.error(f"Master ingestion failed: {e}")
            raise


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    config = IngestorConfig(batch_size=1000)
    
    # Ingest ERP orders from CSV
    with ERPOrdersIngestor(config) as ingestor:
        count = ingestor.ingest_from_csv("data/erp_orders.csv")
        print(f"Ingested {count} ERP orders")
    
    # Run all ingestion
    master = MasterIngestor(config)
    results = master.ingest_all()
    print(f"Ingestion results: {results}")
