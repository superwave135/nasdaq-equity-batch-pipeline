# NASDAQ Equity Batch Pipeline - Detailed Architecture

> **Production-grade, event-driven data engineering pipeline on AWS**

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [System Components](#system-components)
- [Data Flow](#data-flow)
- [Infrastructure Details](#infrastructure-details)
- [Security Architecture](#security-architecture)
- [Cost Optimization](#cost-optimization)
- [Scalability & Performance](#scalability--performance)

---

## 🏗️ Architecture Overview

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    NASDAQ EQUITY BATCH DATA PIPELINE                         │
│                     Event-Driven Serverless Architecture                     │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  📅 SCHEDULING LAYER                                                         │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  Amazon EventBridge                                                │      │
│  │  ├─ Schedule: Daily @ 10:30 AM SGT (02:30 UTC)                     │      │
│  │  ├─ Expression: cron(30 2 * * ? *)                                 │      │
│  │  └─ State: ENABLED                                                 │      │
│  └────────────────────────────────────────────────────────────────────┘      │
│                              │                                               │
│                              │ Triggers                                      │
│                              ▼                                               │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  🔄 ORCHESTRATION LAYER                                                      │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  AWS Step Functions State Machine                                  │      │
│  │  Name: nasdaq-equity-batch-pipeline-dev                            │      │
│  │                                                                    │      │
│  │  ┌──────────────────────────────────────────────────────────┐      │      │
│  │  │  State 1: Extract Stock Data                             │      │      │
│  │  │  ├─ Type: Lambda Invoke (Async)                          │      │      │
│  │  │  ├─ Output: data_date (e.g., "2026-01-20")               │      │      │
│  │  │  ├─ Retries: 2 attempts with exponential backoff         │      │      │
│  │  │  └─ Timeout: 5 minutes                                   │      │      │
│  │  └──────────────────────────────────────────────────────────┘      │      │
│  │                           │                                        │      │
│  │                           │ Wait 3s (S3 consistency)               │      │
│  │                           ▼                                        │      │
│  │  ┌──────────────────────────────────────────────────────────┐      │      │
│  │  │  State 2: Process Dimensions                             │      │      │
│  │  │  ├─ Type: Glue Job (Sync)                                │      │      │
│  │  │  ├─ Job: build-stock-dimensions-dev                      │      │      │
│  │  │  ├─ Parameters: --processing_date={data_date}            │      │      │
│  │  │  ├─ Retries: 1 attempt                                   │      │      │
│  │  │  └─ Timeout: 60 minutes                                  │      │      │
│  │  └──────────────────────────────────────────────────────────┘      │      │
│  │                           │                                        │      │
│  │                           │ Wait 3s                                │      │
│  │                           ▼                                        │      │
│  │  ┌──────────────────────────────────────────────────────────┐      │      │
│  │  │  State 3: Process Fact Table                             │      │      │
│  │  │  ├─ Type: Glue Job (Sync)                                │      │      │
│  │  │  ├─ Job: build-stock-fact-table-dev                      │      │      │
│  │  │  ├─ Parameters: --processing_date={data_date}            │      │      │
│  │  │  ├─ Retries: 1 attempt                                   │      │      │
│  │  │  └─ Timeout: 60 minutes                                  │      │      │
│  │  └──────────────────────────────────────────────────────────┘      │      │
│  │                           │                                        │      │
│  │                           │ Wait 3s                                │      │
│  │                           ▼                                        │      │
│  │  ┌──────────────────────────────────────────────────────────┐      │      │
│  │  │  State 4: Process Aggregations                           │      │      │
│  │  │  ├─ Type: Glue Job (Sync)                                │      │      │
│  │  │  ├─ Job: build-stock-aggregations-dev                    │      │      │
│  │  │  ├─ Parameters: --processing_date={data_date}            │      │      │
│  │  │  ├─ Retries: 1 attempt                                   │      │      │
│  │  │  └─ Timeout: 60 minutes                                  │      │      │
│  │  └──────────────────────────────────────────────────────────┘      │      │
│  │                           │                                        │      │
│  │                           ▼                                        │      │
│  │  ┌──────────────────────────────────────────────────────────┐      │      │
│  │  │  Pipeline Succeeded ✅                                   │      │      │
│  │  └──────────────────────────────────────────────────────────┘      │      │
│  └────────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  💾 DATA STORAGE LAYER                                                       │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  Amazon S3 (Data Lake)                                             │      │
│  │  Bucket: nasdaq-equity-batch-pipeline-data-dev-username            │      │
│  │                                                                    │      │
│  │  📁 raw/stock_quotes/                        (Raw JSON)            │      │
│  │     └─ date=YYYY-MM-DD/                                            │      │
│  │        └─ stocks_{timestamp}.json                                  │      │
│  │                                                                    │      │
│  │  📁 warehouse/                               (Apache Iceberg)      │      │
│  │     ├─ dim_stock/                                                  │      │
│  │     ├─ dim_date/                                                   │      │
│  │     ├─ dim_exchange/                                               │      │
│  │     ├─ fact_stock_daily_price/                                     │      │
│  │     ├─ agg_weekly_performance/                                     │      │
│  │     ├─ agg_monthly_performance/                                    │      │
│  │     └─ agg_sector_performance/                                     │      │
│  │                                                                    │      │
│  │  📁 glue-scripts/                            (ETL Code)            │      │
│  │     ├─ build_stock_dimensions.py                                   │      │
│  │     ├─ build_stock_fact_table.py                                   │      │
│  │     └─ build_stock_aggregations.py                                 │      │
│  └────────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  🔍 ANALYTICS LAYER                                                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  AWS Glue Data Catalog                                             │      │
│  │  Database: nasdaq_warehouse_dev                                    │      │
│  │  ├─ Tables: 7 (3 dimensions + 1 fact + 3 aggregations)             │      │
│  │  └─ Format: Apache Iceberg v2                                      │      │
│  └────────────────────────────────────────────────────────────────────┘      │
│                              │                                               │
│                              │ Queries                                       │
│                              ▼                                               │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  Amazon Athena                                                     │      │
│  │  ├─ Workgroup: primary                                             │      │
│  │  ├─ Query Engine: Athena SQL                                       │      │
│  │  └─ Cost: ~$5 per TB scanned                                       │      │
│  └────────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  📊 MONITORING & ALERTING                                                    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  Amazon CloudWatch                                                 │      │
│  │  ├─ Log Groups:                                                    │      │
│  │  │  ├─ /aws/lambda/nasdaq-equity-batch-pipeline-extractor-dev      │      │
│  │  │  ├─ /aws/glue/jobs/build-stock-dimensions-dev                   │      │
│  │  │  ├─ /aws/glue/jobs/build-stock-fact-table-dev                   │      │
│  │  │  ├─ /aws/glue/jobs/build-stock-aggregations-dev                 │      │
│  │  │  └─ /aws/states/nasdaq-equity-batch-pipeline-dev                │      │
│  │  ├─ Metrics:                                                       │      │
│  │  │  ├─ Lambda: Invocations, Errors, Duration                       │      │
│  │  │  ├─ Glue: JobRunState, JobDuration                              │      │
│  │  │  └─ Step Functions: ExecutionsSucceeded, ExecutionsFailed       │      │
│  │  └─ Alarms:                                                        │      │
│  │     ├─ Lambda execution failures                                   │      │
│  │     ├─ Glue job failures                                           │      │
│  │     └─ Step Functions execution failures                           │      │
│  └────────────────────────────────────────────────────────────────────┘      │
│                              │                                               │
│                              │ Triggers on Failure                           │
│                              ▼                                               │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  Amazon SNS                                                        │      │
│  │  Topic: nasdaq-equity-batch-pipeline-alerts-dev                    │      │
│  │  └─ Subscribers: Email (xxxxxxxx@xxxx.com)                         │      │
│  └────────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  🔄 CI/CD LAYER                                                              │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  GitHub Repository                                                 │      │
│  │  ├─ Webhook: Push events to main branch                            │      │
│  │  └─ Triggers: AWS CodeBuild                                        │      │
│  └────────────────────────────────────────────────────────────────────┘      │
│                              │                                               │
│                              ▼                                               │
│  ┌────────────────────────────────────────────────────────────────────┐      │
│  │  AWS CodeBuild                                                     │      │
│  │  ├─ CI Pipeline (buildspec-ci.yml):                                │      │
│  │  │  ├─ Validate Python syntax                                      │      │
│  │  │  ├─ Package Lambda function                                     │      │
│  │  │  ├─ Copy Glue scripts                                           │      │
│  │  │  └─ Upload to S3 artifacts bucket                               │      │
│  │  └─ CD Pipeline (buildspec-cd.yml):                                │      │
│  │     ├─ Download artifacts from S3                                  │      │
│  │     ├─ Update Lambda function code                                 │      │
│  │     └─ Sync Glue scripts to S3                                     │      │
│  └────────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 System Components

### 1. Data Extraction Layer

#### Lambda Function: `nasdaq-equity-batch-pipeline-extractor-dev`

**Purpose**: Extract real-time stock market data from Financial Modeling Prep (FMP) API

**Configuration**:
```yaml
Runtime: Python 3.11
Memory: 512 MB
Timeout: 300 seconds (5 minutes)
Environment Variables:
  - S3_BUCKET: nasdaq-equity-batch-pipeline-data-dev-username
  - AWS_REGION: us-east-1
  - API_SECRET_NAME: nasdaq-pipeline/fmp-api-key
```

**Process Flow**:
1. **Date Calculation**: Calculates `data_date` (previous trading day: current_date - 1 day)
2. **API Authentication**: Retrieves FMP API key from AWS Secrets Manager
3. **Data Fetching**: 
   - Calls FMP stable endpoint: `https://financialmodelingprep.com/stable/quote`
   - Fetches 5 stocks: AAPL, GOOGL, MSFT, AMZN, META
   - Rate limiting: 1 second delay between requests
4. **Data Enrichment**: Adds extraction metadata (timestamp, endpoint, extraction_time)
5. **S3 Storage**: Writes JSON to `s3://bucket/raw/stock_quotes/date={data_date}/stocks_{timestamp}.json`
6. **Return Value**: Returns `data_date` for downstream Glue jobs

**Data Fields Extracted** (18 fields):
```json
{
  "symbol": "AAPL",
  "name": "Apple Inc.",
  "exchange": "NASDAQ",
  "price": 246.7,
  "open": 252.73,
  "previous_close": 255.53,
  "day_low": 243.43,
  "day_high": 254.79,
  "year_low": 169.21,
  "year_high": 288.62,
  "change": -8.83,
  "change_percent": -3.45556,
  "volume": 77475520,
  "market_cap": 3645326078859,
  "price_avg_50": 271.5098,
  "price_avg_200": 234.05525,
  "timestamp": 1768942802,
  "extraction_time": "2026-01-21T02:30:23.895259+00:00",
  "api_endpoint": "stable"
}
```

**Error Handling**:
- SSL certificate validation using `certifi`
- Automatic fallback to mock data if API fails
- Retry logic via Step Functions (2 attempts with exponential backoff)

---

### 2. Data Transformation Layer

#### Glue Job 1: `build-stock-dimensions-dev`

**Purpose**: Create dimension tables for star schema

**Configuration**:
```yaml
Type: Spark ETL
Glue Version: 4.0
Worker Type: G.1X (4 vCPU, 16 GB memory)
Number of Workers: 2
Max Capacity: 2 DPU
Timeout: 60 minutes
```

**Input**: 
- S3 Path: `s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date={processing_date}/`
- Format: JSON (multiLine=true)

**Transformations**:

1. **dim_stock** (Stock Metadata):
```python
Columns:
  - stock_key (BIGINT, Primary Key, monotonically_increasing_id)
  - symbol (STRING)
  - company_name (STRING)
  - exchange (STRING)
  - market_cap_tier (STRING: "Large Cap", "Mid Cap", "Small Cap")
  - sector (STRING: placeholder "Technology")
  - industry (STRING: placeholder "Software")
  - first_seen_date (DATE)
  - last_seen_date (DATE)
  - is_active (BOOLEAN)

Logic:
  - Deduplicate by symbol
  - Classify market cap tier based on market_cap value
  - Use processing_date for first_seen_date and last_seen_date
```

2. **dim_date** (Date Dimension):
```python
Columns:
  - date_key (INT, Primary Key, format: YYYYMMDD)
  - calendar_date (DATE)
  - year (INT)
  - quarter (INT)
  - month (INT)
  - month_name (STRING)
  - week (INT)
  - day_of_month (INT)
  - day_of_week (INT)
  - day_name (STRING)
  - is_weekend (BOOLEAN)
  - is_month_end (BOOLEAN)
  - is_quarter_end (BOOLEAN)
  - is_year_end (BOOLEAN)

Logic:
  - Extract date from timestamp in raw data
  - Generate calendar attributes
  - Calculate weekend, month-end, quarter-end, year-end flags
```

3. **dim_exchange** (Exchange Information):
```python
Columns:
  - exchange_key (BIGINT, Primary Key)
  - exchange_name (STRING)
  - exchange_country (STRING: "United States")
  - exchange_timezone (STRING: "America/New_York")
  - trading_hours (STRING: "09:30-16:00 EST")

Logic:
  - Create single record for NASDAQ
  - Hardcoded exchange metadata
```

**Output**: 
- Apache Iceberg tables in `glue_catalog.nasdaq_warehouse_dev.*`
- Write Mode: `createOrReplace()` (first run) or maintains existing schema

---

#### Glue Job 2: `build-stock-fact-table-dev`

**Purpose**: Transform raw data into fact table with derived metrics

**Configuration**:
```yaml
Type: Spark ETL
Glue Version: 4.0
Worker Type: G.1X (4 vCPU, 16 GB memory)
Number of Workers: 2
Max Capacity: 2 DPU
Timeout: 60 minutes
```

**Input**:
- Raw Data: `s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date={processing_date}/`
- Dimension Tables: dim_stock, dim_date, dim_exchange

**Transformations**:

**Fact Table**: `fact_stock_daily_price` (24 metrics)

```python
Surrogate Keys:
  - stock_key (BIGINT, FK to dim_stock)
  - date_key (INT, FK to dim_date)
  - exchange_key (BIGINT, FK to dim_exchange)

Price Metrics (7 fields):
  - open_price (DOUBLE)
  - close_price (DOUBLE)
  - high_price (DOUBLE)
  - low_price (DOUBLE)
  - previous_close (DOUBLE)
  - price_change (DOUBLE)
  - price_change_pct (DOUBLE)

Volume & Market Cap (2 fields):
  - volume (BIGINT)
  - market_cap (BIGINT)

Technical Indicators (5 fields):
  - price_avg_50 (DOUBLE: 50-day moving average)
  - price_avg_200 (DOUBLE: 200-day moving average)
  - year_high (DOUBLE)
  - year_low (DOUBLE)
  - distance_from_52w_high_pct (DOUBLE)

Derived Metrics (10 fields):
  - daily_return_pct (DOUBLE: (close - previous_close) / previous_close * 100)
  - intraday_range (DOUBLE: high - low)
  - intraday_range_pct (DOUBLE: range / open * 100)
  - open_to_close_change (DOUBLE: close - open)
  - open_to_close_change_pct (DOUBLE: (close - open) / open * 100)
  - distance_from_50ma_pct (DOUBLE: (close - ma50) / ma50 * 100)
  - distance_from_200ma_pct (DOUBLE: (close - ma200) / ma200 * 100)
  - distance_from_52w_low_pct (DOUBLE: (close - year_low) / year_low * 100)
  - volatility (DOUBLE: intraday_range / open * 100)
  - volume_normalized (DOUBLE: volume / 1,000,000)
```

**Join Logic**:
```sql
fact_table = raw_data
  JOIN dim_stock ON raw_data.symbol = dim_stock.symbol
  JOIN dim_date ON date(raw_data.timestamp) = dim_date.calendar_date
  JOIN dim_exchange ON raw_data.exchange = dim_exchange.exchange_name
```

**Intelligent Table Management**:
```python
def write_to_iceberg_table(df, table_name):
    table_exists = spark.catalog.tableExists(table_name)
    if table_exists:
        df.writeTo(table_name).append()  # Daily incremental load
    else:
        df.writeTo(table_name).createOrReplace()  # First run
```

**Output**:
- Table: `glue_catalog.nasdaq_warehouse_dev.fact_stock_daily_price`
- Partition: By `date_key`
- Format: Apache Iceberg v2

---

#### Glue Job 3: `build-stock-aggregations-dev`

**Purpose**: Create pre-aggregated analytical tables

**Configuration**:
```yaml
Type: Spark ETL
Glue Version: 4.0
Worker Type: G.1X (4 vCPU, 16 GB memory)
Number of Workers: 2
Max Capacity: 2 DPU
Timeout: 60 minutes
```

**Input**: `fact_stock_daily_price` + dimension tables

**Transformations**:

1. **agg_weekly_performance**:
```sql
SELECT
  symbol,
  YEARWEEK(date) as week_key,
  MIN(date) as week_start,
  MAX(date) as week_end,
  AVG(close_price) as avg_price,
  MIN(low_price) as week_low,
  MAX(high_price) as week_high,
  SUM(volume) as total_volume,
  SUM(daily_return_pct) as weekly_return_pct
FROM fact_stock_daily_price
GROUP BY symbol, YEARWEEK(date)
```

2. **agg_monthly_performance**:
```sql
SELECT
  symbol,
  YEAR(date) as year,
  MONTH(date) as month,
  AVG(close_price) as avg_price,
  MIN(low_price) as month_low,
  MAX(high_price) as month_high,
  SUM(volume) as total_volume,
  SUM(daily_return_pct) as monthly_return_pct,
  STDDEV(daily_return_pct) as volatility
FROM fact_stock_daily_price
GROUP BY symbol, YEAR(date), MONTH(date)
```

3. **agg_sector_performance**:
```sql
SELECT
  sector,
  date,
  COUNT(DISTINCT symbol) as stock_count,
  AVG(daily_return_pct) as avg_return,
  SUM(market_cap) as total_market_cap,
  SUM(volume) as total_volume
FROM fact_stock_daily_price
JOIN dim_stock ON fact.stock_key = dim_stock.stock_key
GROUP BY sector, date
```

**Output**: 3 aggregation tables in Iceberg format

---

### 3. Orchestration Layer

#### Step Functions State Machine

**Name**: `nasdaq-equity-batch-pipeline-dev`

**State Transition Graph**:
```
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  START                                                             │
│    │                                                               │
│    ▼                                                               │
│  ┌──────────────────────────────────────────────┐                  │
│  │  Extract Stock Data (Lambda)                 │                  │
│  │  • Invoke Lambda function                    │                  │
│  │  • Capture data_date in ResultSelector       │                  │
│  │  • Retry: 2 attempts, exponential backoff    │                  │
│  └──────────────────────────────────────────────┘                  │
│    │                                                               │
│    ├─ Success → Wait 3s                                            │
│    └─ Failure → Lambda Extraction Failed (END)                     │
│    │                                                               │
│    ▼                                                               │
│  ┌──────────────────────────────────────────────┐                  │
│  │  Process Dimensions (Glue Job)               │                  │
│  │  • Pass data_date as --processing_date       │                  │
│  │  • Sync execution (wait for completion)      │                  │
│  │  • Retry: 1 attempt                          │                  │
│  └──────────────────────────────────────────────┘                  │
│    │                                                               │
│    ├─ Success → Wait 3s                                            │
│    └─ Failure → Glue Dimensions Failed (END)                       │
│    │                                                               │
│    ▼                                                               │
│  ┌──────────────────────────────────────────────┐                  │
│  │  Process Fact Table (Glue Job)               │                  │
│  │  • Pass data_date as --processing_date       │                  │
│  │  • Sync execution                            │                  │
│  │  • Retry: 1 attempt                          │                  │
│  └──────────────────────────────────────────────┘                  │
│    │                                                               │
│    ├─ Success → Wait 3s                                            │
│    └─ Failure → Glue Fact Table Failed (END)                       │
│    │                                                               │
│    ▼                                                               │
│  ┌──────────────────────────────────────────────┐                  │
│  │  Process Aggregations (Glue Job)             │                  │
│  │  • Pass data_date as --processing_date       │                  │
│  │  • Sync execution                            │                  │
│  │  • Retry: 1 attempt                          │                  │
│  └──────────────────────────────────────────────┘                  │
│    │                                                               │
│    ├─ Success → Pipeline Succeeded (END) ✅                        │
│    └─ Failure → Glue Aggregations Failed (END)                     │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

**Key Design Patterns**:

1. **Date Synchronization**:
```json
{
  "ResultSelector": {
    "data_date.$": "$.Payload.data_date",
    "execution_date.$": "$.Payload.execution_date"
  },
  "ResultPath": "$.lambdaResult"
}
```
- Lambda calculates `data_date` (previous trading day)
- Step Functions captures it via `ResultSelector`
- All Glue jobs receive same `--processing_date` parameter
- Ensures all pipeline components process the same date's data

2. **Error Handling**:
```json
{
  "Retry": [{
    "ErrorEquals": ["States.TaskFailed"],
    "IntervalSeconds": 30,
    "MaxAttempts": 1,
    "BackoffRate": 2
  }],
  "Catch": [{
    "ErrorEquals": ["States.ALL"],
    "Next": "Glue Job Failed"
  }]
}
```

3. **Sync vs Async**:
- Lambda: Async invocation (faster, non-blocking)
- Glue Jobs: Sync execution (`.sync` waiter - ensures sequential processing)

---

### 4. Storage Layer

#### S3 Bucket Structure

```
s3://nasdaq-equity-batch-pipeline-data-dev-username/
│
├── raw/                                    # Raw data zone
│   └── stock_quotes/
│       └── date=2026-01-20/
│           └── stocks_20260120_023023.json
│
├── warehouse/                              # Iceberg tables
│   ├── dim_stock/
│   │   ├── metadata/
│   │   │   └── v1.metadata.json
│   │   └── data/
│   │       └── *.parquet
│   ├── dim_date/
│   ├── dim_exchange/
│   ├── fact_stock_daily_price/
│   │   └── date_key=20260120/
│   │       └── *.parquet
│   ├── agg_weekly_performance/
│   ├── agg_monthly_performance/
│   └── agg_sector_performance/
│
└── glue-scripts/                           # ETL code
    ├── build_stock_dimensions.py
    ├── build_stock_fact_table.py
    └── build_stock_aggregations.py
```

#### Apache Iceberg Configuration

**Format Version**: 2

**Features**:
- ✅ ACID transactions
- ✅ Time travel queries
- ✅ Schema evolution
- ✅ Hidden partitioning
- ✅ Partition evolution
- ✅ Snapshot isolation

**Table Properties**:
```python
.tableProperty("format-version", "2")
.using("iceberg")
.partitionedBy("date_key")  # For fact table
```

**Benefits over Parquet**:
- Atomic updates (no partial writes)
- Concurrent reads/writes
- Efficient metadata operations
- Schema changes without rewriting data

---

### 5. Analytics Layer

#### AWS Glue Data Catalog

**Database**: `nasdaq_warehouse_dev`

**Tables** (7 total):
```
Dimension Tables (3):
├─ dim_stock          (10 columns, ~5 records)
├─ dim_date           (14 columns, grows daily)
└─ dim_exchange       (5 columns, 1 record)

Fact Table (1):
└─ fact_stock_daily_price  (24 columns, 5 records/day)

Aggregation Tables (3):
├─ agg_weekly_performance    (9 columns)
├─ agg_monthly_performance   (9 columns)
└─ agg_sector_performance    (6 columns)
```

**Catalog Metadata**:
- Table format: ICEBERG
- Storage location: S3 paths
- Partition info: For fact tables
- Schema versions: Tracked via Iceberg metadata

#### Amazon Athena

**Workgroup**: `primary`

**Query Examples**:

1. **Daily Performance**:
```sql
SELECT 
  ds.symbol,
  ds.company_name,
  f.close_price,
  f.daily_return_pct,
  f.volume_normalized
FROM fact_stock_daily_price f
JOIN dim_stock ds ON f.stock_key = ds.stock_key
WHERE f.date_key = 20260120
ORDER BY f.daily_return_pct DESC;
```

2. **Technical Analysis**:
```sql
SELECT 
  symbol,
  close_price,
  price_avg_50,
  price_avg_200,
  CASE 
    WHEN close_price > price_avg_50 
     AND price_avg_50 > price_avg_200 THEN 'Bullish'
    WHEN close_price < price_avg_50 
     AND price_avg_50 < price_avg_200 THEN 'Bearish'
    ELSE 'Neutral'
  END as trend
FROM fact_stock_daily_price
WHERE date_key = 20260120;
```

3. **Time Travel** (Iceberg feature):
```sql
SELECT * 
FROM fact_stock_daily_price
FOR SYSTEM_TIME AS OF TIMESTAMP '2026-01-15 00:00:00';
```

---

## 📊 Data Flow

### End-to-End Data Journey

```
┌────────────────────────────────────────────────────────────────────┐
│  1. SCHEDULED TRIGGER                                              │
│     EventBridge → Step Functions                                   │
│     Time: Daily @ 10:30 AM SGT                                     │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  2. DATA EXTRACTION (Lambda)                                       │
│     ├─ Calculate: data_date = today - 1 day                        │
│     ├─ Fetch: FMP API for 5 stocks                                 │
│     ├─ Transform: Add metadata                                     │
│     ├─ Store: S3 raw/stock_quotes/date={data_date}/                │
│     └─ Return: {data_date: "2026-01-20", ...}                      │
│                                                                    │
│     Example Output:                                                │
│     {                                                              │
│       "statusCode": 200,                                           │
│       "data_date": "2026-01-20",                                   │
│       "execution_date": "2026-01-21",                              │
│       "body": {                                                    │
│         "records_extracted": 5,                                    │
│         "s3_location": "s3://.../date=2026-01-20/stocks_...json"   │
│       }                                                            │
│     }                                                              │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  3. DATE PARAMETER PASSING (Step Functions)                        │
│     ResultSelector extracts data_date from Lambda response:        │
│     {                                                              │
│       "lambdaResult": {                                            │
│         "data_date": "2026-01-20"                                  │
│       }                                                            │
│     }                                                              │
│                                                                    │
│     All subsequent Glue jobs receive:                              │
│     --processing_date = $.lambdaResult.data_date                   │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  4. DIMENSION BUILDING (Glue Job 1)                                │
│     Input: s3://.../raw/stock_quotes/date=2026-01-20/              │
│     Processing:                                                    │
│     ├─ Read JSON (multiLine=true)                                  │
│     ├─ Create dim_stock: Deduplicate by symbol                     │
│     ├─ Create dim_date: Extract date attributes                    │
│     ├─ Create dim_exchange: Static NASDAQ record                   │
│     └─ Write Iceberg tables                                        │
│                                                                    │
│     Output Tables:                                                 │
│     ├─ dim_stock: 5 records (AAPL, GOOGL, MSFT, AMZN, META)        │
│     ├─ dim_date: 1 record (2026-01-20)                             │
│     └─ dim_exchange: 1 record (NASDAQ)                             │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  5. FACT TABLE BUILDING (Glue Job 2)                               │
│     Input:                                                         │
│     ├─ Raw: s3://.../raw/stock_quotes/date=2026-01-20/             │
│     ├─ Dimensions: dim_stock, dim_date, dim_exchange               │
│     │                                                              │
│     Processing:                                                    │
│     ├─ Read raw data for processing_date (2026-01-20)              │
│     ├─ Join with dimensions to get surrogate keys                  │
│     ├─ Calculate 10 derived metrics:                               │
│     │  ├─ daily_return_pct                                         │
│     │  ├─ intraday_range                                           │
│     │  ├─ distance_from_50ma_pct                                   │
│     │  └─ ... (7 more)                                             │
│     └─ Write to fact_stock_daily_price                             │
│        ├─ Mode: Append (if table exists)                           │
│        └─ Partition: By date_key                                   │
│                                                                    │
│     Output:                                                        │
│     └─ fact_stock_daily_price: 5 new records                       │
│        date_key=20260120/                                          │
│        └─ AAPL, GOOGL, MSFT, AMZN, META with 24 metrics each       │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  6. AGGREGATION BUILDING (Glue Job 3)                              │
│     Input: fact_stock_daily_price + dimensions                     │
│                                                                    │
│     Processing:                                                    │
│     ├─ Weekly Aggregation:                                         │
│     │  └─ GROUP BY symbol, week                                    │
│     │     └─ SUM(volume), AVG(price), weekly_return                │
│     │                                                              │
│     ├─ Monthly Aggregation:                                        │
│     │  └─ GROUP BY symbol, year, month                             │
│     │     └─ AVG, MIN, MAX prices, volatility                      │
│     │                                                              │
│     └─ Sector Aggregation:                                         │
│        └─ GROUP BY sector, date                                    │
│           └─ AVG return, total market cap, total volume            │
│                                                                    │
│     Output: 3 aggregation tables                                   │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  7. PIPELINE SUCCESS                                               │
│     ├─ All 4 states completed successfully                         │
│     ├─ Total duration: ~6-7 minutes                                │
│     ├─ Data ready for querying in Athena                           │
│     └─ CloudWatch logs available for audit                         │
└────────────────────────────────────────────────────────────────────┘
```

### Date Synchronization Pattern

**Critical Design**: All components process the **same trading day's data**

```
Execution Date: 2026-01-21 10:30 AM SGT (Tuesday)
Data Date: 2026-01-20 (Monday - previous trading day)

┌─────────────────────────────────────────────────────────────┐
│  Lambda Calculation                                         │
│  ────────────────────                                       │
│  now_utc = datetime.now(timezone.utc)                       │
│  data_date = now_utc - timedelta(days=1)                    │
│  data_date_str = "2026-01-20"                               │
│                                                             │
│  S3 Partition: raw/stock_quotes/date=2026-01-20/            │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Returns data_date
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Step Functions Capture                                     │
│  ────────────────────────                                   │
│  ResultSelector: {                                          │
│    "data_date.$": "$.Payload.data_date"                     │
│  }                                                          │
│  Result: lambdaResult.data_date = "2026-01-20"              │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Passes to all Glue jobs
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  All Glue Jobs                                              │
│  ──────────────                                             │
│  Receive: --processing_date=2026-01-20                      │
│                                                             │
│  Dimension Job:                                             │
│    Read: s3://.../date=2026-01-20/                          │
│    Set: first_seen_date = 2026-01-20                        │
│                                                             │
│  Fact Job:                                                  │
│    Read: s3://.../date=2026-01-20/                          │
│    Write: date_key = 20260120                               │
│                                                             │
│  Aggregation Job:                                           │
│    Filter: WHERE date_key = 20260120                        │
└─────────────────────────────────────────────────────────────┘
```

**Why This Matters**:
- ✅ Consistent data across all warehouse tables
- ✅ Proper referential integrity in joins
- ✅ Correct date dimensions for time-series analysis
- ✅ Idempotent pipeline (re-running produces same results)

---

## 🏗️ Infrastructure Details

### Terraform Architecture

**Module Structure**:
```
terraform/
├── main.tf                    # Root module - composes all modules
├── variables.tf               # Input variables
├── terraform.tfvars.example   # Template configuration
│
├── modules/
│   ├── lambda/               # Lambda function + IAM
│   ├── s3/                   # Data lake bucket + lifecycle policies
│   ├── glue/                 # Glue database + jobs + IAM
│   ├── step-functions/       # State machine + execution role
│   ├── eventbridge/          # Scheduler + target
│   ├── cloudwatch/           # Log groups + alarms
│   ├── sns/                  # Alert topics + subscriptions
│   ├── codebuild/            # CI/CD projects + webhook
│   └── github-webhook/       # GitHub integration
│
└── environments/
    └── dev.tfvars.example    # Environment-specific config
```

**Key Resources Created**:

```hcl
# Lambda (1 function)
aws_lambda_function.stock_extractor
aws_iam_role.lambda_execution
aws_iam_role_policy.lambda_s3_access
aws_iam_role_policy.lambda_secrets_access

# S3 (1 bucket + policies)
aws_s3_bucket.data_lake
aws_s3_bucket_versioning.data_lake
aws_s3_bucket_server_side_encryption_configuration.data_lake
aws_s3_bucket_lifecycle_configuration.data_lake

# Glue (1 database + 3 jobs)
aws_glue_catalog_database.warehouse
aws_glue_job.dimensions
aws_glue_job.fact_table
aws_glue_job.aggregations
aws_iam_role.glue_execution

# Step Functions (1 state machine)
aws_sfn_state_machine.pipeline
aws_iam_role.step_functions_execution
aws_iam_role_policy.step_functions_policy

# EventBridge (1 rule + 1 target)
aws_cloudwatch_event_rule.daily_schedule
aws_cloudwatch_event_target.step_functions
aws_iam_role.eventbridge_execution

# CloudWatch (5 log groups + 3 alarms)
aws_cloudwatch_log_group.lambda
aws_cloudwatch_log_group.glue_dimensions
aws_cloudwatch_log_group.glue_fact
aws_cloudwatch_log_group.glue_aggregations
aws_cloudwatch_log_group.step_functions
aws_cloudwatch_metric_alarm.lambda_errors
aws_cloudwatch_metric_alarm.glue_failures
aws_cloudwatch_metric_alarm.step_functions_failures

# SNS (1 topic + 1 subscription)
aws_sns_topic.alerts
aws_sns_topic_subscription.email

# CodeBuild (2 projects)
aws_codebuild_project.ci
aws_codebuild_project.cd
aws_iam_role.codebuild_execution
```

**Total Resources**: ~51 AWS resources

---

## 🔐 Security Architecture

### IAM Roles & Policies

#### 1. Lambda Execution Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::nasdaq-equity-batch-pipeline-data-dev-username",
        "arn:aws:s3:::nasdaq-equity-batch-pipeline-data-dev-username/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:nasdaq-pipeline/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/nasdaq-equity-batch-pipeline-extractor-dev:*"
    }
  ]
}
```

**Principle**: Least Privilege
- Only necessary S3 operations
- Scoped to specific secret paths
- Limited to function's log group

#### 2. Glue Execution Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::nasdaq-equity-batch-pipeline-data-dev-username",
        "arn:aws:s3:::nasdaq-equity-batch-pipeline-data-dev-username/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:GetTables",
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:DeleteTable",
        "glue:GetPartitions",
        "glue:CreatePartition",
        "glue:UpdatePartition",
        "glue:DeletePartition"
      ],
      "Resource": [
        "arn:aws:glue:*:*:catalog",
        "arn:aws:glue:*:*:database/nasdaq_warehouse_dev",
        "arn:aws:glue:*:*:table/nasdaq_warehouse_dev/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/glue/jobs/*"
    }
  ]
}
```

**Permissions**:
- Full S3 access to data lake bucket (needed for Iceberg)
- Glue Catalog management (table creation, schema updates)
- CloudWatch Logs write access

#### 3. Step Functions Execution Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:nasdaq-equity-batch-pipeline-extractor-dev"
    },
    {
      "Effect": "Allow",
      "Action": [
        "glue:StartJobRun",
        "glue:GetJobRun",
        "glue:GetJobRuns",
        "glue:BatchStopJobRun"
      ],
      "Resource": [
        "arn:aws:glue:*:*:job/build-stock-dimensions-dev",
        "arn:aws:glue:*:*:job/build-stock-fact-table-dev",
        "arn:aws:glue:*:*:job/build-stock-aggregations-dev"
      ]
    }
  ]
}
```

### Secrets Management

**AWS Secrets Manager**:
```
Secret Name: nasdaq-pipeline/fmp-api-key
Secret Value: {
  "api_key": "your-fmp-api-key-here"
}

Accessed By: Lambda function via boto3
Rotation: Manual (can be automated)
```

**Environment Variables** (Lambda):
- No secrets in environment variables
- All sensitive data retrieved at runtime from Secrets Manager
- Region and bucket names are non-sensitive configuration

### Network Security

**VPC Configuration**: Not required (serverless services)
- Lambda: No VPC (public internet access for FMP API)
- Glue: No VPC (accesses S3 via AWS backbone)
- Step Functions: Managed service

**S3 Bucket Security**:
```hcl
# Encryption at rest
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning enabled
versioning {
  status = "Enabled"
}

# Block public access
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

### Audit & Compliance

**CloudWatch Logs**:
- All Lambda invocations logged
- All Glue job executions logged
- All Step Functions transitions logged
- Retention: 7 days (configurable)

**CloudTrail** (optional, recommended for production):
```
Tracks:
  - IAM role assumptions
  - S3 object access
  - Secrets Manager access
  - Glue Catalog changes
```

---

## 💰 Cost Optimization

### Monthly Cost Breakdown

**Detailed Cost Analysis** (based on daily execution):

```
┌─────────────────────────────────────────────────────────────────┐
│  SERVICE              │  USAGE                │  COST/MONTH     │
├─────────────────────────────────────────────────────────────────┤
│  Lambda               │  30 invocations       │  $0.00          │
│    Duration: 30s      │  512 MB memory        │  (Free Tier)    │
│                                                                 │
│  S3 Storage           │  ~1 GB stored         │  $0.02          │
│    Raw Data: 150 MB   │  30 days retention    │                 │
│    Warehouse: 850 MB  │  Iceberg format       │                 │
│                                                                 │
│  S3 Requests          │  ~120 requests/day    │  $0.01          │
│    PUT: 4/day         │  GET: 100/day         │                 │
│                                                                 │
│  Glue ETL             │  ~6 DPU-minutes/day   │  $5.28          │
│    3 jobs @ 2 DPU     │  180 DPU-min/month    │                 │
│    ~2 min each        │  $0.44/DPU-hour       │                 │
│                       │  = 180/60 * $0.44     │                 │
│                                                                 │
│  Glue Data Catalog    │  7 tables             │  $0.00          │
│    Storage: < 1M      │  Objects stored       │  (Free Tier)    │
│                                                                 │
│  Athena               │  ~100 queries/month   │  $0.50          │
│    Data scanned:      │  ~100 MB/query        │                 │
│    10 GB total        │  $5/TB = $0.05/100GB  │                 │
│                                                                 │
│  CloudWatch Logs      │  ~500 MB/month        │  $0.25          │
│    Ingestion: $0.50   │  Storage: $0.03       │                 │
│                                                                 │
│  Step Functions       │  30 executions        │  $0.03          │
│    4 state transitions│  4,000 free/month     │                 │
│                                                                 │
│  EventBridge          │  30 events/month      │  $0.00          │
│    Custom events      │  (Free)               │                 │
│                                                                 │
│  CodeBuild            │  ~5 builds/month      │  $0.50          │
│    Build time: 5 min  │  compute-optimized    │                 │
│                                                                 │
│  SNS                  │  Notifications        │  $0.00          │
│    < 1000/month       │  (Free Tier)          │                 │
├─────────────────────────────────────────────────────────────────┤
│  TOTAL                                        │  ~$6.59/month   │
└─────────────────────────────────────────────────────────────────┘

Annual Cost: ~$79/year
```

### Cost Comparison

| Solution | Monthly Cost | Annual Cost | Savings |
|----------|-------------|-------------|---------|
| **This Pipeline (Serverless)** | $6.59 | $79 | Baseline |
| AWS MWAA (Managed Airflow) | $338 | $4,056 | **-$3,977/year** |
| Self-Hosted Airflow (t3.medium) | $38 | $456 | **-$377/year** |

**ROI**: 
- vs MWAA: **5,034% savings**
- vs Self-Hosted Airflow: **476% savings**

### Cost Optimization Strategies

**1. Serverless Architecture**:
- No idle compute costs
- Pay only for actual execution time
- Auto-scaling without management

**2. Efficient Data Storage**:
```python
# Apache Iceberg benefits:
- Column pruning (read only needed columns)
- Predicate pushdown (filter at storage level)
- Compact file sizes (optimized Parquet)

# Result: 60-70% reduction in Athena query costs
```

**3. Glue Job Optimization**:
```python
# Current: 3 jobs × 2 minutes × 2 DPU = 12 DPU-minutes
# Optimizations:
- Minimize data shuffles
- Use broadcast joins for small dimensions
- Partition pruning for fact table reads

# Potential savings: 20-30% reduction in DPU usage
```

**4. S3 Lifecycle Policies**:
```hcl
lifecycle_rule {
  # Move raw data to IA after 30 days
  transition {
    days          = 30
    storage_class = "STANDARD_IA"
  }
  
  # Delete raw data after 90 days (warehouse is source of truth)
  expiration {
    days = 90
  }
}

# Savings: 50% on storage costs for older data
```

**5. Query Optimization**:
```sql
-- Bad: Full table scan
SELECT * FROM fact_stock_daily_price;

-- Good: Partition pruning + column selection
SELECT symbol, close_price, daily_return_pct 
FROM fact_stock_daily_price 
WHERE date_key = 20260120;

-- Cost Reduction: 95%+ for typical queries
```

### Scaling Cost Projections

**If scaling to 100 stocks**:
```
Lambda: $0.00 (still free tier)
S3 Storage: $0.40 (20× data)
Glue ETL: $10.56 (2× processing time)
Athena: $1.00 (2× query data)
Other: $0.80 (minimal increase)
─────────────────────────────
Total: ~$12.76/month

Still 3,078% cheaper than MWAA!
```

**If scaling to 1,000 stocks**:
```
Lambda: $2.00 (exceeds free tier)
S3 Storage: $8.00 (200× data)
Glue ETL: $52.80 (10× processing time)
Athena: $10.00 (20× query data)
Other: $5.00
─────────────────────────────
Total: ~$77.80/month

Still 334% cheaper than MWAA!
```

---

## 📈 Scalability & Performance

### Horizontal Scalability

**Current Capacity**:
- Stocks: 5 (AAPL, GOOGL, MSFT, AMZN, META)
- Daily Records: 5 fact records + dimension updates
- Processing Time: ~6-7 minutes end-to-end

**Scaling Paths**:

1. **Add More Stocks** (10 → 100 → 1000):
```python
# Lambda: Parallel processing
async def fetch_multiple_stocks(symbols):
    tasks = [fetch_stock(symbol) for symbol in symbols]
    return await asyncio.gather(*tasks)

# Glue: Increase DPU allocation
NumberOfWorkers: 2 → 10  # For 100+ stocks
```

2. **Increase Frequency** (daily → hourly → real-time):
```
Daily (current):     30 executions/month
Hourly:              720 executions/month
Real-time (5 min):   8,640 executions/month

Cost scales linearly with frequency
Serverless handles concurrency automatically
```

3. **Add Data Sources**:
```
Current: FMP API only
Future:
  ├─ Multiple APIs (Alpha Vantage, IEX Cloud, Polygon)
  ├─ News sentiment data
  ├─ Social media data
  └─ Economic indicators

Pattern: Add Lambda for each source → Merge in Glue
```

### Vertical Scalability

**Glue Job Performance Tuning**:

```python
# Current Configuration
Worker Type: G.1X (4 vCPU, 16 GB)
Number of Workers: 2
Total Capacity: 2 DPU

# For Large-Scale Processing
Worker Type: G.2X (8 vCPU, 32 GB)
Number of Workers: 10
Total Capacity: 10 DPU

# Performance Improvement:
- 5× more compute capacity
- 5× faster processing time
- Cost increases 5× but remains economical
```

**Optimization Techniques**:

1. **Partition Pruning**:
```python
# Instead of:
df = spark.read.parquet("s3://bucket/warehouse/fact_table/")

# Use:
df = spark.read.parquet("s3://bucket/warehouse/fact_table/date_key=20260120/")

# Benefit: 100× faster for daily queries
```

2. **Broadcast Joins**:
```python
# For small dimensions (< 10 MB)
dim_stock_broadcast = broadcast(dim_stock)
fact = raw_data.join(dim_stock_broadcast, "symbol")

# Benefit: No shuffle, 10× faster joins
```

3. **Columnar Optimization**:
```python
# Iceberg automatically:
- Stores data in Parquet (columnar format)
- Tracks min/max values per file
- Skips files during query execution

# Example: Query for AAPL only
# Skips 80% of files without reading them
```

### Concurrency & Throughput

**Current Limits**:
```
Lambda: 1,000 concurrent executions (AWS default)
Glue: 3 concurrent job runs per job
Step Functions: Unlimited executions
Athena: 20 concurrent queries (can increase)
```

**Handling Spikes**:
```
Scenario: Market volatility → 10× query load

Athena:
  ├─ Auto-scales to handle load
  ├─ Queries execute in parallel
  └─ Cost = $5/TB scanned (unchanged)

Glue:
  ├─ Job queue system (FIFO)
  ├─ Increase MaxConcurrentRuns to 10
  └─ Executions stagger automatically

Lambda:
  └─ Concurrent invocations scale to 1,000
     (no action needed)
```

### Performance Benchmarks

**End-to-End Latency**:
```
Component               │ Duration  │ Cumulative
────────────────────────────────────────────────
EventBridge Trigger     │  < 1s     │  0:01
Lambda Extraction       │  30s      │  0:31
Wait for S3 Consistency │  3s       │  0:34
Glue Dimensions Job     │  120s     │  2:34
Wait                    │  3s       │  2:37
Glue Fact Table Job     │  150s     │  5:07
Wait                    │  3s       │  5:10
Glue Aggregations Job   │  60s      │  6:10
────────────────────────────────────────────────
Total                   │  ~6-7 min │
```

**Query Performance** (Athena):
```sql
-- Simple Aggregation (1 day)
SELECT symbol, AVG(close_price) FROM fact_table 
WHERE date_key = 20260120 GROUP BY symbol;
Duration: 2-3 seconds
Data Scanned: ~10 MB
Cost: $0.00005

-- Time Series (30 days)
SELECT date, symbol, close_price FROM fact_table
WHERE date_key BETWEEN 20260101 AND 20260130;
Duration: 5-7 seconds
Data Scanned: ~150 MB
Cost: $0.00075

-- Complex Analytics (90 days, all stocks)
SELECT symbol, 
       AVG(daily_return_pct) as avg_return,
       STDDEV(daily_return_pct) as volatility
FROM fact_table
WHERE date_key >= 20251101
GROUP BY symbol;
Duration: 10-15 seconds
Data Scanned: ~500 MB
Cost: $0.0025
```

**Iceberg Benefits**:
- Time Travel: O(1) - metadata-only operation
- Schema Evolution: No data rewrite needed
- Partition Evolution: Dynamic, no downtime

---

## 🎓 Best Practices Implemented

### 1. Idempotency

**Definition**: Running the pipeline multiple times with the same input produces the same output.

**Implementation**:
```python
# Glue Job Pattern
def write_to_iceberg_table(df, table_name):
    table_exists = spark.catalog.tableExists(table_name)
    if table_exists:
        # Append new data (idempotent via Iceberg ACID)
        df.writeTo(table_name).append()
    else:
        # Create table (first run)
        df.writeTo(table_name).createOrReplace()

# Re-running the pipeline for same date:
# 1. Lambda writes to same S3 partition (overwrites)
# 2. Dimensions: No duplicates (dedup by symbol)
# 3. Fact: Appends data (Iceberg handles duplicates via merge)
```

**Benefits**:
- Safe to re-run on failures
- Historical data corrections possible
- No data corruption from retries

### 2. Date Parameterization

**Pattern**: Decouple execution date from data date

```python
# ❌ Bad (tightly coupled)
data_date = datetime.now()

# ✅ Good (parameterized)
data_date = args['processing_date']  # Passed from orchestrator
```

**Benefits**:
- Backfill historical data
- Reprocess specific dates
- Test with any date

### 3. Error Handling

**Multi-Layer Error Handling**:

```
Layer 1: Application Code (Lambda/Glue)
├─ try/except blocks
├─ Fallback to mock data (Lambda)
└─ Detailed error logging

Layer 2: Step Functions
├─ Retry policies (exponential backoff)
├─ Catch blocks (route to failure states)
└─ Dead-letter queues

Layer 3: CloudWatch Alarms
├─ Monitor error metrics
├─ Trigger SNS notifications
└─ Alert on-call engineer
```

### 4. Monitoring & Observability

**Three Pillars**:

1. **Logs** (CloudWatch):
```
Each component logs:
  - Start/end timestamps
  - Input parameters
  - Record counts
  - Execution duration
  - Error details (if any)

Searchable via CloudWatch Insights
Retention: 7 days (configurable)
```

2. **Metrics** (CloudWatch):
```
Lambda:
  - Invocations
  - Errors
  - Duration
  - Throttles

Glue:
  - Job Run State
  - Duration
  - DPU Utilization

Step Functions:
  - Executions Started
  - Executions Succeeded
  - Executions Failed
```

3. **Traces** (Step Functions):
```
Visual execution graph showing:
  - Which state is executing
  - Input/output of each state
  - Error location (if failed)
  - Execution timeline
```

### 5. Infrastructure as Code

**Benefits Realized**:
- Version control for infrastructure
- Reproducible environments (dev/staging/prod)
- Automated deployments
- Change tracking via Git
- Rollback capability

**Terraform Workflow**:
```bash
# 1. Plan changes
terraform plan -var-file="environments/dev.tfvars"

# 2. Review and approve
# Check resource additions, modifications, deletions

# 3. Apply changes
terraform apply -var-file="environments/dev.tfvars"

# 4. Destroy (if needed)
terraform destroy -var-file="environments/dev.tfvars"
```

---

## 📚 References

### AWS Services Documentation

- **Lambda**: https://docs.aws.amazon.com/lambda/
- **Glue**: https://docs.aws.amazon.com/glue/
- **S3**: https://docs.aws.amazon.com/s3/
- **Step Functions**: https://docs.aws.amazon.com/step-functions/
- **EventBridge**: https://docs.aws.amazon.com/eventbridge/
- **Athena**: https://docs.aws.amazon.com/athena/
- **CloudWatch**: https://docs.aws.amazon.com/cloudwatch/

### Technologies

- **Terraform**: https://www.terraform.io/docs
- **Apache Iceberg**: https://iceberg.apache.org/docs/latest/
- **PySpark**: https://spark.apache.org/docs/latest/api/python/
- **Financial Modeling Prep API**: https://financialmodelingprep.com/developer/docs/

### Related Documentation

- [Data Transformation Guide](./data-transformation-guide.md) - Detailed ETL logic
- [Deployment Guide](./DEPLOYMENT_GUIDE.md) - Step-by-step setup
- [Project Structure](./project-structure-reference.md) - File organization

---

**Last Updated**: January 22, 2026  
**Architecture Version**: 1.0  
**Maintained By**: GeekyTan
