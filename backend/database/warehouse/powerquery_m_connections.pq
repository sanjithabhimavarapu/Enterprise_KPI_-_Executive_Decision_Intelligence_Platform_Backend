// ============================================================
// Enterprise KPI Platform - Power Query M Scripts
// Power BI Desktop Data Source Connections
// ============================================================
// HOW TO USE:
//   1. Open Power BI Desktop
//   2. Home → Transform Data → Advanced Editor
//   3. Paste the relevant query for each table
//   4. Replace YOUR_SERVER and KPI_DataWarehouse with your values
// ============================================================


// ── SHARED CONNECTION PARAMETER ───────────────────────────────────────────────
// Create this as a Parameter in Power BI (Manage Parameters):
//   Name: SQLServer
//   Type: Text
//   Current Value: YOUR_SERVER\INSTANCE   (e.g. localhost\SQLEXPRESS)


// ── 1. dim_date ───────────────────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_dim_date = Source{[Schema="dbo",Item="dim_date"]}[Data],
    #"Changed Types" = Table.TransformColumnTypes(dbo_dim_date,{
        {"date_key",        Int64.Type},
        {"calendar_date",   Date.Type},
        {"calendar_year",   Int64.Type},
        {"calendar_month",  Int64.Type},
        {"calendar_quarter",Int64.Type},
        {"month_name",      type text},
        {"quarter_name",    type text},
        {"fiscal_year",     Int64.Type},
        {"fiscal_quarter",  Int64.Type},
        {"is_weekend",      type logical}
    })
in
    #"Changed Types"


// ── 2. dim_customer ───────────────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_dim_customer = Source{[Schema="dbo",Item="dim_customer"]}[Data],
    #"Remove Sensitive" = Table.RemoveColumns(dbo_dim_customer, {"email_address", "phone_number"}),
    #"Changed Types" = Table.TransformColumnTypes(#"Remove Sensitive",{
        {"customer_key",       Int64.Type},
        {"customer_id",        type text},
        {"customer_name",      type text},
        {"customer_segment",   type text},
        {"industry",           type text},
        {"region",             type text},
        {"country",            type text},
        {"account_status",     type text},
        {"annual_revenue_band",type text},
        {"created_date",       Date.Type}
    })
in
    #"Changed Types"


// ── 3. dim_department ────────────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_dim_department = Source{[Schema="dbo",Item="dim_department"]}[Data],
    #"Changed Types" = Table.TransformColumnTypes(dbo_dim_department,{
        {"department_key",  Int64.Type},
        {"department_code", type text},
        {"department_name", type text},
        {"division",        type text},
        {"cost_center",     type text},
        {"manager_name",    type text}
    })
in
    #"Changed Types"


// ── 4. fact_financial_metrics ────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_fact_financial = Source{[Schema="dbo",Item="fact_financial_metrics"]}[Data],
    // Filter to last 24 months for performance
    #"Filter Period" = Table.SelectRows(dbo_fact_financial, each
        [transaction_date] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -24)
    ),
    #"Changed Types" = Table.TransformColumnTypes(#"Filter Period",{
        {"financial_key",    Int64.Type},
        {"date_key",         Int64.Type},
        {"customer_key",     Int64.Type},
        {"department_key",   Int64.Type},
        {"product_key",      Int64.Type},
        {"order_key",        Int64.Type},
        {"revenue_amount",   Currency.Type},
        {"cost_amount",      Currency.Type},
        {"transaction_date", Date.Type},
        {"on_time_delivery_flag", Int64.Type},
        {"order_fill_rate",  type number}
    })
in
    #"Changed Types"


// ── 5. fact_kpi_metrics ──────────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_fact_kpi = Source{[Schema="dbo",Item="fact_kpi_metrics"]}[Data],
    #"Filter Period" = Table.SelectRows(dbo_fact_kpi, each
        [kpi_date] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -13)
    ),
    #"Changed Types" = Table.TransformColumnTypes(#"Filter Period",{
        {"kpi_key",       Int64.Type},
        {"date_key",      Int64.Type},
        {"kpi_name",      type text},
        {"kpi_category",  type text},
        {"actual_value",  type number},
        {"target_value",  type number},
        {"kpi_date",      Date.Type},
        {"department_key",Int64.Type}
    }),
    #"Add Achievement %" = Table.AddColumn(#"Changed Types", "achievement_pct",
        each if [target_value] = 0 then null
             else Number.Round([actual_value] / [target_value] * 100, 2),
        type number
    ),
    #"Add Status" = Table.AddColumn(#"Add Achievement %", "kpi_status",
        each if [achievement_pct] = null then "NO DATA"
             else if [achievement_pct] >= 100 then "ON TARGET"
             else if [achievement_pct] >= 90  then "AT RISK"
             else if [achievement_pct] >= 75  then "BELOW TARGET"
             else "CRITICAL",
        type text
    )
in
    #"Add Status"


// ── 6. fact_operational_metrics ──────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_fact_ops = Source{[Schema="dbo",Item="fact_operational_metrics"]}[Data],
    #"Filter Period" = Table.SelectRows(dbo_fact_ops, each
        [metric_date] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -13)
    ),
    #"Changed Types" = Table.TransformColumnTypes(#"Filter Period",{
        {"operational_key",    Int64.Type},
        {"date_key",           Int64.Type},
        {"department_key",     Int64.Type},
        {"order_fill_rate",    type number},
        {"on_time_delivery_flag", Int64.Type},
        {"units_processed",    Int64.Type},
        {"defect_count",       Int64.Type},
        {"metric_date",        Date.Type}
    })
in
    #"Changed Types"


// ── 7. fact_sla_metrics ──────────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_fact_sla = Source{[Schema="dbo",Item="fact_sla_metrics"]}[Data],
    #"Filter Period" = Table.SelectRows(dbo_fact_sla, each
        [created_date] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -13)
    ),
    #"Changed Types" = Table.TransformColumnTypes(#"Filter Period",{
        {"sla_key",                 Int64.Type},
        {"ticket_key",              type text},
        {"date_key",                Int64.Type},
        {"department_key",          Int64.Type},
        {"customer_key",            Int64.Type},
        {"sla_minutes",             Int64.Type},
        {"resolution_time_minutes", Int64.Type},
        {"sla_status",              type text},
        {"breach_severity",         type text},
        {"created_date",            Date.Type},
        {"resolved_date",           Date.Type}
    })
in
    #"Changed Types"


// ── 8. fact_customer_metrics ─────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_fact_customer = Source{[Schema="dbo",Item="fact_customer_metrics"]}[Data],
    #"Filter Period" = Table.SelectRows(dbo_fact_customer, each
        [metric_date] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -13)
    ),
    #"Changed Types" = Table.TransformColumnTypes(#"Filter Period",{
        {"customer_metric_key",      Int64.Type},
        {"date_key",                 Int64.Type},
        {"customer_key",             Int64.Type},
        {"customer_status",          type text},
        {"churn_flag",               Int64.Type},
        {"is_new_customer_flag",     Int64.Type},
        {"nps_score",                Int64.Type},
        {"customer_lifetime_value",  Currency.Type},
        {"metric_date",              Date.Type}
    })
in
    #"Changed Types"


// ── 9. data_quality_scores ───────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_dq_scores = Source{[Schema="dbo",Item="data_quality_scores"]}[Data],
    #"Filter Period" = Table.SelectRows(dbo_dq_scores, each
        [load_date] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -3)
    ),
    #"Changed Types" = Table.TransformColumnTypes(#"Filter Period",{
        {"score_id",    Int64.Type},
        {"check_name",  type text},
        {"score_value", type number},
        {"load_date",   Date.Type},
        {"table_name",  type text},
        {"status",      type text}
    })
in
    #"Changed Types"


// ── 10. reconciliation_logs ──────────────────────────────────────────────────
let
    Source = Sql.Database(SQLServer, "KPI_DataWarehouse"),
    dbo_recon = Source{[Schema="dbo",Item="reconciliation_logs"]}[Data],
    #"Filter Period" = Table.SelectRows(dbo_recon, each
        [load_date] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -3)
    ),
    #"Changed Types" = Table.TransformColumnTypes(#"Filter Period",{
        {"log_id",                Int64.Type},
        {"reconciliation_type",   type text},
        {"source_count",          Int64.Type},
        {"target_count",          Int64.Type},
        {"variance_count",        Int64.Type},
        {"reconciliation_status", type text},
        {"load_date",             Date.Type}
    })
in
    #"Changed Types"
