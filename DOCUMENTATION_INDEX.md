# DOCUMENTATION INDEX
## Enterprise KPI - Executive Decision Intelligence Platform

**Complete Navigation Guide for All Documentation**

Last Updated: June 5, 2026

---

## 📍 START HERE

**New to the Project?**
→ Start with [README.md](README.md) - Complete platform overview and quick start

**Ready to Deploy?**
→ [PRODUCTION_DEPLOYMENT_CHECKLIST.md](PRODUCTION_DEPLOYMENT_CHECKLIST.md) - Step-by-step deployment

**Want to Optimize?**
→ [REPOSITORY_CLEANUP_CHECKLIST.md](REPOSITORY_CLEANUP_CHECKLIST.md) - Performance optimization

---

## 📚 QUICK REFERENCE GUIDES

### For Immediate Tasks (< 5 minutes)

| Document | Purpose | Location |
|----------|---------|----------|
| SQL Optimization Quick Reference | Common SQL optimization tasks | `backend/database/warehouse/SQL_OPTIMIZATION_QUICK_REFERENCE.sql` |
| KPI Queries Reference | Pre-built KPI queries | `backend/database/warehouse/KPI_QUERIES_QUICK_REFERENCE.sql` |
| Automation Quick Reference | Common automation tasks | `backend/documentation/AUTOMATION_QUICK_REFERENCE.md` |
| ADF Pipelines Quick Reference | Azure Data Factory reference | `backend/documentation/architecture/ADF_PIPELINES_QUICK_REFERENCE.md` |

---

## 🏗️ IMPLEMENTATION GUIDES

### Setup & Installation

| Document | Topic | Duration | Location |
|----------|-------|----------|----------|
| Python Setup Guide | Python environment configuration | 15 min | `backend/python/PYTHON_SETUP_GUIDE.md` |
| Automation Implementation | Full automation deployment | 2-3 hours | `backend/documentation/AUTOMATION_IMPLEMENTATION_GUIDE.md` |
| Monitoring & Alerts Setup | Alert configuration | 1-2 hours | `backend/documentation/MONITORING_AND_ALERTS_SETUP.md` |

### Architecture & Design

| Document | Topic | Location |
|----------|-------|----------|
| Workflow Orchestration Guide | Task orchestration design | `backend/documentation/architecture/WORKFLOW_ORCHESTRATION_GUIDE.md` |
| Pipeline Triggers Guide | Workflow triggers | `backend/documentation/architecture/PIPELINE_TRIGGERS_GUIDE.md` |
| Orchestration Implementation | Production deployment | `backend/documentation/architecture/ORCHESTRATION_IMPLEMENTATION_GUIDE.md` |

### Performance & Optimization (NEW - June 2026)

| Document | Topic | Impact | Location |
|----------|-------|--------|----------|
| Query Optimization Analysis | Find and optimize slow queries | 5-10x faster queries | `backend/database/warehouse/02_query_optimization_analysis.sql` |
| Index Tuning Strategy | Build optimal index strategy | 5-10x query speed | `backend/database/warehouse/03_index_tuning_strategy.sql` |
| Warehouse Optimization | Materialization & compression | 40-60% storage savings | `backend/database/warehouse/04_warehouse_optimization.sql` |

---

## 🔧 TECHNICAL DOCUMENTATION

### Data Layer (SQL)

**Schema & Dimensional Modeling**
- [01_dimensions.sql](backend/database/schema/01_dimensions.sql) - 15+ dimension tables
- [02_facts.sql](backend/database/schema/02_facts.sql) - 10+ fact tables
- [03_staging.sql](backend/database/schema/03_staging.sql) - Staging layer

**Data Transformation**
- [01_stg_erp_orders_transformation.sql](backend/database/staging/01_stg_erp_orders_transformation.sql) - ERP data
- [02_stg_salesforce_transformation.sql](backend/database/staging/02_stg_salesforce_transformation.sql) - Salesforce data
- [03_stg_inventory_hr_production_transformation.sql](backend/database/staging/03_stg_inventory_hr_production_transformation.sql) - Inventory & HR

**ETL & Business Logic**
- [01_sp_load_dimensions.sql](backend/database/stored_procedures/01_sp_load_dimensions.sql) - SCD Type 2 loading
- [02_sp_load_facts.sql](backend/database/stored_procedures/02_sp_load_facts.sql) - Fact loading
- [03_sp_calculate_kpis.sql](backend/database/stored_procedures/03_sp_calculate_kpis.sql) - KPI calculation
- [04_sp_etl_master_orchestration.sql](backend/database/stored_procedures/04_sp_etl_master_orchestration.sql) - Master orchestration
- [05_kpi_reference_specifications.sql](backend/database/stored_procedures/05_kpi_reference_specifications.sql) - KPI definitions
- [06_sp_data_quality_validation.sql](backend/database/stored_procedures/06_sp_data_quality_validation.sql) - Data quality
- [07_etl_implementation_guide.sql](backend/database/stored_procedures/07_etl_implementation_guide.sql) - Implementation
- [08_sp_kpi_optimization.sql](backend/database/stored_procedures/08_sp_kpi_optimization.sql) - KPI optimization
- [09_sp_sla_operational_metrics.sql](backend/database/stored_procedures/09_sp_sla_operational_metrics.sql) - SLA metrics
- [10_sp_workflow_customer_retention_churn.sql](backend/database/stored_procedures/10_sp_workflow_customer_retention_churn.sql) - Retention
- [11_sp_revenue_forecasting_profit_calculations.sql](backend/database/stored_procedures/11_sp_revenue_forecasting_profit_calculations.sql) - Revenue forecasting
- [12_sp_executive_reporting.sql](backend/database/stored_procedures/12_sp_executive_reporting.sql) - Executive reports
- [13_sp_performance_tuning.sql](backend/database/stored_procedures/13_sp_performance_tuning.sql) - Performance tuning

**Reporting & Analytics**
- [01_optimized_reporting_views.sql](backend/database/warehouse/01_optimized_reporting_views.sql) - 15+ reporting views
- [04_kpi_optimization.sql](backend/database/warehouse/04_kpi_optimization.sql) - KPI queries
- [REVENUE_FORECASTING_PROFIT_QUERIES.sql](backend/database/warehouse/REVENUE_FORECASTING_PROFIT_QUERIES.sql) - Revenue queries
- [SLA_OPERATIONAL_WORKFLOW_RETENTION_QUERIES.sql](backend/database/warehouse/SLA_OPERATIONAL_WORKFLOW_RETENTION_QUERIES.sql) - Operational queries

### Python Layer

**Core Modules**
- [automation_orchestrator.py](backend/python/automation_orchestrator.py) - Central orchestration engine
- [workflow_orchestrator.py](backend/python/workflow_orchestrator.py) - Task execution engine
- [etl_workflow_adapter.py](backend/python/etl_workflow_adapter.py) - ETL workflows
- [database.py](backend/python/database.py) - Database connectivity
- [models.py](backend/python/models.py) - Data models

**Package Modules**
- [automation/](backend/python/automation/) - Automation workflows
- [ingestion/](backend/python/ingestion/) - Data ingestion
- [validation/](backend/python/validation/) - Data quality
- [reconciliation/](backend/python/reconciliation/) - Reconciliation
- [logging/](backend/python/logging/) - Audit & logging

**Configuration**
- [requirements.txt](backend/python/requirements.txt) - Python dependencies
- [README.md](backend/python/README.md) - Python module overview

---

## 📊 DATA DICTIONARY & MAPPING

| Document | Purpose | Location |
|----------|---------|----------|
| Data Dictionary | Table & column definitions | `backend/documentation/data_dictionary/` |
| Source Mapping | Source-to-target mappings | `backend/documentation/source_mapping/` |
| Technical Docs | Implementation details | `backend/documentation/technical_docs/` |

---

## ✅ CHECKLISTS & SUMMARIES

| Document | Purpose | Use When | Location |
|----------|---------|----------|----------|
| Production Deployment Checklist | Pre-deployment verification | Ready to go live | [PRODUCTION_DEPLOYMENT_CHECKLIST.md](PRODUCTION_DEPLOYMENT_CHECKLIST.md) |
| Repository Cleanup Checklist | Code quality verification | Preparing for release | [REPOSITORY_CLEANUP_CHECKLIST.md](REPOSITORY_CLEANUP_CHECKLIST.md) |
| Automation System Index | Component inventory | Planning system updates | [AUTOMATION_SYSTEM_INDEX.md](AUTOMATION_SYSTEM_INDEX.md) |
| Deliverables Index | Project deliverables | Stakeholder reviews | [DELIVERABLES_INDEX.md](DELIVERABLES_INDEX.md) |
| KPI Optimization Summary | KPI implementation guide | Setting up KPIs | [KPI_OPTIMIZATION_SUMMARY.md](KPI_OPTIMIZATION_SUMMARY.md) |
| SQL Implementation README | SQL setup guide | Database setup | [SQL_IMPLEMENTATION_README.md](SQL_IMPLEMENTATION_README.md) |
| SLA Operational Retention Summary | SLA implementation | SLA setup | [SLA_OPERATIONAL_RETENTION_BUILD_SUMMARY.md](SLA_OPERATIONAL_RETENTION_BUILD_SUMMARY.md) |
| Revenue Forecasting Summary | Revenue forecasting | Forecasting setup | [REVENUE_FORECASTING_PROFIT_BUILD_SUMMARY.md](REVENUE_FORECASTING_PROFIT_BUILD_SUMMARY.md) |
| Enhancement Summary | May 2021 enhancements | Historical reference | [ENHANCEMENT_SUMMARY_MAY21.md](ENHANCEMENT_SUMMARY_MAY21.md) |

---

## 🎯 TASK-BASED NAVIGATION

### "I need to..."

#### Deploy to Production
1. Start: [PRODUCTION_DEPLOYMENT_CHECKLIST.md](PRODUCTION_DEPLOYMENT_CHECKLIST.md)
2. Then: [Automation Implementation Guide](backend/documentation/AUTOMATION_IMPLEMENTATION_GUIDE.md)
3. Then: [Monitoring & Alerts Setup](backend/documentation/MONITORING_AND_ALERTS_SETUP.md)

#### Set Up KPI Tracking
1. Start: [KPI Optimization Summary](KPI_OPTIMIZATION_SUMMARY.md)
2. Then: [05_kpi_reference_specifications.sql](backend/database/stored_procedures/05_kpi_reference_specifications.sql)
3. Then: [KPI Queries Reference](backend/database/warehouse/KPI_QUERIES_QUICK_REFERENCE.sql)

#### Optimize Query Performance
1. Start: [02_query_optimization_analysis.sql](backend/database/warehouse/02_query_optimization_analysis.sql)
2. Then: [03_index_tuning_strategy.sql](backend/database/warehouse/03_index_tuning_strategy.sql)
3. Then: [SQL Optimization Quick Reference](backend/database/warehouse/SQL_OPTIMIZATION_QUICK_REFERENCE.sql)

#### Improve Warehouse Performance
1. Start: [04_warehouse_optimization.sql](backend/database/warehouse/04_warehouse_optimization.sql)
2. Then: [Monitoring & Alerts Setup](backend/documentation/MONITORING_AND_ALERTS_SETUP.md)
3. Then: [01_optimized_reporting_views.sql](backend/database/warehouse/01_optimized_reporting_views.sql)

#### Set Up Automation
1. Start: [Automation Quick Reference](backend/documentation/AUTOMATION_QUICK_REFERENCE.md)
2. Then: [Automation Implementation Guide](backend/documentation/AUTOMATION_IMPLEMENTATION_GUIDE.md)
3. Then: [Orchestration Implementation Guide](backend/documentation/architecture/ORCHESTRATION_IMPLEMENTATION_GUIDE.md)

#### Configure Alerts & Monitoring
1. Start: [Monitoring & Alerts Setup](backend/documentation/MONITORING_AND_ALERTS_SETUP.md)
2. Then: [Automation Quick Reference](backend/documentation/AUTOMATION_QUICK_REFERENCE.md)
3. Then: [Pipeline Triggers Guide](backend/documentation/architecture/PIPELINE_TRIGGERS_GUIDE.md)

#### Understand the Data Model
1. Start: [README.md](README.md) (Architecture section)
2. Then: [Data Dictionary](backend/documentation/data_dictionary/)
3. Then: [Source Mapping](backend/documentation/source_mapping/)

---

## 📈 FEATURES BY COMPONENT

### ETL & Data Loading
- **Where**: `backend/database/staging/` and `backend/database/stored_procedures/`
- **What**: 3-stage transformation, 13 stored procedures
- **How**: [SQL Implementation README](SQL_IMPLEMENTATION_README.md)

### Analytics & Reporting
- **Where**: `backend/database/warehouse/`
- **What**: 15+ pre-built views, KPI dashboards
- **How**: [KPI Optimization Summary](KPI_OPTIMIZATION_SUMMARY.md)

### Orchestration & Automation
- **Where**: `backend/python/`
- **What**: Workflow engine, task dependencies, multi-channel alerts
- **How**: [Automation Implementation Guide](backend/documentation/AUTOMATION_IMPLEMENTATION_GUIDE.md)

### Data Quality & Validation
- **Where**: `backend/database/stored_procedures/06_sp_data_quality_validation.sql`
- **What**: Automated validation, reconciliation, audit logging
- **How**: [Monitoring & Alerts Setup](backend/documentation/MONITORING_AND_ALERTS_SETUP.md)

### Performance Optimization
- **Where**: `backend/database/warehouse/02_query_optimization_analysis.sql` (NEW)
- **What**: Query tuning, index strategy, materialization
- **How**: [Repository Cleanup Checklist](REPOSITORY_CLEANUP_CHECKLIST.md)

---

## 🔗 CROSS-REFERENCES

### If you're reading...

**[README.md](README.md)**
- For details on ETL: See [SQL Implementation README](SQL_IMPLEMENTATION_README.md)
- For automation setup: See [Automation Implementation Guide](backend/documentation/AUTOMATION_IMPLEMENTATION_GUIDE.md)
- For KPI details: See [KPI Optimization Summary](KPI_OPTIMIZATION_SUMMARY.md)
- For optimization: See [Repository Cleanup Checklist](REPOSITORY_CLEANUP_CHECKLIST.md)

**[SQL Implementation README](SQL_IMPLEMENTATION_README.md)**
- For orchestration: See [Workflow Orchestration Guide](backend/documentation/architecture/WORKFLOW_ORCHESTRATION_GUIDE.md)
- For queries: See [KPI Queries Reference](backend/database/warehouse/KPI_QUERIES_QUICK_REFERENCE.sql)
- For performance: See [Index Tuning Strategy](backend/database/warehouse/03_index_tuning_strategy.sql)

**[Automation Implementation Guide](backend/documentation/AUTOMATION_IMPLEMENTATION_GUIDE.md)**
- For scheduling: See [Pipeline Triggers Guide](backend/documentation/architecture/PIPELINE_TRIGGERS_GUIDE.md)
- For alerts: See [Monitoring & Alerts Setup](backend/documentation/MONITORING_AND_ALERTS_SETUP.md)
- For deployment: See [Production Deployment Checklist](PRODUCTION_DEPLOYMENT_CHECKLIST.md)

---

## 🆘 TROUBLESHOOTING

**Can't find what you're looking for?**

1. **Search by topic**: Use browser Find (Ctrl+F) to search this index
2. **Check Quick Reference Guides**: Above, under "Quick Reference Guides"
3. **Browse by layer**: Data layer (SQL) vs Python layer
4. **Search by use case**: "Task-Based Navigation" section above

**Still stuck?**
- Check [Production Deployment Checklist](PRODUCTION_DEPLOYMENT_CHECKLIST.md) - Troubleshooting section
- Review [README.md](README.md) - Troubleshooting section
- Check [Monitoring & Alerts Setup](backend/documentation/MONITORING_AND_ALERTS_SETUP.md) - Diagnostics

---

## 📊 STATISTICS

**Total Documentation**:
- 25+ markdown files
- 15+ SQL files
- 5+ Python modules
- 3 quick reference guides
- 9 implementation guides
- 6 checklists & summaries

**Coverage**:
- ✅ Architecture & Design
- ✅ Implementation & Deployment
- ✅ Data Dictionary & Mappings
- ✅ Troubleshooting & Support
- ✅ Optimization & Performance
- ✅ Monitoring & Alerts
- ✅ Security & Compliance

---

## 📅 MAINTENANCE

**Last Updated**: June 5, 2026
**Status**: ✅ Complete & Current
**Next Review**: September 5, 2026

**New in June 2026**:
- Query Optimization Analysis (02_query_optimization_analysis.sql)
- Index Tuning Strategy (03_index_tuning_strategy.sql)
- Warehouse Optimization (04_warehouse_optimization.sql)
- Comprehensive Main README
- This Documentation Index

---

## 🔑 KEY FILES AT A GLANCE

| File | Purpose | Size | Status |
|------|---------|------|--------|
| [README.md](README.md) | Platform overview | 20KB | ✅ Complete |
| [PRODUCTION_DEPLOYMENT_CHECKLIST.md](PRODUCTION_DEPLOYMENT_CHECKLIST.md) | Deployment guide | 15KB | ✅ Complete |
| [REPOSITORY_CLEANUP_CHECKLIST.md](REPOSITORY_CLEANUP_CHECKLIST.md) | Quality assurance | 12KB | ✅ Complete |
| SQL Schema Files | Dimension, Fact, Staging | 80KB | ✅ Complete |
| SQL Stored Procedures | ETL & Reporting (13 files) | 120KB | ✅ Complete |
| SQL Warehouse Files | Views & Optimization (4 files) | 150KB | ✅ Complete (NEW) |
| Python Modules | Orchestration & Automation | 50KB | ✅ Complete |
| Documentation | Architecture & Implementation | 100KB | ✅ Complete |

---

**Bookmark this page for quick access to all documentation!**
