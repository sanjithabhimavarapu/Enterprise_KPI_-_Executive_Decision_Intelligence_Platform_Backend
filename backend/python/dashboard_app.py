"""
Enterprise KPI Executive Dashboard
====================================
Interactive Plotly Dash web application replicating Power BI executive
dashboard functionality. Covers all 7 project deliverables:

  Tab 1 — Executive Scorecard      (Revenue, KPI health, targets)
  Tab 2 — Revenue & Profitability  (Trend, department, forecast)
  Tab 3 — Operational KPIs         (Fill rate, OTD, throughput)
  Tab 4 — SLA Compliance           (Breach rates, severity, trends)
  Tab 5 — Customer Analytics       (Retention, churn, CLV, segments)
  Tab 6 — Data Quality             (Validation scores, reconciliation)

Run:
    python dashboard_app.py
    Open http://localhost:8050
"""

import os
import random
from datetime import date, datetime, timedelta

import dash
import dash_bootstrap_components as dbc
import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from dash import Input, Output, dcc, html
from plotly.subplots import make_subplots

# ── App Init ──────────────────────────────────────────────────────────────────
app = dash.Dash(
    __name__,
    external_stylesheets=[dbc.themes.DARKLY],
    title="Enterprise KPI | Executive Intelligence Platform",
    suppress_callback_exceptions=True,
)
server = app.server  # expose Flask server for production deployment

# ── Colour Palette ────────────────────────────────────────────────────────────
COLOURS = {
    "primary":   "#0078D4",   # Microsoft blue
    "success":   "#107C10",
    "warning":   "#FFB900",
    "danger":    "#D13438",
    "purple":    "#5C2D91",
    "teal":      "#008272",
    "bg":        "#1E1E1E",
    "card":      "#252526",
    "text":      "#FFFFFF",
    "muted":     "#9E9E9E",
}

# ── Sample Data Generators ────────────────────────────────────────────────────
random.seed(42)
np.random.seed(42)

def _date_range(months: int = 12) -> list:
    today = date.today()
    return [
        (today.replace(day=1) - timedelta(days=30 * i)).strftime("%b %Y")
        for i in range(months - 1, -1, -1)
    ]

MONTHS = _date_range(12)
DEPARTMENTS = ["Sales", "Operations", "Finance", "Customer Success", "Logistics", "HR"]

# Revenue data
def revenue_data() -> pd.DataFrame:
    base = 8_500_000
    return pd.DataFrame({
        "Month":   MONTHS,
        "Revenue": [base + i * 120_000 + random.randint(-200_000, 300_000) for i in range(12)],
        "Target":  [base + i * 100_000 for i in range(12)],
        "Cost":    [int((base + i * 120_000) * random.uniform(0.58, 0.65)) for i in range(12)],
    })

def dept_revenue() -> pd.DataFrame:
    return pd.DataFrame({
        "Department": DEPARTMENTS,
        "Revenue":    [4_200_000, 2_800_000, 1_500_000, 980_000, 1_200_000, 450_000],
        "Target":     [4_000_000, 3_000_000, 1_400_000, 900_000, 1_100_000, 400_000],
        "Orders":     [1_240, 880, 320, 415, 560, 145],
    })

def kpi_scorecard() -> list:
    return [
        {"name": "Monthly Revenue",    "actual": 9_820_000, "target": 9_500_000, "unit": "$",  "fmt": ",.0f"},
        {"name": "Gross Margin",       "actual": 38.4,      "target": 35.0,      "unit": "%",  "fmt": ".1f"},
        {"name": "Customer Retention", "actual": 91.2,      "target": 90.0,      "unit": "%",  "fmt": ".1f"},
        {"name": "On-Time Delivery",   "actual": 87.6,      "target": 92.0,      "unit": "%",  "fmt": ".1f"},
        {"name": "Order Fill Rate",    "actual": 94.3,      "target": 95.0,      "unit": "%",  "fmt": ".1f"},
        {"name": "SLA Compliance",     "actual": 96.8,      "target": 98.0,      "unit": "%",  "fmt": ".1f"},
        {"name": "Churn Rate",         "actual": 3.2,       "target": 4.0,       "unit": "%",  "fmt": ".1f"},
        {"name": "Avg Resolution Time","actual": 4.2,       "target": 4.0,       "unit": "hrs","fmt": ".1f"},
    ]

def operational_data() -> pd.DataFrame:
    return pd.DataFrame({
        "Month":        MONTHS,
        "Fill_Rate":    [94 + random.uniform(-2, 2) for _ in range(12)],
        "OTD":          [88 + random.uniform(-3, 4) for _ in range(12)],
        "Throughput":   [1200 + i * 15 + random.randint(-50, 80) for i in range(12)],
        "Defect_Rate":  [2.5 - i * 0.05 + random.uniform(-0.3, 0.3) for i in range(12)],
    })

def sla_data() -> pd.DataFrame:
    return pd.DataFrame({
        "Department":  DEPARTMENTS,
        "Compliant":   [94, 88, 97, 91, 86, 99],
        "Warning":     [3,  7,  2,  5,  9,  1],
        "Breached":    [3,  5,  1,  4,  5,  0],
    })

def customer_data() -> pd.DataFrame:
    return pd.DataFrame({
        "Month":         MONTHS,
        "Retention":     [90 + random.uniform(-1.5, 2) for _ in range(12)],
        "Churn_Rate":    [4.5 - i * 0.1 + random.uniform(-0.3, 0.3) for i in range(12)],
        "NPS":           [42 + i + random.randint(-3, 5) for i in range(12)],
        "New_Customers": [120 + random.randint(-20, 40) for _ in range(12)],
        "CLV":           [12_000 + i * 200 + random.randint(-500, 800) for i in range(12)],
    })

def dq_data() -> pd.DataFrame:
    return pd.DataFrame({
        "Check":  ["Completeness", "Accuracy", "Consistency", "Timeliness", "Validity", "Uniqueness"],
        "Score":  [98.4, 97.1, 96.8, 99.2, 97.5, 99.8],
        "Target": [98.0, 97.0, 97.0, 99.0, 97.0, 99.5],
    })


# ── Helper: KPI card ──────────────────────────────────────────────────────────
def _kpi_card(name: str, actual, target, unit: str, fmt: str):
    pct = actual / target * 100 if target else 0
    colour = COLOURS["success"] if pct >= 100 else COLOURS["warning"] if pct >= 90 else COLOURS["danger"]
    trend = "▲" if pct >= 100 else "▼"
    return dbc.Card(
        dbc.CardBody([
            html.P(name, className="text-muted mb-1", style={"fontSize": "0.75rem", "letterSpacing": "0.05em"}),
            html.H4(
                f"{unit}{format(actual, fmt)}" if unit == "$" else f"{format(actual, fmt)}{unit}",
                style={"color": colour, "fontWeight": "700", "marginBottom": "2px"},
            ),
            html.Small(
                f"{trend} {pct:.1f}% of target  |  Target: {format(target, fmt)}{unit}",
                style={"color": COLOURS["muted"], "fontSize": "0.7rem"},
            ),
        ]),
        style={"backgroundColor": COLOURS["card"], "border": f"1px solid {colour}33"},
        className="h-100",
    )


# ── Layout ────────────────────────────────────────────────────────────────────
COMMON_GRAPH_CFG = {"displayModeBar": True, "displaylogo": False}
TRANSPARENT_BG = {"paper_bgcolor": "rgba(0,0,0,0)", "plot_bgcolor": "rgba(0,0,0,0)"}

def _tab_label(icon: str, text: str):
    return html.Span([html.I(className=f"bi bi-{icon} me-1"), text])


app.layout = dbc.Container(
    fluid=True,
    style={"backgroundColor": COLOURS["bg"], "minHeight": "100vh", "padding": "0"},
    children=[
        # ── Header ────────────────────────────────────────────────────────────
        dbc.Row(
            dbc.Col(
                html.Div([
                    html.H4(
                        "Enterprise KPI | Executive Decision Intelligence Platform",
                        className="mb-0",
                        style={"color": COLOURS["primary"], "fontWeight": "700"},
                    ),
                    html.Small(
                        f"Last refreshed: {datetime.now().strftime('%d %b %Y  %H:%M')}  ·  "
                        "Data Warehouse: KPI_DataWarehouse",
                        style={"color": COLOURS["muted"]},
                    ),
                ], style={"padding": "16px 24px 12px"}),
            ),
            style={"backgroundColor": COLOURS["card"], "borderBottom": f"2px solid {COLOURS['primary']}"},
        ),

        # ── Tabs ──────────────────────────────────────────────────────────────
        dbc.Row(
            dbc.Col(
                dbc.Tabs(
                    id="main-tabs",
                    active_tab="tab-scorecard",
                    children=[
                        dbc.Tab(label="Executive Scorecard", tab_id="tab-scorecard"),
                        dbc.Tab(label="Revenue & Profit",    tab_id="tab-revenue"),
                        dbc.Tab(label="Operational KPIs",    tab_id="tab-ops"),
                        dbc.Tab(label="SLA Compliance",      tab_id="tab-sla"),
                        dbc.Tab(label="Customer Analytics",  tab_id="tab-customer"),
                        dbc.Tab(label="Data Quality",        tab_id="tab-dq"),
                    ],
                    style={"padding": "0 24px"},
                ),
            ),
            style={"backgroundColor": COLOURS["card"]},
        ),

        # ── Tab Content ───────────────────────────────────────────────────────
        dbc.Row(
            dbc.Col(
                html.Div(id="tab-content", style={"padding": "24px"}),
            )
        ),
    ],
)


# ── Callbacks ─────────────────────────────────────────────────────────────────

@app.callback(Output("tab-content", "children"), Input("main-tabs", "active_tab"))
def render_tab(tab: str):
    if tab == "tab-scorecard":
        return _tab_scorecard()
    if tab == "tab-revenue":
        return _tab_revenue()
    if tab == "tab-ops":
        return _tab_ops()
    if tab == "tab-sla":
        return _tab_sla()
    if tab == "tab-customer":
        return _tab_customer()
    if tab == "tab-dq":
        return _tab_dq()
    return html.P("Select a tab")


# ── Tab 1: Executive Scorecard ────────────────────────────────────────────────
def _tab_scorecard():
    cards = kpi_scorecard()
    # KPI cards row
    card_cols = [dbc.Col(_kpi_card(**k), xs=12, sm=6, md=3, className="mb-3") for k in cards]

    # Revenue gauge
    rev = 9_820_000
    target = 9_500_000
    gauge = go.Figure(go.Indicator(
        mode="gauge+number+delta",
        value=rev / 1_000_000,
        delta={"reference": target / 1_000_000, "valueformat": ".2f", "prefix": "$", "suffix": "M"},
        number={"prefix": "$", "suffix": "M", "valueformat": ".2f"},
        title={"text": "Monthly Revenue vs Target", "font": {"color": COLOURS["text"]}},
        gauge={
            "axis": {"range": [0, 12], "tickcolor": COLOURS["muted"]},
            "bar": {"color": COLOURS["primary"]},
            "steps": [
                {"range": [0, target / 1_000_000 * 0.75], "color": COLOURS["danger"] + "44"},
                {"range": [target / 1_000_000 * 0.75, target / 1_000_000 * 0.9], "color": COLOURS["warning"] + "44"},
                {"range": [target / 1_000_000 * 0.9, 12], "color": COLOURS["success"] + "44"},
            ],
            "threshold": {"line": {"color": COLOURS["warning"], "width": 3}, "value": target / 1_000_000},
        },
    ))
    gauge.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=280, margin={"t": 60, "b": 20})

    # KPI status donut
    statuses = {"ON_TARGET": 5, "AT_RISK": 2, "BELOW_TARGET": 1}
    donut = go.Figure(go.Pie(
        labels=list(statuses.keys()),
        values=list(statuses.values()),
        hole=0.6,
        marker_colors=[COLOURS["success"], COLOURS["warning"], COLOURS["danger"]],
    ))
    donut.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=280,
        title={"text": "KPI Health Distribution", "font": {"color": COLOURS["text"]}},
        legend={"font": {"color": COLOURS["text"]}},
        margin={"t": 60, "b": 20},
    )
    donut.update_traces(textfont_color=COLOURS["text"])

    # Department revenue bar
    df = dept_revenue()
    dept_bar = px.bar(
        df, x="Department", y=["Revenue", "Target"],
        barmode="group",
        color_discrete_map={"Revenue": COLOURS["primary"], "Target": COLOURS["muted"]},
        title="Department Revenue vs Target",
        labels={"value": "Revenue ($)", "variable": ""},
    )
    dept_bar.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
                           title_font_color=COLOURS["text"], legend_font_color=COLOURS["text"])

    return html.Div([
        dbc.Row(card_cols),
        dbc.Row([
            dbc.Col(dcc.Graph(figure=gauge, config=COMMON_GRAPH_CFG), md=6),
            dbc.Col(dcc.Graph(figure=donut, config=COMMON_GRAPH_CFG), md=6),
        ], className="mb-3"),
        dbc.Row(dbc.Col(dcc.Graph(figure=dept_bar, config=COMMON_GRAPH_CFG))),
    ])


# ── Tab 2: Revenue & Profitability ────────────────────────────────────────────
def _tab_revenue():
    df = revenue_data()
    df["Profit"] = df["Revenue"] - df["Cost"]
    df["Margin_Pct"] = (df["Profit"] / df["Revenue"] * 100).round(2)

    # Revenue trend with target line
    rev_fig = go.Figure()
    rev_fig.add_trace(go.Bar(x=df["Month"], y=df["Revenue"], name="Revenue",
                             marker_color=COLOURS["primary"]))
    rev_fig.add_trace(go.Scatter(x=df["Month"], y=df["Target"], name="Target",
                                 mode="lines+markers", line={"color": COLOURS["warning"], "dash": "dot"}))
    rev_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=320,
        title="Monthly Revenue vs Target", title_font_color=COLOURS["text"],
        legend_font_color=COLOURS["text"], xaxis_tickangle=-30,
    )

    # Waterfall: Revenue → Cost → Profit
    waterfall = go.Figure(go.Waterfall(
        name="", orientation="v",
        measure=["absolute", "relative", "total"],
        x=["Total Revenue", "Total Cost", "Gross Profit"],
        y=[df["Revenue"].sum(), -df["Cost"].sum(), 0],
        connector={"line": {"color": COLOURS["muted"]}},
        increasing={"marker": {"color": COLOURS["success"]}},
        decreasing={"marker": {"color": COLOURS["danger"]}},
        totals={"marker": {"color": COLOURS["primary"]}},
    ))
    waterfall.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=320,
        title="Revenue Waterfall (12-Month)", title_font_color=COLOURS["text"],
    )

    # Margin % line
    margin_fig = px.line(
        df, x="Month", y="Margin_Pct",
        title="Gross Margin % Trend",
        markers=True,
        color_discrete_sequence=[COLOURS["teal"]],
        labels={"Margin_Pct": "Gross Margin (%)"},
    )
    margin_fig.add_hline(y=35, line_dash="dot", line_color=COLOURS["warning"],
                         annotation_text="Target 35%", annotation_font_color=COLOURS["warning"])
    margin_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
        title_font_color=COLOURS["text"], xaxis_tickangle=-30,
    )

    # Department contribution pie
    df2 = dept_revenue()
    dept_pie = px.pie(
        df2, names="Department", values="Revenue",
        title="Revenue by Department",
        color_discrete_sequence=px.colors.qualitative.Bold,
    )
    dept_pie.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
        title_font_color=COLOURS["text"], legend_font_color=COLOURS["text"],
    )

    return html.Div([
        dbc.Row([
            dbc.Col(dcc.Graph(figure=rev_fig, config=COMMON_GRAPH_CFG), md=8),
            dbc.Col(dcc.Graph(figure=dept_pie, config=COMMON_GRAPH_CFG), md=4),
        ], className="mb-3"),
        dbc.Row([
            dbc.Col(dcc.Graph(figure=waterfall, config=COMMON_GRAPH_CFG), md=6),
            dbc.Col(dcc.Graph(figure=margin_fig, config=COMMON_GRAPH_CFG), md=6),
        ]),
    ])


# ── Tab 3: Operational KPIs ───────────────────────────────────────────────────
def _tab_ops():
    df = operational_data()

    fill_fig = px.line(
        df, x="Month", y="Fill_Rate",
        title="Order Fill Rate (%)",
        markers=True, color_discrete_sequence=[COLOURS["primary"]],
    )
    fill_fig.add_hline(y=95, line_dash="dot", line_color=COLOURS["warning"],
                       annotation_text="Target 95%", annotation_font_color=COLOURS["warning"])
    fill_fig.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
                           title_font_color=COLOURS["text"], xaxis_tickangle=-30)

    otd_fig = px.bar(
        df, x="Month", y="OTD",
        title="On-Time Delivery (%)",
        color="OTD",
        color_continuous_scale=[[0, COLOURS["danger"]], [0.9, COLOURS["warning"]], [1, COLOURS["success"]]],
        range_color=[80, 96],
    )
    otd_fig.add_hline(y=92, line_dash="dot", line_color=COLOURS["warning"],
                      annotation_text="Target 92%", annotation_font_color=COLOURS["warning"])
    otd_fig.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
                          title_font_color=COLOURS["text"], xaxis_tickangle=-30,
                          coloraxis_showscale=False)

    throughput_fig = go.Figure()
    throughput_fig.add_trace(go.Scatter(
        x=df["Month"], y=df["Throughput"], fill="tozeroy",
        name="Throughput", line={"color": COLOURS["teal"]},
    ))
    throughput_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
        title="Monthly Order Throughput", title_font_color=COLOURS["text"],
        xaxis_tickangle=-30,
    )

    defect_fig = px.line(
        df, x="Month", y="Defect_Rate",
        title="Defect / Error Rate (%)",
        markers=True, color_discrete_sequence=[COLOURS["danger"]],
    )
    defect_fig.add_hline(y=2.0, line_dash="dot", line_color=COLOURS["warning"],
                         annotation_text="Target <2%", annotation_font_color=COLOURS["warning"])
    defect_fig.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
                             title_font_color=COLOURS["text"], xaxis_tickangle=-30)

    return html.Div([
        dbc.Row([
            dbc.Col(dcc.Graph(figure=fill_fig, config=COMMON_GRAPH_CFG), md=6),
            dbc.Col(dcc.Graph(figure=otd_fig,  config=COMMON_GRAPH_CFG), md=6),
        ], className="mb-3"),
        dbc.Row([
            dbc.Col(dcc.Graph(figure=throughput_fig, config=COMMON_GRAPH_CFG), md=6),
            dbc.Col(dcc.Graph(figure=defect_fig,     config=COMMON_GRAPH_CFG), md=6),
        ]),
    ])


# ── Tab 4: SLA Compliance ─────────────────────────────────────────────────────
def _tab_sla():
    df = sla_data()

    stacked = go.Figure()
    stacked.add_trace(go.Bar(x=df["Department"], y=df["Compliant"], name="Compliant",
                             marker_color=COLOURS["success"]))
    stacked.add_trace(go.Bar(x=df["Department"], y=df["Warning"],   name="Warning",
                             marker_color=COLOURS["warning"]))
    stacked.add_trace(go.Bar(x=df["Department"], y=df["Breached"],  name="Breached",
                             marker_color=COLOURS["danger"]))
    stacked.update_layout(
        barmode="stack", **TRANSPARENT_BG, font_color=COLOURS["text"], height=350,
        title="SLA Status by Department (%)", title_font_color=COLOURS["text"],
        legend_font_color=COLOURS["text"],
    )

    # SLA compliance trend
    months = MONTHS
    compliance = [96 + random.uniform(-2, 2) for _ in months]
    trend_fig = go.Figure()
    trend_fig.add_trace(go.Scatter(
        x=months, y=compliance, name="SLA Compliance %",
        mode="lines+markers", line={"color": COLOURS["primary"]},
    ))
    trend_fig.add_hline(y=98, line_dash="dot", line_color=COLOURS["warning"],
                        annotation_text="SLA Target 98%", annotation_font_color=COLOURS["warning"])
    trend_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
        title="SLA Compliance Trend", title_font_color=COLOURS["text"],
        xaxis_tickangle=-30,
    )

    # Breach severity donut
    severity_fig = go.Figure(go.Pie(
        labels=["None", "Low", "Medium", "High", "Critical"],
        values=[72, 14, 8, 4, 2],
        hole=0.5,
        marker_colors=[COLOURS["success"], COLOURS["teal"], COLOURS["warning"],
                       COLOURS["danger"], "#8B0000"],
    ))
    severity_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
        title="SLA Breach Severity", title_font_color=COLOURS["text"],
        legend_font_color=COLOURS["text"],
    )
    severity_fig.update_traces(textfont_color=COLOURS["text"])

    return html.Div([
        dbc.Row([
            dbc.Col(dcc.Graph(figure=stacked, config=COMMON_GRAPH_CFG), md=8),
            dbc.Col(dcc.Graph(figure=severity_fig, config=COMMON_GRAPH_CFG), md=4),
        ], className="mb-3"),
        dbc.Row(dbc.Col(dcc.Graph(figure=trend_fig, config=COMMON_GRAPH_CFG))),
    ])


# ── Tab 5: Customer Analytics ─────────────────────────────────────────────────
def _tab_customer():
    df = customer_data()

    retention_fig = go.Figure()
    retention_fig.add_trace(go.Scatter(
        x=df["Month"], y=df["Retention"], name="Retention %",
        mode="lines+markers", line={"color": COLOURS["success"]}, fill="tozeroy",
        fillcolor=COLOURS["success"] + "22",
    ))
    retention_fig.add_hline(y=90, line_dash="dot", line_color=COLOURS["warning"],
                            annotation_text="Target 90%", annotation_font_color=COLOURS["warning"])
    retention_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
        title="Customer Retention Rate (%)", title_font_color=COLOURS["text"],
        xaxis_tickangle=-30,
    )

    churn_fig = px.bar(
        df, x="Month", y="Churn_Rate",
        title="Monthly Churn Rate (%)",
        color="Churn_Rate",
        color_continuous_scale=[[0, COLOURS["success"]], [0.5, COLOURS["warning"]], [1, COLOURS["danger"]]],
        range_color=[2.5, 5.5],
    )
    churn_fig.add_hline(y=4.0, line_dash="dot", line_color=COLOURS["warning"],
                        annotation_text="Target <4%", annotation_font_color=COLOURS["warning"])
    churn_fig.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
                            title_font_color=COLOURS["text"], xaxis_tickangle=-30,
                            coloraxis_showscale=False)

    nps_fig = px.line(
        df, x="Month", y="NPS",
        title="Net Promoter Score (NPS)",
        markers=True, color_discrete_sequence=[COLOURS["purple"]],
    )
    nps_fig.add_hline(y=50, line_dash="dot", line_color=COLOURS["warning"],
                      annotation_text="Target 50", annotation_font_color=COLOURS["warning"])
    nps_fig.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
                          title_font_color=COLOURS["text"], xaxis_tickangle=-30)

    clv_fig = px.area(
        df, x="Month", y="CLV",
        title="Average Customer Lifetime Value ($)",
        color_discrete_sequence=[COLOURS["teal"]],
    )
    clv_fig.update_layout(**TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
                          title_font_color=COLOURS["text"], xaxis_tickangle=-30)

    # Customer segment distribution
    seg_fig = go.Figure(go.Pie(
        labels=["Enterprise", "Large", "Mid-Market", "Small", "Micro"],
        values=[8, 15, 34, 28, 15],
        hole=0.45,
        marker_colors=[COLOURS["primary"], COLOURS["purple"], COLOURS["teal"],
                       COLOURS["warning"], COLOURS["muted"]],
    ))
    seg_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=300,
        title="Customer Segmentation", title_font_color=COLOURS["text"],
        legend_font_color=COLOURS["text"],
    )
    seg_fig.update_traces(textfont_color=COLOURS["text"])

    return html.Div([
        dbc.Row([
            dbc.Col(dcc.Graph(figure=retention_fig, config=COMMON_GRAPH_CFG), md=6),
            dbc.Col(dcc.Graph(figure=churn_fig,     config=COMMON_GRAPH_CFG), md=6),
        ], className="mb-3"),
        dbc.Row([
            dbc.Col(dcc.Graph(figure=nps_fig,  config=COMMON_GRAPH_CFG), md=4),
            dbc.Col(dcc.Graph(figure=clv_fig,  config=COMMON_GRAPH_CFG), md=4),
            dbc.Col(dcc.Graph(figure=seg_fig,  config=COMMON_GRAPH_CFG), md=4),
        ]),
    ])


# ── Tab 6: Data Quality ───────────────────────────────────────────────────────
def _tab_dq():
    df = dq_data()

    bar_fig = go.Figure()
    bar_fig.add_trace(go.Bar(x=df["Check"], y=df["Score"],  name="Score",
                             marker_color=COLOURS["primary"]))
    bar_fig.add_trace(go.Bar(x=df["Check"], y=df["Target"], name="Target",
                             marker_color=COLOURS["muted"] + "88"))
    bar_fig.update_layout(
        barmode="group", **TRANSPARENT_BG, font_color=COLOURS["text"], height=350,
        title="Data Quality Scores by Dimension", title_font_color=COLOURS["text"],
        yaxis={"range": [93, 100]},
        legend_font_color=COLOURS["text"],
    )

    # Radar / spider chart for DQ dimensions
    radar_fig = go.Figure(go.Scatterpolar(
        r=df["Score"].tolist() + [df["Score"].iloc[0]],
        theta=df["Check"].tolist() + [df["Check"].iloc[0]],
        fill="toself",
        line_color=COLOURS["primary"],
        fillcolor=COLOURS["primary"] + "33",
        name="DQ Score",
    ))
    radar_fig.add_trace(go.Scatterpolar(
        r=df["Target"].tolist() + [df["Target"].iloc[0]],
        theta=df["Check"].tolist() + [df["Check"].iloc[0]],
        fill="toself",
        line_color=COLOURS["warning"],
        fillcolor=COLOURS["warning"] + "22",
        name="Target",
    ))
    radar_fig.update_layout(
        **TRANSPARENT_BG, font_color=COLOURS["text"], height=350,
        title="Data Quality Radar", title_font_color=COLOURS["text"],
        legend_font_color=COLOURS["text"],
        polar={
            "bgcolor": "rgba(0,0,0,0)",
            "radialaxis": {"range": [93, 100], "color": COLOURS["muted"]},
            "angularaxis": {"color": COLOURS["muted"]},
        },
    )

    # Reconciliation summary table
    recon_data = {
        "Process":      ["ERP Orders", "Salesforce", "Inventory", "HR Records", "Financial"],
        "Source_Count": [125_430, 48_920, 78_340, 5_680, 34_200],
        "DW_Count":     [125_428, 48_920, 78_338, 5_680, 34_200],
        "Variance":     [2, 0, 2, 0, 0],
        "Status":       ["PASS", "PASS", "PASS", "PASS", "PASS"],
    }
    recon_df = pd.DataFrame(recon_data)
    recon_table = dbc.Table.from_dataframe(
        recon_df, striped=True, bordered=True, hover=True, dark=True,
        className="small",
    )

    return html.Div([
        dbc.Row([
            dbc.Col(dcc.Graph(figure=bar_fig,   config=COMMON_GRAPH_CFG), md=7),
            dbc.Col(dcc.Graph(figure=radar_fig, config=COMMON_GRAPH_CFG), md=5),
        ], className="mb-3"),
        dbc.Row(dbc.Col([
            html.H6("Reconciliation Summary", style={"color": COLOURS["text"], "marginBottom": "8px"}),
            recon_table,
        ])),
    ])


# ── Entry Point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.getenv("DASHBOARD_PORT", 8050))
    debug = os.getenv("DASHBOARD_DEBUG", "false").lower() == "true"
    print(f"\n  Enterprise KPI Dashboard running at  http://localhost:{port}\n")
    app.run(debug=debug, port=port, host="0.0.0.0")
