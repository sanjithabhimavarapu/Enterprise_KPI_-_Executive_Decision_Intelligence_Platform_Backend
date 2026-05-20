"""
ETL Pipeline Orchestration
===========================
Complete end-to-end ETL pipeline combining ingestion, validation, and reconciliation.
"""

import logging
import sys
from datetime import date, datetime
from typing import Optional, Dict
from pathlib import Path

from database import init_db, DatabaseConfig, close_db
from ingestion.data_ingestor import MasterIngestor, IngestorConfig
from validation.data_validator import MasterValidator
from reconciliation.data_reconciler import MasterReconciler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(f'logs/etl_pipeline_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)

logger = logging.getLogger(__name__)


class ETLPipeline:
    """Master ETL pipeline orchestrator."""
    
    def __init__(self, load_date: Optional[date] = None, config: Optional[DatabaseConfig] = None):
        """
        Initialize ETL pipeline.
        
        Args:
            load_date: Date to process (default: today)
            config: Database configuration
        """
        self.load_date = load_date or date.today()
        self.config = config or DatabaseConfig()
        self.start_time = None
        self.end_time = None
        self.execution_logs: Dict[str, Dict] = {}
        
    def initialize(self) -> bool:
        """Initialize database connection."""
        try:
            logger.info("=" * 70)
            logger.info("ETL PIPELINE INITIALIZATION")
            logger.info("=" * 70)
            logger.info(f"Load Date: {self.load_date}")
            logger.info(f"Config: {self.config}")
            
            self.db = init_db(self.config, echo=False)
            logger.info("✓ Database connection initialized")
            return True
            
        except Exception as e:
            logger.error(f"✗ Failed to initialize database: {e}")
            return False

    def run_ingestion(self) -> bool:
        """Execute data ingestion."""
        try:
            logger.info("\n" + "=" * 70)
            logger.info("STAGE 1: DATA INGESTION")
            logger.info("=" * 70)
            
            ingestor_config = IngestorConfig(batch_size=1000)
            ingestor = MasterIngestor(ingestor_config)
            
            results = ingestor.ingest_all(self.load_date)
            
            logger.info("✓ Ingestion completed:")
            for source, count in results.items():
                logger.info(f"  - {source}: {count} records")
            
            self.execution_logs['ingestion'] = {
                'status': 'SUCCESS',
                'results': results,
                'timestamp': datetime.now()
            }
            return True
            
        except Exception as e:
            logger.error(f"✗ Ingestion failed: {e}")
            self.execution_logs['ingestion'] = {
                'status': 'FAILED',
                'error': str(e),
                'timestamp': datetime.now()
            }
            return False

    def run_validation(self) -> bool:
        """Execute data quality validation."""
        try:
            logger.info("\n" + "=" * 70)
            logger.info("STAGE 2: DATA QUALITY VALIDATION")
            logger.info("=" * 70)
            
            validator = MasterValidator(self.load_date)
            result = validator.validate_all()
            
            logger.info(f"✓ Validation Summary: {result}")
            logger.info(f"  - Status: {result.status}")
            logger.info(f"  - Quality Score: {result.validation_percent:.2f}%")
            logger.info(f"  - Details: {result.details}")
            
            self.execution_logs['validation'] = {
                'status': result.status,
                'validation_percent': result.validation_percent,
                'total_checks': result.total_records,
                'passed_checks': result.valid_records,
                'timestamp': datetime.now()
            }
            
            # Return based on validation result
            return result.status != 'FAIL'
            
        except Exception as e:
            logger.error(f"✗ Validation failed: {e}")
            self.execution_logs['validation'] = {
                'status': 'FAILED',
                'error': str(e),
                'timestamp': datetime.now()
            }
            return False

    def run_reconciliation(self) -> bool:
        """Execute ETL reconciliation."""
        try:
            logger.info("\n" + "=" * 70)
            logger.info("STAGE 3: ETL RECONCILIATION")
            logger.info("=" * 70)
            
            reconciler = MasterReconciler(self.load_date, variance_tolerance=0.01)
            results = reconciler.reconcile_all()
            
            logger.info(f"✓ Reconciliation Summary:")
            logger.info(f"  - Total: {results['total_reconciliations']}")
            logger.info(f"  - Passed: {results['passed']}")
            logger.info(f"  - Failed: {results['failed']}")
            logger.info(f"  - Warned: {results['warned']}")
            logger.info(f"  - Status: {results['overall_status']}")
            
            logger.info(f"\nReconciliation Details:")
            for detail in results['details']:
                logger.info(f"  - {detail['data_type']}: {detail['status']}")
                logger.info(f"    Variance: {detail['variance_percent']:.2f}%")
            
            self.execution_logs['reconciliation'] = {
                'status': results['overall_status'],
                'results': results,
                'timestamp': datetime.now()
            }
            
            return results['overall_status'] != 'FAIL'
            
        except Exception as e:
            logger.error(f"✗ Reconciliation failed: {e}")
            self.execution_logs['reconciliation'] = {
                'status': 'FAILED',
                'error': str(e),
                'timestamp': datetime.now()
            }
            return False

    def print_final_report(self):
        """Print final ETL report."""
        logger.info("\n" + "=" * 70)
        logger.info("ETL PIPELINE FINAL REPORT")
        logger.info("=" * 70)
        logger.info(f"Load Date: {self.load_date}")
        logger.info(f"Execution Time: {(self.end_time - self.start_time).total_seconds():.2f} seconds")
        logger.info("")
        
        for stage, log in self.execution_logs.items():
            status = log.get('status', 'UNKNOWN')
            logger.info(f"{stage.upper()}: {status}")
            if status == 'SUCCESS' or status == 'PASS':
                logger.info(f"  ✓ Completed successfully")
            elif status == 'WARNING':
                logger.info(f"  ⚠ Completed with warnings")
            else:
                logger.info(f"  ✗ Failed: {log.get('error', 'Unknown error')}")
        
        logger.info("=" * 70)

    def run(self) -> bool:
        """Execute complete ETL pipeline."""
        self.start_time = datetime.now()
        
        try:
            # Stage 1: Initialize
            if not self.initialize():
                return False
            
            # Stage 2: Ingest data
            if not self.run_ingestion():
                logger.warning("Ingestion completed with errors, continuing...")
            
            # Stage 3: Validate data
            if not self.run_validation():
                logger.warning("Validation completed with issues, continuing...")
            
            # Stage 4: Reconcile data
            if not self.run_reconciliation():
                logger.warning("Reconciliation completed with issues")
            
            return True
            
        except Exception as e:
            logger.error(f"✗ Pipeline execution failed: {e}")
            return False
            
        finally:
            self.end_time = datetime.now()
            self.print_final_report()
            close_db()


def main():
    """Entry point for ETL pipeline."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Enterprise KPI ETL Pipeline')
    parser.add_argument(
        '--date',
        type=str,
        default=None,
        help='Load date (YYYY-MM-DD format). Default: today'
    )
    parser.add_argument(
        '--server',
        type=str,
        default='localhost',
        help='Database server. Default: localhost'
    )
    parser.add_argument(
        '--database',
        type=str,
        default='KPI_DataWarehouse',
        help='Database name. Default: KPI_DataWarehouse'
    )
    parser.add_argument(
        '--username',
        type=str,
        default='sa',
        help='Database username. Default: sa'
    )
    parser.add_argument(
        '--password',
        type=str,
        default='',
        help='Database password. Default: from environment'
    )
    
    args = parser.parse_args()
    
    # Parse load date
    load_date = None
    if args.date:
        try:
            load_date = datetime.strptime(args.date, '%Y-%m-%d').date()
        except ValueError:
            logger.error(f"Invalid date format: {args.date}. Use YYYY-MM-DD")
            return False
    
    # Create database config
    config = DatabaseConfig()
    if args.server:
        config.server = args.server
    if args.database:
        config.database = args.database
    if args.username:
        config.username = args.username
    if args.password:
        config.password = args.password
    
    # Run pipeline
    pipeline = ETLPipeline(load_date, config)
    success = pipeline.run()
    
    return 0 if success else 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
