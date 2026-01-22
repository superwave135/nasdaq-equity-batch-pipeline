# NASDAQ Equity Batch Pipeline - Project Structure Reference

> **Complete guide to the project's file organization and codebase structure**

---

## 📋 Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Core Components](#core-components)
- [Configuration Files](#configuration-files)
- [Documentation](#documentation)
- [Development Guidelines](#development-guidelines)

---

## 🎯 Overview

### Project Organization Principles

1. **Separation of Concerns**: Code, infrastructure, and documentation are clearly separated
2. **Environment Isolation**: Dev/staging/prod configurations are independent
3. **Infrastructure as Code**: All AWS resources defined in Terraform
4. **CI/CD Ready**: Automated build and deployment scripts included
5. **Production-Grade**: Follows AWS Well-Architected Framework principles

### Technology Stack Summary

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Orchestration** | AWS Step Functions, EventBridge | Workflow automation |
| **Extraction** | AWS Lambda (Python 3.11) | API data extraction |
| **Transformation** | AWS Glue (PySpark) | ETL processing |
| **Storage** | Amazon S3, Apache Iceberg | Data lake and warehouse |
| **Analytics** | AWS Athena, Glue Catalog | SQL querying |
| **Infrastructure** | Terraform 1.5+ | IaC provisioning |
| **CI/CD** | AWS CodeBuild, GitHub | Automated deployment |
| **Monitoring** | CloudWatch, SNS | Logging and alerting |

---

## 📁 Directory Structure

### Complete Project Tree

```
nasdaq-equity-batch-pipeline/
│
├── README.md                              # Project overview and quick start
├── requirements.txt                       # Python dependencies for development
│
├── terraform/                             # Infrastructure as Code
│   ├── main.tf                            # Root module composition
│   ├── variables.tf                       # Input variable definitions
│   ├── terraform.tfvars.example           # Template configuration
│   │
│   ├── modules/                           # Reusable Terraform modules
│   │   ├── lambda/                        # Lambda function module
│   │   │   ├── main.tf                    # Lambda resource definitions
│   │   │   └── variables.tf               # Module input variables
│   │   │
│   │   ├── s3/                            # S3 bucket module
│   │   │   ├── main.tf                    # Bucket, policies, lifecycle rules
│   │   │   └── variables.tf               # Module variables
│   │   │
│   │   ├── glue/                          # Glue jobs and database module
│   │   │   ├── main.tf                    # Glue resources
│   │   │   └── variables.tf               # Module variables
│   │   │
│   │   ├── step-functions/                # Step Functions state machine
│   │   │   ├── main.tf                    # State machine definition
│   │   │   ├── variables.tf               # Module variables
│   │   │   └── README.md                  # State machine documentation
│   │   │
│   │   ├── eventbridge/                   # EventBridge scheduler
│   │   │   ├── main.tf                    # Schedule rules and targets
│   │   │   ├── variables.tf               # Module variables
│   │   │   └── README.md                  # Scheduling documentation
│   │   │
│   │   ├── cloudwatch/                    # CloudWatch logs and alarms
│   │   │   ├── main.tf                    # Log groups, alarms
│   │   │   └── variables.tf               # Module variables
│   │   │
│   │   ├── sns/                           # SNS topics and subscriptions
│   │   │   ├── main.tf                    # Notification topics
│   │   │   └── variables.tf               # Module variables
│   │   │
│   │   ├── codebuild/                     # CodeBuild CI/CD projects
│   │   │   ├── main.tf                    # Build projects
│   │   │   ├── iam.tf                     # IAM roles and policies
│   │   │   ├── outputs.tf                 # Module outputs
│   │   │   └── variables.tf               # Module variables
│   │   │
│   │   └── github-webhook/                # GitHub integration
│   │       ├── main.tf                    # Webhook resources
│   │       └── variables.tf               # Module variables
│   │
│   └── environments/                      # Environment-specific configs
│       ├── dev.tfvars.example             # Development template
│       └── CHANGELOG.md                   # Infrastructure changes log
│
├── lambda/                                # Lambda function code
│   └── stock_extractor/                   # Stock data extractor function
│       ├── lambda_function.py             # Main handler (259 lines)
│       ├── config.py                      # Configuration (29 lines)
│       └── requirements.txt               # Python dependencies
│
├── glue/                                  # Glue ETL jobs
│   └── jobs/                              # PySpark transformation scripts
│       ├── build_stock_dimensions.py      # Dimension table builder (174 lines)
│       ├── build_stock_fact_table.py      # Fact table builder (267 lines)
│       └── build_stock_aggregations.py    # Aggregation builder (180 lines)
│
├── cicd/                                  # CI/CD pipeline
│   ├── buildspec-ci.yml                   # CI build specification
│   ├── buildspec-cd.yml                   # CD deployment specification
│   │
│   └── scripts/                           # Build and deployment scripts
│       ├── package-lambda.sh              # Lambda packaging script (88 lines)
│       ├── deploy.sh                      # Deployment automation (50 lines)
│       └── test-pipeline.sh               # Integration test script (225 lines)
│
└── docs/                                  # Documentation
    ├── architecture-detailed.md           # Complete architecture guide
    ├── data-transformation-guide.md       # ETL and data model documentation
    ├── deployment_guide.md                # Step-by-step deployment
    ├── project-structure-reference.md     # This file
    ├── api_data_sample.json               # Sample API response
    └── diagrams/                          # Architecture diagrams (optional)
```

**Total Files**: ~40 core files  
**Lines of Code**: ~2,500+ lines (Python + HCL + Shell)

---

## 🔧 Core Components

### 1. Lambda Function: Stock Extractor

**Location**: `lambda/stock_extractor/`

#### `lambda_function.py` (259 lines)

**Purpose**: Extract real-time stock data from FMP API and store in S3

**Key Functions**:

```python
def get_api_key() -> str
    """Retrieve FMP API key from AWS Secrets Manager"""
    # Lines 16-30
    # Returns: API key string

def get_jsonparsed_data(url: str) -> dict
    """Fetch and parse JSON from URL with SSL context"""
    # Lines 32-52
    # Uses: certifi for SSL certificate validation
    # Returns: Parsed JSON dictionary

def fetch_fmp_quote(symbol: str, api_key: str) -> dict
    """Fetch real-time quote from FMP stable endpoint"""
    # Lines 54-106
    # Endpoint: https://financialmodelingprep.com/stable/quote
    # Returns: Normalized stock data dict (18 fields)

def fetch_real_data(symbols: list, api_key: str) -> list
    """Fetch data for multiple symbols with rate limiting"""
    # Lines 108-126
    # Rate Limit: 1 second delay between requests
    # Returns: List of stock data dicts

def generate_mock_data(symbols: list, data_date_str: str) -> list
    """Generate mock data for testing (fallback)"""
    # Lines 128-160
    # Returns: List of mock stock data

def save_to_s3(data: list, data_date_str: str) -> dict
    """Save stock data to S3 with date partitioning"""
    # Lines 162-197
    # S3 Path: s3://bucket/raw/stock_quotes/date=YYYY-MM-DD/stocks_TIMESTAMP.json
    # Returns: S3 location metadata

def lambda_handler(event: dict, context: object) -> dict
    """Main Lambda entry point"""
    # Lines 199-259
    # Returns: {statusCode, data_date, execution_date, body}
```

**Data Flow**:
```
1. Calculate data_date (previous trading day)
2. Retrieve API key from Secrets Manager
3. Fetch real data OR generate mock data
4. Save to S3 with date partition
5. Return data_date for downstream jobs
```

**Environment Variables** (configured via Terraform):
```python
AWS_REGION = "us-east-1"
S3_BUCKET = "nasdaq-equity-batch-pipeline-data-dev-username"
API_SECRET_NAME = "nasdaq-pipeline/fmp-api-key"
DEFAULT_SYMBOLS = ['AAPL', 'GOOGL', 'MSFT', 'AMZN', 'META']
USE_MOCK_DATA = False
RATE_LIMIT_DELAY = 1.0
```

#### `config.py` (29 lines)

**Purpose**: Centralized configuration management

```python
# AWS Configuration
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
S3_BUCKET = os.environ.get('S3_BUCKET')

# API Configuration
API_SECRET_NAME = os.environ.get('API_SECRET_NAME', 'nasdaq-pipeline/fmp-api-key')
API_PROVIDER = os.environ.get('API_PROVIDER', 'fmp')

# Stock Symbols
DEFAULT_SYMBOLS = ['AAPL', 'GOOGL', 'MSFT', 'AMZN', 'META']

# Mock Mode
USE_MOCK_DATA = os.environ.get("USE_MOCK_DATA", 'false').lower() in ("1", "true", "yes")

# FMP API
FMP_BASE_URL = 'https://financialmodelingprep.com/api/v3'

# Rate Limiting
RATE_LIMIT_DELAY = float(os.environ.get('RATE_LIMIT_DELAY', '1'))
```

#### `requirements.txt`

```
boto3==1.34.44      # AWS SDK
requests==2.32.0    # HTTP library (not used, prefer urllib)
certifi             # SSL certificates for Lambda
```

---

### 2. Glue ETL Jobs

**Location**: `glue/jobs/`

#### `build_stock_dimensions.py` (174 lines)

**Purpose**: Build dimension tables for star schema

**Structure**:
```python
# Lines 1-33: Imports and initialization
from awsglue.transforms import *
from pyspark.sql.functions import *
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'processing_date'])

# Lines 34-52: Read raw data
raw_df = spark.read.option("multiLine", "true").json("s3://.../raw/stock_quotes/date=*/")

# Lines 53-80: Build dim_stock
dim_stock = raw_df.select(
    monotonically_increasing_id().alias("stock_key"),
    col("symbol"),
    col("name").alias("company_name"),
    ...
).dropDuplicates(["symbol"])

# Lines 81-138: Build dim_date
dim_date = raw_df.select(
    date_format(col("calendar_date"), "yyyyMMdd").cast("int").alias("date_key"),
    year(), quarter(), month(), ...
)

# Lines 139-162: Build dim_exchange
dim_exchange = raw_df.select("exchange").distinct().select(...)

# Lines 163-174: Write to Iceberg tables
dim_stock.writeTo("glue_catalog.nasdaq_warehouse_dev.dim_stock").createOrReplace()
```

**Tables Created**:
1. `dim_stock` (10 columns): Stock metadata
2. `dim_date` (14 columns): Calendar dimension
3. `dim_exchange` (5 columns): Exchange information

#### `build_stock_fact_table.py` (267 lines)

**Purpose**: Transform raw data into fact table with derived metrics

**Structure**:
```python
# Lines 1-43: Initialization and date handling
processing_date = args['processing_date']

# Lines 44-90: Smart table write function
def write_to_iceberg_table(df, table_name, partition_cols=None):
    table_exists = spark.catalog.tableExists(table_name)
    if table_exists:
        df.writeTo(table_name).append()  # Incremental load
    else:
        df.writeTo(table_name).createOrReplace()  # First run

# Lines 91-109: Read data
raw_df = spark.read.json(f"s3://.../date={processing_date}/")
dim_stock = spark.table("glue_catalog.nasdaq_warehouse_dev.dim_stock")
dim_date = spark.table("glue_catalog.nasdaq_warehouse_dev.dim_date")

# Lines 110-135: Join with dimensions
fact_base = raw_df.join(dim_stock, "symbol").join(dim_date, "calendar_date")

# Lines 136-230: Calculate derived metrics (10 metrics)
fact_table = fact_base.select(
    stock_key, date_key, exchange_key,
    # Price metrics (7 fields)
    col("price").alias("close_price"),
    ...
    # Derived metrics (10 fields)
    ((col("price") - col("previousClose")) / col("previousClose") * 100).alias("daily_return_pct"),
    ...
)

# Lines 231-267: Write to fact table with partitioning
write_to_iceberg_table(fact_table, "...fact_stock_daily_price", partition_cols="date_key")
```

**Fact Table Schema**:
- **Surrogate Keys**: 3 (stock_key, date_key, exchange_key)
- **Price Metrics**: 7 (open, close, high, low, etc.)
- **Volume & Market**: 2 (volume, market_cap)
- **Technical Indicators**: 5 (MA50, MA200, year high/low)
- **Derived Metrics**: 10 (daily_return_pct, volatility, etc.)
- **Total Columns**: 24

#### `build_stock_aggregations.py` (180 lines)

**Purpose**: Pre-aggregate data for faster analytics

**Structure**:
```python
# Lines 1-40: Initialization and read tables
fact = spark.table("glue_catalog.nasdaq_warehouse_dev.fact_stock_daily_price")
dim_stock = spark.table("glue_catalog.nasdaq_warehouse_dev.dim_stock")
dim_date = spark.table("glue_catalog.nasdaq_warehouse_dev.dim_date")

# Lines 41-75: Weekly aggregation
weekly_agg = fact.groupBy(symbol, year, week).agg(
    avg("close_price"), sum("volume"), sum("daily_return_pct"), ...
)

# Lines 76-110: Monthly aggregation
monthly_agg = fact.groupBy(symbol, year, month).agg(
    avg("close_price"), stddev("daily_return_pct"), ...
)

# Lines 111-145: Sector aggregation
sector_agg = fact.join(dim_stock).groupBy(sector, date).agg(
    count("symbol"), avg("daily_return_pct"), sum("market_cap"), ...
)

# Lines 146-180: Write aggregation tables
write_to_iceberg_table(weekly_agg, "...agg_weekly_performance")
write_to_iceberg_table(monthly_agg, "...agg_monthly_performance")
write_to_iceberg_table(sector_agg, "...agg_sector_performance")
```

**Aggregations Created**:
1. `agg_weekly_performance` (9 columns)
2. `agg_monthly_performance` (9 columns)
3. `agg_sector_performance` (6 columns)

---

### 3. Terraform Infrastructure

**Location**: `terraform/`

#### `main.tf` (Root Module)

**Purpose**: Compose all infrastructure modules

**Structure**:
```hcl
# Provider Configuration
provider "aws" {
  region = var.aws_region
}

# Module: S3 Data Lake
module "s3" {
  source = "./modules/s3"
  bucket_name = var.s3_bucket_name
  ...
}

# Module: Lambda Function
module "lambda" {
  source = "./modules/lambda"
  function_name = var.lambda_function_name
  s3_bucket = module.s3.bucket_name
  ...
}

# Module: Glue Jobs and Database
module "glue" {
  source = "./modules/glue"
  database_name = var.glue_database_name
  s3_bucket = module.s3.bucket_name
  ...
}

# Module: Step Functions State Machine
module "step_functions" {
  source = "./modules/step-functions"
  lambda_arn = module.lambda.function_arn
  glue_job_dimensions = module.glue.job_dimensions_name
  ...
}

# Module: EventBridge Scheduler
module "eventbridge" {
  source = "./modules/eventbridge"
  target_arn = module.step_functions.state_machine_arn
  schedule_expression = var.schedule_expression
  ...
}

# Module: CloudWatch Monitoring
module "cloudwatch" {
  source = "./modules/cloudwatch"
  lambda_function_name = module.lambda.function_name
  ...
}

# Module: SNS Notifications
module "sns" {
  source = "./modules/sns"
  alert_email = var.alert_email
  ...
}

# Optional: CI/CD Modules
module "codebuild" {
  count = var.enable_cicd ? 1 : 0
  source = "./modules/codebuild"
  ...
}

module "github_webhook" {
  count = var.enable_cicd ? 1 : 0
  source = "./modules/github-webhook"
  ...
}
```

**Module Dependencies**:
```
s3 (base layer)
  ↓
lambda → step_functions → eventbridge
  ↓         ↓
glue ───────┘
  ↓
cloudwatch → sns
```

#### `variables.tf` (Variable Definitions)

**Categories**:
```hcl
# Project Configuration
variable "project_name" {}
variable "environment" {}
variable "aws_region" {}

# S3 Configuration
variable "s3_bucket_name" {}

# Lambda Configuration
variable "lambda_function_name" {}
variable "lambda_runtime" { default = "python3.11" }
variable "lambda_memory_size" { default = 512 }
variable "lambda_timeout" { default = 300 }

# Glue Configuration
variable "glue_database_name" {}
variable "glue_version" { default = "4.0" }
variable "glue_worker_type" { default = "G.1X" }
variable "glue_num_workers" { default = 2 }

# Step Functions Configuration
variable "state_machine_name" {}

# EventBridge Configuration
variable "schedule_expression" {}
variable "schedule_enabled" { default = true }

# API Configuration
variable "api_secret_name" {}
variable "stock_symbols" { type = list(string) }

# Monitoring Configuration
variable "log_retention_days" { default = 7 }
variable "alert_email" {}

# CI/CD Configuration
variable "enable_cicd" { default = false }
variable "github_repo" { default = "" }

# Tags
variable "tags" { type = map(string) }
```

---

### 4. CI/CD Pipeline

**Location**: `cicd/`

#### `buildspec-ci.yml` (CI Build Spec)

**Purpose**: Continuous Integration - validate code and create artifacts

**Phases**:
```yaml
install:
  - Install Python 3.11
  - Install dependencies from requirements.txt

pre_build:
  - Validate Python syntax
  - Check dependency versions

build:
  - Run pytest tests (if tests/ exists)
  - Validate Glue scripts syntax
  - Package Lambda function (./cicd/scripts/package-lambda.sh)
  - Copy Glue scripts to build/

post_build:
  - Upload Lambda package to S3 artifacts bucket
  - Upload Glue scripts to S3 artifacts bucket
  - Generate build summary
```

**Artifacts**:
```
build/
├── lambda/
│   └── lambda-function.zip
└── glue-scripts/
    ├── build_stock_dimensions.py
    ├── build_stock_fact_table.py
    └── build_stock_aggregations.py
```

#### `buildspec-cd.yml` (CD Deployment Spec)

**Purpose**: Continuous Deployment - deploy artifacts to AWS

**Phases**:
```yaml
pre_build:
  - Log deployment environment
  - Verify Lambda function exists

build:
  - Download Lambda package from CI artifacts
  - Update Lambda function code
  - Wait for Lambda update to complete
  - Download Glue scripts from CI artifacts
  - Upload Glue scripts to data bucket

post_build:
  - Verify Lambda deployment
  - Log deployment summary
  - Note: Orchestration resources managed by Terraform
```

**Environment Variables** (configured in CodeBuild):
```
LAMBDA_FUNCTION_NAME = nasdaq-equity-batch-pipeline-extractor-dev
S3_BUCKET = nasdaq-equity-batch-pipeline-data-dev-username
AWS_REGION = us-east-1
EVENTBRIDGE_RULE_NAME = nasdaq-equity-batch-pipeline-schedule-dev
STATE_MACHINE_NAME = nasdaq-equity-batch-pipeline-dev
```

#### `scripts/package-lambda.sh` (88 lines)

**Purpose**: Package Lambda function with dependencies

**Process**:
```bash
#!/bin/bash
set -e

# 1. Create temp directory
TEMP_DIR=$(mktemp -d)

# 2. Copy Lambda code
cp -r lambda/stock_extractor/* $TEMP_DIR/

# 3. Install dependencies
cd $TEMP_DIR
pip install -r requirements.txt -t . --upgrade --quiet

# 4. Remove unnecessary files
find . -type d -name "__pycache__" -exec rm -rf {} +
find . -type f -name "*.pyc" -delete

# 5. Create zip file
zip -r9 lambda-function.zip . -x "*.git*" -q

# 6. Move to build directory
mv lambda-function.zip $PROJECT_ROOT/build/lambda/

# 7. Generate checksums
md5sum build/lambda/lambda-function.zip
sha256sum build/lambda/lambda-function.zip

# 8. Cleanup temp directory
rm -rf $TEMP_DIR
```

**Output**: `build/lambda/lambda-function.zip` (~8-10 MB)

#### `scripts/test-pipeline.sh` (225 lines)

**Purpose**: End-to-end integration testing

**Test Suite**:
```bash
# Infrastructure Tests (8 tests)
test_lambda_exists
test_s3_bucket_exists
test_glue_database_exists
test_glue_scripts_in_s3
test_step_functions_exists
test_eventbridge_rule_exists
test_secrets_exist

# Lambda Function Tests
test_lambda_invocation
test_lambda_response_valid_json

# S3 Data Tests
test_raw_data_exists
test_processed_data_exists

# Glue Catalog Tests
test_glue_tables_exist
test_glue_table_count

# Results Summary
display_pass_fail_summary
calculate_pass_rate
```

**Usage**:
```bash
# Run all tests
./cicd/scripts/test-pipeline.sh dev

# Example output:
# ============================================
# 🧪 Pipeline Integration Test Script
# ============================================
# Configuration:
#   Environment: dev
#   Lambda Function: nasdaq-equity-batch-pipeline-extractor-dev
#   S3 Bucket: nasdaq-equity-batch-pipeline-data-dev-username
# 
# Test 1: Lambda function exists...
#   ✅ PASS: Lambda function exists
# Test 2: S3 bucket exists...
#   ✅ PASS: S3 bucket exists
# ...
# 
# ============================================
# 📋 Test Summary
# ============================================
# Total Tests: 8
# Passed: 8 ✅
# Failed: 0 ❌
# Pass Rate: 100.0%
# ============================================
```

---

## ⚙️ Configuration Files

### Root Level Configuration

#### `requirements.txt`

**Purpose**: Python dependencies for local development and testing

```
# AWS SDK
boto3>=1.34.0

# Testing
pytest>=7.4.0
pytest-cov>=4.1.0
moto>=4.2.0

# Utilities
python-dateutil>=2.8.2
```

**Usage**:
```bash
pip install -r requirements.txt
```

---

### Terraform Configuration

#### `terraform.tfvars.example`

**Purpose**: Template for user-specific configuration

**Key Sections**:
```hcl
# 1. Project Metadata
project_name = "nasdaq-equity-batch-pipeline"
environment = "dev"

# 2. AWS Configuration
aws_region = "us-east-1"

# 3. Resource Naming
s3_bucket_name = "nasdaq-equity-batch-pipeline-data-dev-YOUR-UNIQUE-ID"
lambda_function_name = "nasdaq-equity-batch-pipeline-extractor-dev"
glue_database_name = "nasdaq_warehouse_dev"

# 4. Scheduling
schedule_expression = "cron(30 2 * * ? *)"
schedule_enabled = true

# 5. Data Configuration
stock_symbols = ["AAPL", "GOOGL", "MSFT", "AMZN", "META"]

# 6. Secrets
api_secret_name = "nasdaq-pipeline/fmp-api-key"

# 7. Notifications
alert_email = "your-email@example.com"

# 8. Optional Features
enable_cicd = false
```

**Setup**:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

#### `environments/dev.tfvars.example`

**Purpose**: Environment-specific overrides

```hcl
# Development Environment Configuration

# Lower resource limits for cost savings
glue_num_workers = 2
lambda_memory_size = 512

# Shorter log retention
log_retention_days = 7

# Debug mode settings
USE_MOCK_DATA = "false"
```

---

## 📚 Documentation

### Documentation Files

#### `README.md` (root)

**Purpose**: Project overview and quick start guide

**Sections**:
- Project overview
- Architecture diagram (ASCII)
- Key features
- Technology stack
- Quick start (5 steps)
- Cost breakdown
- Sample queries
- Troubleshooting

**Target Audience**: New users, recruiters, contributors

#### `docs/architecture-detailed.md`

**Purpose**: Complete system architecture documentation

**Contents**:
- High-level architecture
- Component details (Lambda, Glue, Step Functions)
- Data flow diagrams
- Infrastructure details
- Security architecture
- Cost optimization
- Scalability patterns

**Target Audience**: Architects, technical reviewers

#### `docs/data-transformation-guide.md`

**Purpose**: ETL processes and data modeling

**Contents**:
- Star schema design
- Dimension table logic
- Fact table transformations
- Derived metric calculations
- Aggregation queries
- Data quality checks

**Target Audience**: Data engineers, analysts

#### `docs/DEPLOYMENT_GUIDE.md`

**Purpose**: Step-by-step deployment instructions

**Contents**:
- Prerequisites
- AWS setup
- Terraform deployment
- Code deployment
- Testing procedures
- Troubleshooting

**Target Audience**: DevOps engineers, new deployments

#### `docs/project-structure-reference.md` (this file)

**Purpose**: Codebase organization guide

**Contents**:
- Directory structure
- File descriptions
- Code organization
- Configuration files

**Target Audience**: Developers, contributors

---

## 👨‍💻 Development Guidelines

### Coding Standards

#### Python Code

**Style Guide**: PEP 8

**Key Conventions**:
```python
# 1. Function documentation
def process_stock_data(symbol: str, data: dict) -> dict:
    """
    Process raw stock data for a single symbol.
    
    Args:
        symbol: Stock ticker symbol (e.g., 'AAPL')
        data: Raw API response data
    
    Returns:
        Processed stock data dictionary
    """
    pass

# 2. Type hints
from typing import List, Dict, Optional

def fetch_multiple_stocks(symbols: List[str]) -> List[Dict]:
    pass

# 3. Error handling
try:
    data = fetch_api_data(url)
except HTTPError as e:
    print(f"HTTP Error {e.code}: {e.reason}")
    return None

# 4. Logging
print(f"Processing {len(symbols)} symbols...")
print(f"✓ Successfully fetched {symbol}: ${price}")
```

#### Terraform Code

**Style Guide**: HashiCorp Terraform Style

**Key Conventions**:
```hcl
# 1. Resource naming
resource "aws_lambda_function" "stock_extractor" {
  # Use descriptive names, not generic
}

# 2. Variable documentation
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

# 3. Module usage
module "lambda" {
  source = "./modules/lambda"
  
  # Pass variables explicitly
  function_name = var.lambda_function_name
  runtime       = var.lambda_runtime
}

# 4. Tagging
tags = merge(
  var.tags,
  {
    Name = "${var.project_name}-${var.environment}"
  }
)
```

### File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Python modules | `snake_case.py` | `build_stock_dimensions.py` |
| Terraform files | `kebab-case.tf` | `step-functions/main.tf` |
| Shell scripts | `kebab-case.sh` | `package-lambda.sh` |
| Documentation | `UPPER_CASE.md` or `kebab-case.md` | `DEPLOYMENT_GUIDE.md`, `architecture-detailed.md` |
| Configuration | `lowercase.ext` | `requirements.txt`, `terraform.tfvars` |

### Version Control

**Branching Strategy**:
```
main                # Production-ready code
  ├── develop       # Integration branch
  │   ├── feature/  # New features
  │   ├── fix/      # Bug fixes
  │   └── docs/     # Documentation updates
```

**Commit Message Format**:
```
type(scope): subject

[optional body]

[optional footer]

# Types: feat, fix, docs, refactor, test, chore
# Example:
feat(lambda): add error handling for API timeouts

Added retry logic with exponential backoff for FMP API calls.
Handles 429 Too Many Requests errors gracefully.

Closes #123
```

### Testing Guidelines

**Unit Tests** (Python):
```python
# tests/test_lambda_function.py
import pytest
from lambda_function import calculate_daily_return

def test_daily_return_calculation():
    assert calculate_daily_return(100, 110) == 10.0
    assert calculate_daily_return(100, 90) == -10.0

@pytest.fixture
def mock_stock_data():
    return {
        "symbol": "AAPL",
        "price": 150.0,
        "previousClose": 148.0
    }

def test_process_stock_data(mock_stock_data):
    result = process_stock_data(mock_stock_data)
    assert "daily_return_pct" in result
```

**Integration Tests** (Shell):
```bash
# cicd/scripts/test-pipeline.sh
test_lambda_exists() {
    aws lambda get-function \
        --function-name nasdaq-equity-batch-pipeline-extractor-dev \
        --region us-east-1 > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ PASS: Lambda function exists"
        return 0
    else
        echo "❌ FAIL: Lambda function not found"
        return 1
    fi
}
```

### Documentation Standards

**Code Comments**:
```python
# ✅ Good: Explain WHY, not WHAT
# Calculate data_date as previous trading day to ensure
# we capture end-of-day market data after markets close
data_date = now_utc - timedelta(days=1)

# ❌ Bad: Redundant comment
# Set data_date to yesterday
data_date = now_utc - timedelta(days=1)
```

**Inline Documentation**:
```python
# Use docstrings for functions
def fetch_fmp_quote(symbol: str, api_key: str) -> dict:
    """
    Fetch real-time quote from FMP API using stable endpoint.
    
    Args:
        symbol: Stock ticker symbol (e.g., 'AAPL')
        api_key: FMP API authentication key
    
    Returns:
        Dictionary containing stock data with keys:
        - symbol, name, exchange (identifiers)
        - price, open, high, low (price data)
        - volume, market_cap (market data)
        - timestamp, extraction_time (metadata)
    
    Raises:
        HTTPError: If API request fails
        ValueError: If symbol is invalid
    """
```

---

## 🔄 Maintenance & Updates

### Adding New Features

**1. Add New Stock Symbol**:
```bash
# Edit terraform/terraform.tfvars
stock_symbols = ["AAPL", "GOOGL", "MSFT", "AMZN", "META", "TSLA"]  # Add TSLA

# Apply
terraform apply

# Redeploy Lambda (picks up new config)
./cicd/scripts/package-lambda.sh
aws lambda update-function-code ...
```

**2. Add New Derived Metric**:
```python
# Edit glue/jobs/build_stock_fact_table.py
# Add new metric in select statement:

fact_table = fact_base.select(
    ...
    # NEW: Calculate RSI (Relative Strength Index)
    calculate_rsi(col("close_price"), window_spec).alias("rsi_14"),
    ...
)

# Upload to S3
aws s3 cp glue/jobs/build_stock_fact_table.py s3://.../glue-scripts/

# Re-run Glue job to rebuild table
```

**3. Add New Aggregation Table**:
```python
# Edit glue/jobs/build_stock_aggregations.py
# Add new aggregation:

daily_sector_agg = fact.join(dim_stock).groupBy("sector", "date").agg(...)
write_to_iceberg_table(daily_sector_agg, "...agg_daily_sector_performance")

# Deploy and run
```

### Updating Dependencies

**Python Dependencies**:
```bash
# Update requirements.txt
boto3==1.35.0  # Updated version

# Rebuild Lambda package
./cicd/scripts/package-lambda.sh

# Deploy
aws lambda update-function-code ...
```

**Terraform Provider**:
```hcl
# Edit terraform/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"  # Update version
    }
  }
}

# Run
terraform init -upgrade
terraform plan
terraform apply
```

### Monitoring Changes

**Track Infrastructure Changes**:
```bash
# View Terraform state
terraform show

# Compare with desired state
terraform plan

# View change history
git log --oneline -- terraform/
```

**Track Code Changes**:
```bash
# View file changes
git diff lambda/stock_extractor/lambda_function.py

# View commit history
git log --oneline --graph --all
```

---

## 📊 Metrics & KPIs

### Project Statistics

**Codebase Metrics**:
- **Total Lines of Code**: ~2,500
- **Python Code**: ~720 lines
- **Terraform Code**: ~1,200 lines
- **Shell Scripts**: ~400 lines
- **Documentation**: ~6,000+ lines

**Infrastructure Resources**:
- **AWS Resources**: 51 total
- **Lambda Functions**: 1
- **Glue Jobs**: 3
- **S3 Buckets**: 1
- **Step Functions**: 1
- **EventBridge Rules**: 1

**Data Metrics**:
- **Daily Records**: 5 fact records + dimension updates
- **Storage Growth**: ~50 KB/day (raw) + 200 KB/day (warehouse)
- **Monthly Storage**: ~7.5 MB total

---

## 🔗 Related Resources

### Internal Documentation
- [Architecture Details](./architecture-detailed.md)
- [Data Transformation Guide](./data-transformation-guide.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)

### External Resources
- **AWS Glue**: https://docs.aws.amazon.com/glue/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **Apache Iceberg**: https://iceberg.apache.org/docs/
- **PySpark**: https://spark.apache.org/docs/latest/api/python/

---

**Document Version**: 1.0  
**Last Updated**: January 21, 2026  
**Maintainer**: Data Engineering Team