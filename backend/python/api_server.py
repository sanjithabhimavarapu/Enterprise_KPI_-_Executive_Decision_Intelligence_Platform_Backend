"""
Enterprise KPI Platform - Flask API Server
Provides REST endpoints for frontend dashboard connections and ETL triggering
"""

from flask import Flask, request, jsonify
from datetime import datetime
import os
from dotenv import load_dotenv
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False

# Health check endpoint
@app.route('/api/health', methods=['GET'])
def health_check():
    """Check if API server is running"""
    return jsonify({
        'status': 'healthy',
        'service': 'Enterprise_KPI_Executive_Decision_Intelligence_Platform_API',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    }), 200

# Database connection test endpoint
@app.route('/api/db-status', methods=['GET'])
def db_status():
    """Check database connection status"""
    try:
        db_server = os.getenv('DB_SERVER', 'localhost')
        db_name = os.getenv('DB_NAME', 'KPI_DataWarehouse')
        db_port = os.getenv('DB_PORT', '1433')
        
        return jsonify({
            'status': 'configured',
            'database': {
                'server': db_server,
                'database': db_name,
                'port': db_port,
                'driver': 'SQL Server (Native)'
            },
            'message': 'Database configuration loaded successfully'
        }), 200
    except Exception as e:
        logger.error(f"Database status check failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

# ETL trigger endpoint
@app.route('/api/trigger-etl', methods=['POST'])
def trigger_etl():
    """Trigger ETL workflow (placeholder)"""
    try:
        data = request.get_json() or {}
        load_date = data.get('load_date', str(datetime.now().date()))
        continue_on_error = data.get('continue_on_error', False)
        
        return jsonify({
            'status': 'queued',
            'message': 'ETL workflow triggered',
            'load_date': load_date,
            'continue_on_error': continue_on_error,
            'timestamp': datetime.now().isoformat(),
            'execution_id': f"ETL_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        }), 202
    except Exception as e:
        logger.error(f"ETL trigger failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

# ETL status endpoint
@app.route('/api/etl-status', methods=['GET'])
def etl_status():
    """Get current ETL execution status"""
    return jsonify({
        'status': 'idle',
        'last_execution': None,
        'next_scheduled': '02:00 AM',
        'frequency': 'Daily'
    }), 200

# Data query endpoint
@app.route('/api/query', methods=['POST'])
def query_data():
    """Execute data query (placeholder)"""
    try:
        data = request.get_json() or {}
        sql_query = data.get('query', '')
        
        if not sql_query:
            return jsonify({
                'status': 'error',
                'message': 'No SQL query provided'
            }), 400
        
        return jsonify({
            'status': 'queued',
            'message': 'Query execution queued',
            'query': sql_query[:100] + '...' if len(sql_query) > 100 else sql_query,
            'timestamp': datetime.now().isoformat()
        }), 202
    except Exception as e:
        logger.error(f"Query failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

# Available tables endpoint
@app.route('/api/tables', methods=['GET'])
def get_tables():
    """List available data warehouse tables"""
    tables = {
        'dimensions': [
            'Dim_Date',
            'Dim_Company',
            'Dim_Customer',
            'Dim_Product',
            'Dim_Employee',
            'Dim_Geography'
        ],
        'facts': [
            'Fact_Sales',
            'Fact_Orders',
            'Fact_Customer_Activity',
            'Fact_Financial',
            'Fact_Operations',
            'Fact_KPI'
        ],
        'views': [
            'vw_executive_kpi_dashboard',
            'vw_daily_financial_summary',
            'vw_customer_churn_risk',
            'vw_sales_anomaly_detection',
            'vw_operational_metrics'
        ]
    }
    return jsonify(tables), 200

# Root endpoint
@app.route('/', methods=['GET'])
def index():
    """API information"""
    return jsonify({
        'name': 'Enterprise_KPI_Executive_Decision_Intelligence_Platform_API',
        'version': '1.0.0',
        'status': 'running',
        'service': 'Backend API Server',
        'database': 'KPI_DataWarehouse',
        'endpoints': {
            'health': '/api/health',
            'database': '/api/db-status',
            'tables': '/api/tables',
            'trigger_etl': '/api/trigger-etl (POST)',
            'etl_status': '/api/etl-status',
            'query': '/api/query (POST)'
        },
        'documentation': 'See README.md for detailed documentation'
    }), 200

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'status': 'error',
        'message': 'Endpoint not found',
        'path': request.path
    }), 404

@app.errorhandler(500)
def server_error(error):
    return jsonify({
        'status': 'error',
        'message': 'Internal server error'
    }), 500

if __name__ == '__main__':
    port = int(os.getenv('FLASK_PORT', 5000))
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    
    logger.info(f"Starting Enterprise_KPI_Executive_Decision_Intelligence_Platform_API")
    logger.info(f"Service: Backend API Server")
    logger.info(f"Server: {host}:{port}")
    logger.info(f"Database: {os.getenv('DB_SERVER')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}")
    
    app.run(host=host, port=port, debug=False, threaded=True)
