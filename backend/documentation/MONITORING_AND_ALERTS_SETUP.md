# Monitoring, Alerting & Dashboard Setup Guide

## Alert Configuration

### Email Alerts

#### SMTP Configuration

```env
# .env file
ALERT_EMAIL_SMTP=smtp.gmail.com
ALERT_EMAIL_PORT=587
ALERT_EMAIL_FROM=etl-alerts@company.com
ALERT_EMAIL_PASSWORD=your_app_specific_password
ALERT_EMAIL_TLS=true

# For Office 365
# ALERT_EMAIL_SMTP=smtp.office365.com
# ALERT_EMAIL_PORT=587

# For AWS SES
# ALERT_EMAIL_SMTP=email-smtp.us-east-1.amazonaws.com
# ALERT_EMAIL_PORT=587
```

#### Python Email Implementation

```python
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

class EmailAlertSender:
    def __init__(self):
        self.smtp_server = os.getenv('ALERT_EMAIL_SMTP')
        self.smtp_port = int(os.getenv('ALERT_EMAIL_PORT', 587))
        self.from_email = os.getenv('ALERT_EMAIL_FROM')
        self.password = os.getenv('ALERT_EMAIL_PASSWORD')
    
    def send_alert(self, to_emails: List[str], subject: str, message: str):
        """Send email alert."""
        try:
            msg = MIMEMultipart()
            msg['From'] = self.from_email
            msg['To'] = ','.join(to_emails)
            msg['Subject'] = subject
            
            msg.attach(MIMEText(message, 'plain'))
            
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.from_email, self.password)
                server.send_message(msg)
            
            logger.info(f"Email alert sent to {', '.join(to_emails)}")
        except Exception as e:
            logger.error(f"Failed to send email alert: {e}")
```

### Slack Integration

```python
import requests
import json

class SlackAlertSender:
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url
    
    def send_alert(self, message: str, status: str = "warning"):
        """Send alert to Slack."""
        colors = {
            "success": "#36a64f",
            "warning": "#ffa500",
            "error": "#ff0000",
            "info": "#0099ff"
        }
        
        payload = {
            "attachments": [
                {
                    "fallback": message,
                    "color": colors.get(status, colors["info"]),
                    "title": "ETL Pipeline Alert",
                    "text": message,
                    "ts": int(time.time())
                }
            ]
        }
        
        try:
            response = requests.post(
                self.webhook_url,
                data=json.dumps(payload),
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            if response.status_code == 200:
                logger.info("Slack alert sent successfully")
            else:
                logger.error(f"Slack alert failed: {response.text}")
        except Exception as e:
            logger.error(f"Error sending Slack alert: {e}")
```

### Microsoft Teams Integration

```python
import requests
import json

class TeamsAlertSender:
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url
    
    def send_alert(self, title: str, message: str, summary: dict):
        """Send alert to Microsoft Teams."""
        
        # Build facts from summary
        facts = []
        for key, value in summary.items():
            facts.append({
                "name": key,
                "value": str(value)
            })
        
        payload = {
            "@type": "MessageCard",
            "@context": "https://schema.org/extensions",
            "summary": title,
            "themeColor": "ff0000" if "FAIL" in summary.get("status", "") else "0078d7",
            "sections": [
                {
                    "activityTitle": title,
                    "activitySubtitle": message,
                    "facts": facts,
                    "markdown": True
                }
            ]
        }
        
        try:
            response = requests.post(
                self.webhook_url,
                json=payload,
                timeout=10
            )
            if response.status_code == 200:
                logger.info("Teams alert sent successfully")
            else:
                logger.error(f"Teams alert failed: {response.text}")
        except Exception as e:
            logger.error(f"Error sending Teams alert: {e}")
```

### PagerDuty Integration

```python
import requests
import json
from datetime import datetime

class PagerDutyAlertSender:
    def __init__(self, integration_key: str):
        self.integration_key = integration_key
        self.api_url = "https://events.pagerduty.com/v2/enqueue"
    
    def send_alert(self, 
                   title: str, 
                   message: str, 
                   severity: str = "error",
                   dedup_key: str = None):
        """Send alert to PagerDuty."""
        
        payload = {
            "routing_key": self.integration_key,
            "event_action": "trigger",
            "dedup_key": dedup_key or f"etl-alert-{int(datetime.now().timestamp())}",
            "payload": {
                "summary": title,
                "severity": severity,  # critical, error, warning, info
                "source": "ETL Pipeline",
                "timestamp": datetime.utcnow().isoformat(),
                "custom_details": {
                    "message": message
                }
            }
        }
        
        try:
            response = requests.post(
                self.api_url,
                json=payload,
                timeout=10
            )
            if response.status_code == 202:
                logger.info("PagerDuty alert sent successfully")
            else:
                logger.error(f"PagerDuty alert failed: {response.text}")
        except Exception as e:
            logger.error(f"Error sending PagerDuty alert: {e}")
```

---

## Centralized Monitoring Dashboard

### Dashboard Database Views

```sql
-- View 1: Recent Orchestration Runs
CREATE VIEW vw_recent_orchestrations AS
SELECT 
    JSON_EXTRACT(details, '$.execution_id') as execution_id,
    JSON_EXTRACT(details, '$.workflow') as workflow,
    JSON_EXTRACT(details, '$.status') as status,
    log_date,
    JSON_EXTRACT(details, '$.total_tasks') as total_tasks,
    JSON_EXTRACT(details, '$.successful') as successful,
    JSON_EXTRACT(details, '$.failed') as failed,
    JSON_EXTRACT(details, '$.duration_seconds') as duration_sec
FROM etl_logs
WHERE process_name LIKE 'orchestration_%'
AND process_step = 'COMPLETE'
ORDER BY log_date DESC;

-- View 2: Task Success Rate
CREATE VIEW vw_task_success_rate AS
SELECT TOP 30
    CONVERT(DATE, log_date) as exec_date,
    JSON_EXTRACT(details, '$.workflow') as workflow,
    COUNT(*) as total_tasks,
    SUM(CASE WHEN JSON_EXTRACT(details, '$.status') = 'SUCCESS' THEN 1 ELSE 0 END) as successful,
    CAST(SUM(CASE WHEN JSON_EXTRACT(details, '$.status') = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) 
        AS DECIMAL(5,2)) as success_rate
FROM etl_logs
WHERE process_name LIKE 'orchestration_%'
AND process_step = 'COMPLETE'
GROUP BY CONVERT(DATE, log_date), JSON_EXTRACT(details, '$.workflow')
ORDER BY exec_date DESC;

-- View 3: Data Quality Trends
CREATE VIEW vw_quality_trends AS
SELECT 
    CONVERT(DATE, load_date) as quality_date,
    check_name,
    AVG(quality_score) as avg_score,
    MIN(quality_score) as min_score,
    MAX(quality_score) as max_score,
    COUNT(*) as checks_run
FROM data_quality_scores
GROUP BY CONVERT(DATE, load_date), check_name;

-- View 4: Reconciliation Status
CREATE VIEW vw_reconciliation_status AS
SELECT 
    CONVERT(DATE, load_date) as recon_date,
    reconciliation_type,
    reconciliation_status,
    COUNT(*) as count,
    AVG(record_variance) as avg_variance,
    SUM(source_record_count) as total_source
FROM reconciliation_logs
GROUP BY CONVERT(DATE, load_date), reconciliation_type, reconciliation_status
ORDER BY recon_date DESC;

-- View 5: Alert History
CREATE VIEW vw_alert_history AS
SELECT TOP 100
    log_date,
    JSON_EXTRACT(details, '$.alert_type') as alert_type,
    JSON_EXTRACT(details, '$.severity') as severity,
    JSON_EXTRACT(details, '$.message') as message,
    JSON_EXTRACT(details, '$.sent_to') as sent_to
FROM etl_logs
WHERE process_name = 'alert_system'
ORDER BY log_date DESC;
```

### Power BI Dashboard Configuration

#### Data Source Connection

```python
# Connection string for Power BI
connection_string = """
Provider=MSOLEDBSQL;
Server=tcp:your_server.database.windows.net,1433;
Database=kpi_analytics;
Uid=your_username;
Pwd=your_password;
Encrypt=yes;
TrustServerCertificate=no;
Connection Timeout=30;
"""
```

#### Sample Queries for Power BI

```sql
-- Query 1: Pipeline Health Card
SELECT 
    COUNT(DISTINCT execution_id) as total_executions,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed,
    CAST(SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / 
        COUNT(DISTINCT execution_id) AS DECIMAL(5,2)) as success_rate
FROM vw_recent_orchestrations
WHERE log_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE));

-- Query 2: Task Performance Over Time
SELECT 
    exec_date,
    workflow,
    AVG(duration_sec) as avg_duration,
    MAX(duration_sec) as max_duration,
    MIN(duration_sec) as min_duration
FROM vw_recent_orchestrations
GROUP BY exec_date, workflow
ORDER BY exec_date DESC;

-- Query 3: Data Quality Heatmap
SELECT 
    quality_date,
    check_name,
    avg_score,
    CASE 
        WHEN avg_score >= 99 THEN 'Excellent'
        WHEN avg_score >= 95 THEN 'Good'
        WHEN avg_score >= 90 THEN 'Fair'
        ELSE 'Poor'
    END as quality_level
FROM vw_quality_trends
WHERE quality_date >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY quality_date DESC, check_name;
```

---

## Grafana Dashboard Setup

### Grafana Configuration

```yaml
# docker-compose.yml for Grafana with SQL Server datasource
version: '3'
services:
  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning

volumes:
  grafana-storage:
```

### Grafana Dashboard JSON

```json
{
  "dashboard": {
    "title": "ETL Pipeline Monitoring",
    "panels": [
      {
        "title": "Pipeline Success Rate",
        "targets": [
          {
            "rawSql": "SELECT exec_date, success_rate FROM vw_task_success_rate"
          }
        ]
      },
      {
        "title": "Average Task Duration",
        "targets": [
          {
            "rawSql": "SELECT exec_date, AVG(duration_sec) as avg_duration FROM vw_recent_orchestrations GROUP BY exec_date"
          }
        ]
      },
      {
        "title": "Data Quality Trends",
        "targets": [
          {
            "rawSql": "SELECT quality_date, check_name, avg_score FROM vw_quality_trends"
          }
        ]
      },
      {
        "title": "Recent Alerts",
        "targets": [
          {
            "rawSql": "SELECT TOP 10 log_date, alert_type, severity, message FROM vw_alert_history"
          }
        ]
      }
    ]
  }
}
```

---

## Prometheus Metrics Export

### Prometheus Exporter for ETL Metrics

```python
from prometheus_client import Counter, Gauge, Histogram, start_http_server
from datetime import datetime
import time

class ETLMetricsExporter:
    def __init__(self):
        # Counters
        self.task_count = Counter(
            'etl_task_total',
            'Total ETL tasks executed',
            ['task_name', 'status']
        )
        
        self.records_processed = Counter(
            'etl_records_processed_total',
            'Total records processed',
            ['task_name']
        )
        
        # Gauges
        self.current_tasks = Gauge(
            'etl_current_tasks',
            'Currently running tasks'
        )
        
        self.quality_score = Gauge(
            'etl_quality_score',
            'Data quality score',
            ['check_name']
        )
        
        # Histograms
        self.task_duration = Histogram(
            'etl_task_duration_seconds',
            'Task execution duration',
            ['task_name'],
            buckets=(60, 300, 600, 1200, 1800, 3600)
        )
    
    def record_task_completion(self, task_name: str, duration: float, status: str):
        """Record task completion metrics."""
        self.task_count.labels(task_name=task_name, status=status).inc()
        self.task_duration.labels(task_name=task_name).observe(duration)
    
    def record_records_processed(self, task_name: str, count: int):
        """Record records processed."""
        self.records_processed.labels(task_name=task_name).inc(count)
    
    def record_quality_score(self, check_name: str, score: float):
        """Record quality score."""
        self.quality_score.labels(check_name=check_name).set(score)

# Start Prometheus metrics server
if __name__ == "__main__":
    start_http_server(8000)
    print("Metrics available at http://localhost:8000/metrics")
```

---

## Custom Dashboard Implementation

### Flask-based Dashboard

```python
from flask import Flask, render_template, jsonify
from sqlalchemy import text
from database import get_db_session
from datetime import datetime, timedelta

app = Flask(__name__)

@app.route('/api/orchestrations/recent')
def get_recent_orchestrations():
    """Get recent orchestration runs."""
    session = get_db_session()
    
    query = text("""
        SELECT TOP 20
            JSON_EXTRACT(details, '$.execution_id') as execution_id,
            JSON_EXTRACT(details, '$.workflow') as workflow,
            JSON_EXTRACT(details, '$.status') as status,
            log_date,
            JSON_EXTRACT(details, '$.duration_seconds') as duration
        FROM etl_logs
        WHERE process_name LIKE 'orchestration_%'
        AND process_step = 'COMPLETE'
        ORDER BY log_date DESC
    """)
    
    results = session.execute(query).fetchall()
    
    return jsonify([{
        'execution_id': r[0],
        'workflow': r[1],
        'status': r[2],
        'log_date': r[3].isoformat() if r[3] else None,
        'duration': r[4]
    } for r in results])

@app.route('/api/quality/trends')
def get_quality_trends():
    """Get data quality trends."""
    session = get_db_session()
    
    query = text("""
        SELECT 
            CONVERT(DATE, load_date) as quality_date,
            check_name,
            AVG(quality_score) as avg_score
        FROM data_quality_scores
        WHERE load_date >= DATEADD(DAY, -30, GETDATE())
        GROUP BY CONVERT(DATE, load_date), check_name
        ORDER BY quality_date DESC
    """)
    
    results = session.execute(query).fetchall()
    
    return jsonify([{
        'date': r[0].isoformat() if r[0] else None,
        'check': r[1],
        'score': float(r[2]) if r[2] else 0
    } for r in results])

@app.route('/api/health/summary')
def get_health_summary():
    """Get overall pipeline health summary."""
    session = get_db_session()
    
    # Get last 30 days stats
    query = text("""
        SELECT 
            COUNT(DISTINCT execution_id) as total,
            SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful,
            SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed,
            AVG(duration_seconds) as avg_duration
        FROM vw_recent_orchestrations
        WHERE log_date >= DATEADD(DAY, -30, GETDATE())
    """)
    
    result = session.execute(query).fetchone()
    
    return jsonify({
        'total_executions': result[0],
        'successful': result[1],
        'failed': result[2],
        'success_rate': (result[1] / result[0] * 100) if result[0] > 0 else 0,
        'avg_duration_seconds': float(result[3]) if result[3] else 0
    })

if __name__ == '__main__':
    app.run(debug=True, port=5000)
```

### HTML Dashboard Template

```html
<!DOCTYPE html>
<html>
<head>
    <title>ETL Pipeline Dashboard</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.7.0/dist/chart.min.js"></script>
</head>
<body>
    <div class="container-fluid p-4">
        <h1>ETL Pipeline Monitoring Dashboard</h1>
        
        <!-- Health Summary Cards -->
        <div class="row mb-4" id="health-cards">
            <!-- Populated by JavaScript -->
        </div>
        
        <!-- Charts -->
        <div class="row">
            <div class="col-md-6">
                <canvas id="successRateChart"></canvas>
            </div>
            <div class="col-md-6">
                <canvas id="durationChart"></canvas>
            </div>
        </div>
        
        <div class="row mt-4">
            <div class="col-md-12">
                <canvas id="qualityTrendChart"></canvas>
            </div>
        </div>
        
        <!-- Recent Executions Table -->
        <div class="row mt-4">
            <div class="col-md-12">
                <h3>Recent Executions</h3>
                <table class="table table-striped" id="executions-table">
                    <thead>
                        <tr>
                            <th>Execution ID</th>
                            <th>Workflow</th>
                            <th>Status</th>
                            <th>Duration (s)</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody id="executions-body">
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    
    <script>
        // Load dashboard data
        async function loadDashboard() {
            // Load health summary
            const healthResponse = await fetch('/api/health/summary');
            const health = await healthResponse.json();
            
            const healthHtml = `
                <div class="col-md-3">
                    <div class="card">
                        <div class="card-body">
                            <h5>Total Executions</h5>
                            <h2>${health.total_executions}</h2>
                        </div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="card">
                        <div class="card-body">
                            <h5>Success Rate</h5>
                            <h2>${health.success_rate.toFixed(1)}%</h2>
                        </div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="card">
                        <div class="card-body">
                            <h5>Failed</h5>
                            <h2>${health.failed}</h2>
                        </div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="card">
                        <div class="card-body">
                            <h5>Avg Duration</h5>
                            <h2>${health.avg_duration_seconds.toFixed(0)}s</h2>
                        </div>
                    </div>
                </div>
            `;
            document.getElementById('health-cards').innerHTML = healthHtml;
            
            // Load recent executions
            const execResponse = await fetch('/api/orchestrations/recent');
            const executions = await execResponse.json();
            
            const tbody = document.getElementById('executions-body');
            executions.forEach(exec => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${exec.execution_id}</td>
                    <td>${exec.workflow}</td>
                    <td><span class="badge bg-${exec.status === 'SUCCESS' ? 'success' : 'danger'}">${exec.status}</span></td>
                    <td>${exec.duration}</td>
                    <td>${exec.log_date}</td>
                `;
                tbody.appendChild(row);
            });
        }
        
        // Load on page ready
        document.addEventListener('DOMContentLoaded', loadDashboard);
        
        // Refresh every 60 seconds
        setInterval(loadDashboard, 60000);
    </script>
</body>
</html>
```

---

## Performance Monitoring & Optimization

### Slow Query Detection

```python
import logging
from functools import wraps
import time

def log_slow_queries(threshold_seconds=5):
    """Decorator to log slow queries."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start = time.time()
            result = func(*args, **kwargs)
            duration = time.time() - start
            
            if duration > threshold_seconds:
                logger.warning(
                    f"Slow query detected: {func.__name__} took {duration:.2f}s"
                )
            
            return result
        return wrapper
    return decorator

@log_slow_queries(threshold_seconds=10)
def execute_reconciliation(config):
    """Execute reconciliation with slow query logging."""
    # Implementation
    pass
```

---

**Version**: 1.0  
**Last Updated**: June 2024
