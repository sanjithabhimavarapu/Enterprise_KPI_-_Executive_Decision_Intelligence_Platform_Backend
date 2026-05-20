"""
SQLAlchemy Database Configuration
==================================
Centralized database connection and session management for the Enterprise KPI Platform.
Supports SQL Server with connection pooling and configurable retry logic.
"""

import os
from typing import Optional
from sqlalchemy import create_engine, event, pool
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
import logging

logger = logging.getLogger(__name__)

# Base class for all ORM models
Base = declarative_base()


class DatabaseConfig:
    """Database configuration from environment variables."""
    
    def __init__(self):
        self.server = os.getenv('DB_SERVER', 'localhost')
        self.database = os.getenv('DB_NAME', 'KPI_DataWarehouse')
        self.username = os.getenv('DB_USER', 'sa')
        self.password = os.getenv('DB_PASSWORD', 'DefaultPassword123')
        self.port = os.getenv('DB_PORT', '1433')
        self.driver = os.getenv('DB_DRIVER', 'ODBC Driver 17 for SQL Server')
        self.pool_size = int(os.getenv('DB_POOL_SIZE', '10'))
        self.max_overflow = int(os.getenv('DB_MAX_OVERFLOW', '20'))
        self.pool_recycle = int(os.getenv('DB_POOL_RECYCLE', '3600'))
        self.pool_pre_ping = os.getenv('DB_POOL_PRE_PING', 'True').lower() == 'true'

    @property
    def connection_string(self) -> str:
        """Build connection string for SQL Server."""
        return (
            f"mssql+pyodbc://{self.username}:{self.password}@"
            f"{self.server}:{self.port}/{self.database}?"
            f"driver={self.driver.replace(' ', '+')}"
        )

    def __repr__(self) -> str:
        return (
            f"DatabaseConfig(server={self.server}, database={self.database}, "
            f"pool_size={self.pool_size})"
        )


class DatabaseConnection:
    """Manages SQLAlchemy database connection and session lifecycle."""
    
    def __init__(self, config: Optional[DatabaseConfig] = None, echo: bool = False):
        """
        Initialize database connection.
        
        Args:
            config: DatabaseConfig instance. If None, uses environment variables.
            echo: Whether to log SQL statements.
        """
        self.config = config or DatabaseConfig()
        self.engine = None
        self.SessionLocal = None
        self.echo = echo
        self._initialize_engine()

    def _initialize_engine(self):
        """Create SQLAlchemy engine with connection pooling."""
        try:
            logger.info(f"Initializing database connection: {self.config}")
            
            self.engine = create_engine(
                self.config.connection_string,
                echo=self.echo,
                poolclass=QueuePool,
                pool_size=self.config.pool_size,
                max_overflow=self.config.max_overflow,
                pool_recycle=self.config.pool_recycle,
                pool_pre_ping=self.config.pool_pre_ping,
                connect_args={
                    'timeout': 30,
                    'fast_executemany': True,
                    'autocommit': False
                }
            )
            
            # Add connection pool listeners
            @event.listens_for(self.engine, "connect")
            def receive_connect(dbapi_conn, connection_record):
                """Set connection options."""
                cursor = dbapi_conn.cursor()
                cursor.execute("SET NOCOUNT ON")
                cursor.close()
            
            # Create session factory
            self.SessionLocal = sessionmaker(
                autocommit=False,
                autoflush=False,
                bind=self.engine
            )
            
            # Test connection
            self.test_connection()
            logger.info("Database connection initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize database connection: {e}")
            raise

    def test_connection(self) -> bool:
        """Test database connection."""
        try:
            with self.engine.connect() as connection:
                result = connection.execute("SELECT @@VERSION")
                version = result.fetchone()[0]
                logger.info(f"Connected to: {version}")
                return True
        except Exception as e:
            logger.error(f"Database connection test failed: {e}")
            return False

    def get_session(self) -> Session:
        """Get new database session."""
        if self.SessionLocal is None:
            raise RuntimeError("Database connection not initialized")
        return self.SessionLocal()

    def create_tables(self):
        """Create all tables defined in models."""
        try:
            logger.info("Creating database tables...")
            Base.metadata.create_all(bind=self.engine)
            logger.info("Tables created successfully")
        except Exception as e:
            logger.error(f"Failed to create tables: {e}")
            raise

    def drop_tables(self):
        """Drop all tables (USE WITH CAUTION)."""
        try:
            logger.warning("Dropping all database tables...")
            Base.metadata.drop_all(bind=self.engine)
            logger.info("Tables dropped successfully")
        except Exception as e:
            logger.error(f"Failed to drop tables: {e}")
            raise

    def close(self):
        """Close database connection."""
        if self.engine:
            self.engine.dispose()
            logger.info("Database connection closed")

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()


# Global database connection instance
_db_connection: Optional[DatabaseConnection] = None


def init_db(config: Optional[DatabaseConfig] = None, echo: bool = False) -> DatabaseConnection:
    """Initialize global database connection."""
    global _db_connection
    _db_connection = DatabaseConnection(config, echo)
    return _db_connection


def get_db_session() -> Session:
    """Get database session from global connection."""
    if _db_connection is None:
        raise RuntimeError("Database connection not initialized. Call init_db() first.")
    return _db_connection.get_session()


def close_db():
    """Close global database connection."""
    global _db_connection
    if _db_connection:
        _db_connection.close()
        _db_connection = None


# Example usage in tests
if __name__ == "__main__":
    # Configure logging
    logging.basicConfig(level=logging.INFO)
    
    # Initialize connection
    config = DatabaseConfig()
    db = DatabaseConnection(config, echo=False)
    
    # Test session
    session = db.get_session()
    print(f"Session created: {session}")
    session.close()
    
    # Close connection
    db.close()
