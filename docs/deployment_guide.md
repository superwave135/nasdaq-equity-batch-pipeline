# NASDAQ Equity Batch Pipeline - Deployment Guide

> **Complete step-by-step guide to deploy the production-ready data pipeline**

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Post-Deployment](#post-deployment)

---

## ✅ Prerequisites

### Required Accounts & Access

#### 1. AWS Account
- **Access Level**: Administrator or PowerUser
- **Region**: us-east-1
- **Services Required**:
  - Lambda
  - S3
  - Glue
  - Step Functions
  - EventBridge
  - CloudWatch
  - Secrets Manager
  - IAM
  - CodeBuild (for CI/CD)

**AWS Academy Students**: 
- Use temporary credentials (valid for 4 hours)
- Re-authenticate before each deployment
- Budget: ~$10-15/month for this pipeline

#### 2. Financial Modeling Prep (FMP) API
- **Sign up**: https://financialmodelingprep.com/developer
- **Plan Required**: Free tier (250 calls/day) or paid
- **API Key**: Save this - you'll need it for Secrets Manager

#### 3. Development Tools
```bash
# Check versions
terraform --version   # Required: >= 1.5.0
python --version      # Required: >= 3.9
aws --version         # Required: >= 2.0

# If not installed:
# Terraform: https://www.terraform.io/downloads
# Python: https://www.python.org/downloads/
# AWS CLI: https://aws.amazon.com/cli/
```

#### 4. Optional (for CI/CD)
- GitHub account
- Git installed locally

---

## 🚀 Quick Start

**Total Time**: ~30 minutes

### Step 1: Clone Repository
```bash
git clone https://github.com/yourusername/nasdaq-equity-batch-pipeline.git
cd nasdaq-equity-batch-pipeline
```

### Step 2: Setting up and using the AWS access portal
```bash
# Copy credentials from AWS access portal. Click on the Access keys link.
# Copy and paste the following commands (from Option 1: Set AWS environment variables) into your cli terminal.
export AWS_ACCESS_KEY_ID="xxx..."
export AWS_SECRET_ACCESS_KEY="yyy..."
export AWS_SESSION_TOKEN="zzz..."

# Verify
aws sts get-caller-identity
```

### Step 3: Store FMP API Key
```bash
aws secretsmanager create-secret \
    --name nasdaq-pipeline/fmp-api-key \
    --secret-string '{"api_key":"YOUR_FMP_API_KEY"}' \
    --region us-east-1
```

### Step 4: Configure Terraform
```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Edit `terraform.tfvars`**:
```hcl
# Project Configuration
project_name = "nasdaq-equity-batch-pipeline"
environment  = "dev"

# AWS Configuration
aws_region = "us-east-1"

# S3 Bucket (must be globally unique)
s3_bucket_name = "nasdaq-equity-batch-pipeline-data-dev-YOUR-UNIQUE-ID"  # Change YOUR-UNIQUE-ID

# FMP API Configuration
api_secret_name = "nasdaq-pipeline/fmp-api-key"

# EventBridge Schedule (daily at 10:30 AM Singapore Time = 02:30 UTC). Please adjust according to your timezone.
schedule_expression = "cron(30 2 * * ? *)"

# Notification Email
alert_email = "your-email@example.com"  # Change this

# Stock Symbols
stock_symbols = ["AAPL", "GOOGL", "MSFT", "AMZN", "META"] 
```

### Step 5: Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (type 'yes' when prompted)
terraform apply

# Note: First deployment takes ~5-10 minutes
```

### Step 6: Upload Glue Scripts
```bash
# After Terraform completes, upload ETL scripts
aws s3 sync ../glue/jobs/ s3://YOUR-BUCKET-NAME/glue-scripts/ \
    --region us-east-1
```

### Step 7: Package and Deploy Lambda
```bash
cd ../cicd/scripts
chmod +x package-lambda.sh
./package-lambda.sh

# Upload Lambda package
aws lambda update-function-code \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --zip-file fileb://../../build/lambda/lambda-function.zip \
    --region us-east-1
```

### Step 8: Test Pipeline
```bash
# Manually trigger Step Functions
aws stepfunctions start-execution \
    --state-machine-arn $(terraform output -raw step_functions_arn) \
    --region us-east-1

# Monitor execution (replace EXECUTION_ARN from output above)
aws stepfunctions describe-execution \
    --execution-arn EXECUTION_ARN \
    --region us-east-1
```

**Done!** ✅ Your pipeline is now deployed and will run daily at 10:30 AM SGT.

---

## 📖 Detailed Setup

### Phase 1: Environment Preparation

#### 1.1 Verify AWS Access

```bash
# Check AWS credentials
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/YourUser"
# }

# If you get an error, reconfigure credentials
```

#### 1.2 Set Up Project Directory

```bash
# Create project directory
mkdir -p ~/projects
cd ~/projects

# Clone repository
git clone https://github.com/yourusername/nasdaq-equity-batch-pipeline.git
cd nasdaq-equity-batch-pipeline

# Verify structure
tree -L 2
```

**Expected Structure**:
```
nasdaq-equity-batch-pipeline/
├── README.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── modules/
│   └── environments/
├── lambda/
│   └── stock_extractor/
├── glue/
│   └── jobs/
├── cicd/
│   ├── buildspec-ci.yml
│   ├── buildspec-cd.yml
│   └── scripts/
└── docs/
```

#### 1.3 Install Python Dependencies

```bash
# Create virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Verify installations
pip list | grep -E "boto3|pytest|moto"
```

---

### Phase 2: AWS Services Setup

#### 2.1 Create FMP API Secret

**Why Secrets Manager?**
- Secure storage (encrypted at rest)
- No hardcoded credentials in code
- Automatic rotation capability
- Audit trail via CloudTrail

**Steps**:
```bash
# Option 1: AWS CLI
aws secretsmanager create-secret \
    --name nasdaq-pipeline/fmp-api-key \
    --description "FMP API key for NASDAQ Equity Batch pipeline" \
    --secret-string '{"api_key":"YOUR_FMP_API_KEY_HERE"}' \
    --region us-east-1

# Option 2: AWS Console
# 1. Navigate to AWS Secrets Manager
# 2. Click "Store a new secret"
# 3. Select "Other type of secret"
# 4. Key: api_key, Value: YOUR_FMP_API_KEY
# 5. Name: nasdaq-pipeline/fmp-api-key
# 6. Click "Store"
```

**Verify Secret**:
```bash
aws secretsmanager get-secret-value \
    --secret-id nasdaq-pipeline/fmp-api-key \
    --region us-east-1

# Expected output:
# {
#     "ARN": "arn:aws:secretsmanager:us-east-1:...",
#     "Name": "nasdaq-pipeline/fmp-api-key",
#     "SecretString": "{\"api_key\":\"YOUR_KEY\"}"
# }
```

#### 2.2 Create S3 Bucket (if not using Terraform)

**Optional**: Terraform creates this automatically. Manual creation only needed for troubleshooting.

```bash
# Create bucket
aws s3 mb s3://nasdaq-equity-batch-pipeline-data-dev-YOUR-UNIQUE-ID --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket nasdaq-equity-batch-pipeline-data-dev-YOUR-UNIQUE-ID \
    --versioning-configuration Status=Enabled \
    --region us-east-1

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket nasdaq-equity-batch-pipeline-data-dev-YOUR-UNIQUE-ID \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --region us-east-1

# Block public access
aws s3api put-public-access-block \
    --bucket nasdaq-equity-batch-pipeline-data-dev-YOUR-UNIQUE-ID \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region us-east-1
```

---

### Phase 3: Terraform Deployment

#### 3.1 Configure Variables

**Create `terraform/terraform.tfvars`**:
```hcl
#===============================================================================
# NASDAQ Equity Batch Pipeline - Terraform Configuration
#===============================================================================

# Project Metadata
project_name = "nasdaq-equity-batch-pipeline"
environment  = "dev"

# AWS Configuration
aws_region = "us-east-1"  # Singapore

# S3 Data Lake Bucket
# IMPORTANT: Must be globally unique - change YOUR-UNIQUE-ID
s3_bucket_name = "nasdaq-equity-batch-pipeline-data-dev-username"  # Example: use your GitHub username

# Lambda Configuration
lambda_function_name = "nasdaq-equity-batch-pipeline-extractor-dev"
lambda_runtime       = "python3.11"
lambda_memory_size   = 512
lambda_timeout       = 300  # 5 minutes

# Glue Configuration
glue_database_name = "nasdaq_warehouse_dev"
glue_version       = "4.0"
glue_worker_type   = "G.1X"
glue_num_workers   = 2

# Step Functions Configuration
state_machine_name = "nasdaq-equity-batch-pipeline-pipeline-dev"

# EventBridge Schedule
# Daily at 10:30 AM Singapore Time (02:30 UTC)
schedule_expression = "cron(30 2 * * ? *)"
schedule_enabled    = true

# API Configuration
api_secret_name = "nasdaq-pipeline/fmp-api-key"
stock_symbols   = ["AAPL", "GOOGL", "MSFT", "AMZN", "META"]

# CloudWatch Configuration
log_retention_days = 7

# SNS Notifications
alert_email = "your-email@example.com"  # CHANGE THIS

# CI/CD Configuration (optional)
enable_cicd = false  # Set to true if using GitHub integration
github_repo = ""     # Example: "yourusername/nasdaq-equity-batch-pipeline"
github_token_secret = ""  # Example: "github/personal-access-token"

# Tags
tags = {
  Project     = "NASDAQ Equity Batch Pipeline"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "DataEngineering"
}
```

**Validate Configuration**:
```bash
cd terraform

# Check syntax
terraform fmt -check

# Validate configuration
terraform validate

# Expected output:
# Success! The configuration is valid.
```

#### 3.2 Initialize Terraform

```bash
# Download provider plugins
terraform init

# Expected output:
# Initializing modules...
# Initializing the backend...
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0"...
# - Installing hashicorp/aws v5.31.0...
# Terraform has been successfully initialized!
```

**If you get provider errors**:
```bash
# Clear cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init -upgrade
```

#### 3.3 Plan Deployment

```bash
# Preview infrastructure changes
terraform plan -out=tfplan

# Review output carefully:
# - Resources to be created (should be ~51 resources)
# - No resources to be destroyed (on first run)
# - Check S3 bucket name is unique
```

**Key Resources Being Created**:
```
+ aws_lambda_function.stock_extractor
+ aws_s3_bucket.data_lake
+ aws_glue_catalog_database.warehouse
+ aws_glue_job.dimensions
+ aws_glue_job.fact_table
+ aws_glue_job.aggregations
+ aws_sfn_state_machine.pipeline
+ aws_cloudwatch_event_rule.schedule
+ aws_sns_topic.alerts
... (and 42 more)
```

#### 3.4 Apply Infrastructure

```bash
# Deploy infrastructure
terraform apply tfplan

# Alternative (interactive):
terraform apply

# Type 'yes' when prompted
# Deployment takes 5-10 minutes
```

**Monitor Progress**:
```
aws_iam_role.lambda_execution: Creating...
aws_s3_bucket.data_lake: Creating...
aws_glue_catalog_database.warehouse: Creating...
...
Apply complete! Resources: 51 added, 0 changed, 0 destroyed.

Outputs:
lambda_function_arn = "arn:aws:lambda:us-east-1:..."
s3_bucket_name = "nasdaq-equity-batch-pipeline-data-dev-username"
step_functions_arn = "arn:aws:states:us-east-1:..."
glue_database_name = "nasdaq_warehouse_dev"
```

**Save Outputs**:
```bash
# Save for later use
terraform output > terraform-outputs.txt
```

#### 3.5 Verify Infrastructure

```bash
# Check Lambda function
aws lambda get-function --function-name nasdaq-equity-batch-pipeline-extractor-dev --region us-east-1

# Check S3 bucket
aws s3 ls s3://nasdaq-equity-batch-pipeline-data-dev-username --region us-east-1

# Check Glue database
aws glue get-database --name nasdaq_warehouse_dev --region us-east-1

# Check Step Functions
aws stepfunctions list-state-machines --region us-east-1 | grep nasdaq-equity-batch-pipeline-pipeline
```

---

### Phase 4: Code Deployment

#### 4.1 Upload Glue Scripts

```bash
# Navigate to project root
cd /path/to/nasdaq-equity-batch-pipeline

# Sync Glue scripts to S3
aws s3 sync glue/jobs/ s3://nasdaq-equity-batch-pipeline-data-dev-username/glue-scripts/ \
    --region us-east-1

# Verify upload
aws s3 ls s3://nasdaq-equity-batch-pipeline-data-dev-username/glue-scripts/ --region us-east-1

# Expected output:
# 2026-01-21 10:30:00      15234 build_stock_aggregations.py
# 2026-01-21 10:30:00      18756 build_stock_dimensions.py
# 2026-01-21 10:30:00      22341 build_stock_fact_table.py
```

#### 4.2 Package Lambda Function

```bash
# Navigate to CI/CD scripts
cd cicd/scripts

# Make script executable
chmod +x package-lambda.sh

# Run packaging script
./package-lambda.sh

# Expected output:
# ============================================
# Packaging Lambda Function
# ============================================
# Project root: /path/to/nasdaq-equity-batch-pipeline
# Lambda directory: lambda/stock_extractor
# Temp directory: /tmp/tmp.XXXXXXXX
# 
# Copying Lambda code...
# Installing Python dependencies...
#   Dependencies installed
# Removing unnecessary files...
#   Cleanup complete
# Creating zip file...
#   Zip file created
# 
# ============================================
# Packaging Complete!
# ============================================
# Output file: build/lambda/lambda-function.zip
# File size: 8.2M
# MD5: a1b2c3d4e5f6...
# SHA256: 7f8e9d0c1b2a...
# ============================================
```

#### 4.3 Deploy Lambda Function

```bash
# Update Lambda function code
aws lambda update-function-code \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --zip-file fileb://../../build/lambda/lambda-function.zip \
    --region us-east-1

# Wait for update to complete
aws lambda wait function-updated \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --region us-east-1

# Verify deployment
aws lambda get-function-configuration \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --region us-east-1 \
    --query '[Runtime,LastModified,CodeSize,State]' \
    --output table
```

**Expected Output**:
```
-------------------------------------------------------------
|            GetFunctionConfiguration                      |
+------------------+----------------------+-----------------+
|  python3.11      |  2026-01-21T02:30:23 |  8623456       | Active
+------------------+----------------------+-----------------+
```

---

### Phase 5: Testing & Validation

#### 5.1 Test Lambda Function

```bash
# Create test event
cat > /tmp/test-event.json << EOF
{
  "test": true,
  "timestamp": "2026-01-21T02:30:00Z"
}
EOF

# Invoke Lambda
aws lambda invoke \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --payload file:///tmp/test-event.json \
    --region us-east-1 \
    /tmp/lambda-response.json

# Check response
cat /tmp/lambda-response.json | jq '.'

# Expected output:
# {
#   "statusCode": 200,
#   "data_date": "2026-01-20",
#   "execution_date": "2026-01-21",
#   "body": {
#     "records_extracted": 5,
#     "s3_location": "s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date=2026-01-20/...",
#     "data_source": "FMP_REAL",
#     "symbols": ["AAPL", "GOOGL", "MSFT", "AMZN", "META"],
#     "successful": 5,
#     "failed": 0
#   }
# }
```

#### 5.2 Verify S3 Data

```bash
# Check raw data was written
aws s3 ls s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/ --recursive --region us-east-1

# Expected output:
# 2026-01-21 02:30:23      4567 raw/stock_quotes/date=2026-01-20/stocks_20260121_023023.json

# Download and inspect
aws s3 cp s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date=2026-01-20/stocks_20260121_023023.json - | jq '.'
```

#### 5.3 Test Step Functions Pipeline

```bash
# Get state machine ARN
STATE_MACHINE_ARN=$(terraform output -raw step_functions_arn)

# Start execution
EXECUTION_ARN=$(aws stepfunctions start-execution \
    --state-machine-arn $STATE_MACHINE_ARN \
    --name "manual-test-$(date +%s)" \
    --region us-east-1 \
    --query 'executionArn' \
    --output text)

echo "Execution started: $EXECUTION_ARN"

# Monitor execution (refresh every 30 seconds)
watch -n 30 "aws stepfunctions describe-execution \
    --execution-arn $EXECUTION_ARN \
    --region us-east-1 \
    --query '[status,startDate,stopDate]' \
    --output table"

# View execution in AWS Console:
# https://us-east-1.console.aws.amazon.com/states/home?region=us-east-1#/executions/details/$EXECUTION_ARN
```

**Execution Timeline** (~6-7 minutes):
```
00:00 - Extract Stock Data (Lambda): 30s
00:33 - Wait: 3s
00:36 - Process Dimensions (Glue): 120s
02:36 - Wait: 3s
02:39 - Process Fact Table (Glue): 150s
05:09 - Wait: 3s
05:12 - Process Aggregations (Glue): 60s
06:12 - Pipeline Succeeded ✅
```

#### 5.4 Query Data with Athena

```bash
# Open Athena console
echo "https://us-east-1.console.aws.amazon.com/athena/home?region=us-east-1"

# Or use AWS CLI
aws athena start-query-execution \
    --query-string "SELECT * FROM nasdaq_warehouse_dev.fact_stock_daily_price LIMIT 10" \
    --result-configuration "OutputLocation=s3://nasdaq-equity-batch-pipeline-data-dev-username/athena-results/" \
    --region us-east-1
```

**Test Queries**:
```sql
-- 1. Check dimension tables
SELECT * FROM nasdaq_warehouse_dev.dim_stock;
SELECT * FROM nasdaq_warehouse_dev.dim_date;
SELECT * FROM nasdaq_warehouse_dev.dim_exchange;

-- 2. Check fact table
SELECT 
    ds.symbol,
    dd.calendar_date,
    f.close_price,
    f.daily_return_pct,
    f.volume_normalized
FROM nasdaq_warehouse_dev.fact_stock_daily_price f
JOIN nasdaq_warehouse_dev.dim_stock ds ON f.stock_key = ds.stock_key
JOIN nasdaq_warehouse_dev.dim_date dd ON f.date_key = dd.date_key
ORDER BY dd.calendar_date DESC, f.daily_return_pct DESC
LIMIT 10;

-- 3. Verify record counts
SELECT 
    'dim_stock' as table_name, COUNT(*) as record_count FROM nasdaq_warehouse_dev.dim_stock
UNION ALL
SELECT 'dim_date', COUNT(*) FROM nasdaq_warehouse_dev.dim_date
UNION ALL
SELECT 'fact_stock_daily_price', COUNT(*) FROM nasdaq_warehouse_dev.fact_stock_daily_price;
```

**Expected Results**:
| table_name | record_count |
|------------|--------------|
| dim_stock | 5 |
| dim_date | 1 |
| fact_stock_daily_price | 5 |

---

## ⚙️ Configuration

### Environment Variables

**Lambda Environment Variables** (set via Terraform):
```
S3_BUCKET = nasdaq-equity-batch-pipeline-data-dev-username
AWS_REGION = us-east-1
API_SECRET_NAME = nasdaq-pipeline/fmp-api-key
API_PROVIDER = fmp
USE_MOCK_DATA = false
RATE_LIMIT_DELAY = 1
```

**Glue Job Arguments** (passed by Step Functions):
```
--processing_date = YYYY-MM-DD  # Dynamically set by Lambda return value
```

### Scheduling

**Current Schedule**: Daily at 10:30 AM Singapore Time (02:30 UTC)

**Change Schedule**:
```bash
# Edit terraform/terraform.tfvars
schedule_expression = "cron(30 2 * * ? *)"  # Change this

# Common schedules:
# - Every hour: "cron(0 * * * ? *)"
# - Every 30 min: "cron(0/30 * * * ? *)"
# - Twice daily: "cron(0 0,12 * * ? *)"
# - Weekdays only: "cron(0 9 ? * MON-FRI *)"

# Apply changes
terraform apply

# Or temporarily disable
schedule_enabled = false
```

### Stock Symbols

**Add/Remove Stocks**:
```bash
# Edit terraform/terraform.tfvars
stock_symbols = ["AAPL", "GOOGL", "MSFT", "AMZN", "META", "TSLA", "NVDA"]  # Add TSLA, NVDA

# Update Lambda environment
terraform apply

# Or update directly
aws lambda update-function-configuration \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --environment "Variables={...}" \
    --region us-east-1
```

### Notification Settings

**Update Email**:
```bash
# Edit terraform/terraform.tfvars
alert_email = "new-email@example.com"

# Apply
terraform apply

# Confirm subscription in email
# Check inbox for "AWS Notification - Subscription Confirmation"
```

---

## 🔍 Verification

### Health Check Checklist

```bash
#!/bin/bash
# health-check.sh - Verify pipeline deployment

echo "=== NASDAQ Pipeline Health Check ==="
echo ""

# 1. Lambda
echo "✓ Checking Lambda function..."
aws lambda get-function --function-name nasdaq-equity-batch-pipeline-extractor-dev --region us-east-1 > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "  ✅ Lambda function exists"; else echo "  ❌ Lambda function not found"; fi

# 2. S3 Bucket
echo "✓ Checking S3 bucket..."
aws s3 ls s3://nasdaq-equity-batch-pipeline-data-dev-username --region us-east-1 > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "  ✅ S3 bucket accessible"; else echo "  ❌ S3 bucket not found"; fi

# 3. Glue Database
echo "✓ Checking Glue database..."
aws glue get-database --name nasdaq_warehouse_dev --region us-east-1 > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "  ✅ Glue database exists"; else echo "  ❌ Glue database not found"; fi

# 4. Glue Jobs
echo "✓ Checking Glue jobs..."
for job in build-stock-dimensions-dev build-stock-fact-table-dev build-stock-aggregations-dev; do
    aws glue get-job --job-name $job --region us-east-1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then echo "  ✅ $job exists"; else echo "  ❌ $job not found"; fi
done

# 5. Step Functions
echo "✓ Checking Step Functions..."
aws stepfunctions describe-state-machine --state-machine-arn $(terraform output -raw step_functions_arn) --region us-east-1 > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "  ✅ State machine exists"; else echo "  ❌ State machine not found"; fi

# 6. EventBridge Rule
echo "✓ Checking EventBridge schedule..."
aws events describe-rule --name nasdaq-equity-batch-pipeline-schedule-dev --region us-east-1 > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "  ✅ EventBridge rule exists"; else echo "  ❌ EventBridge rule not found"; fi

# 7. Secrets
echo "✓ Checking Secrets Manager..."
aws secretsmanager get-secret-value --secret-id nasdaq-pipeline/fmp-api-key --region us-east-1 > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "  ✅ API secret exists"; else echo "  ❌ API secret not found"; fi

echo ""
echo "=== Health Check Complete ==="
```

**Run Health Check**:
```bash
chmod +x health-check.sh
./health-check.sh
```

---

## 🐛 Troubleshooting

### Common Issues

#### Issue 1: Terraform Apply Fails - "BucketAlreadyExists"

**Error**:
```
Error: creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available
```

**Solution**:
```bash
# S3 bucket names must be globally unique
# Edit terraform/terraform.tfvars
s3_bucket_name = "nasdaq-equity-batch-pipeline-data-dev-YOUR-GITHUB-USERNAME"  # Make it unique

# Retry
terraform apply
```

#### Issue 2: Lambda Function Fails - "Unable to import module"

**Error**:
```
{
  "errorMessage": "Unable to import module 'lambda_function': No module named 'certifi'",
  "errorType": "Runtime.ImportModuleError"
}
```

**Solution**:
```bash
# Rebuild Lambda package with dependencies
cd cicd/scripts
./package-lambda.sh

# Redeploy
aws lambda update-function-code \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --zip-file fileb://../../build/lambda/lambda-function.zip \
    --region us-east-1
```

#### Issue 3: Glue Job Fails - "S3 path does not exist"

**Error** (in Glue logs):
```
AnalysisException: Path does not exist: s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date=2026-01-20/
```

**Solution**:
```bash
# Check if Lambda successfully wrote data
aws s3 ls s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/ --recursive --region us-east-1

# If empty, manually trigger Lambda
aws lambda invoke \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --payload '{}' \
    --region us-east-1 \
    /tmp/lambda-response.json

# Then retry Glue job
```

#### Issue 4: API Rate Limit Exceeded

**Error** (in Lambda logs):
```
HTTP Error 429: Too Many Requests
```

**Solution**:
```bash
# Increase rate limit delay
# Edit lambda/stock_extractor/config.py
RATE_LIMIT_DELAY = 2  # Increase from 1 to 2 seconds

# Redeploy Lambda
# Or upgrade to FMP paid tier (higher limits)
```

#### Issue 5: AWS Academy Credentials Expired

**Error**:
```
An error occurred (ExpiredToken) when calling the GetFunction operation: The security token included in the request is expired
```

**Solution**:
```bash
# Re-authenticate with AWS Academy
# 1. Go to AWS Academy Learner Lab
# 2. Click "AWS Details"
# 3. Copy new credentials
# 4. Reconfigure AWS CLI

aws configure set aws_access_key_id NEW_ACCESS_KEY
aws configure set aws_secret_access_key NEW_SECRET_KEY
aws configure set aws_session_token NEW_SESSION_TOKEN

# Retry command
```

#### Issue 6: Glue Job Stuck in "RUNNING" State

**Symptoms**: Glue job runs for > 30 minutes, never completes

**Solution**:
```bash
# Stop the job
aws glue batch-stop-job-run \
    --job-name build-stock-dimensions-dev \
    --job-run-ids JOB_RUN_ID \
    --region us-east-1

# Check CloudWatch logs for errors
aws logs tail /aws/glue/jobs/build-stock-dimensions-dev --follow --region us-east-1

# Common causes:
# - Insufficient Glue DPUs (increase num_workers)
# - Data skew (optimize partitioning)
# - Memory issues (upgrade to G.2X worker type)
```

### Debug Commands

**View Lambda Logs**:
```bash
aws logs tail /aws/lambda/nasdaq-equity-batch-pipeline-extractor-dev --follow --region us-east-1
```

**View Glue Job Logs**:
```bash
aws logs tail /aws/glue/jobs/build-stock-dimensions-dev --follow --region us-east-1
```

**View Step Functions Execution**:
```bash
aws stepfunctions get-execution-history \
    --execution-arn EXECUTION_ARN \
    --region us-east-1 \
    --max-results 100 \
    | jq '.events[] | select(.type | contains("Failed"))'
```

**Check S3 Data**:
```bash
# List all data
aws s3 ls s3://nasdaq-equity-batch-pipeline-data-dev-username/ --recursive --human-readable --region us-east-1

# Download sample file
aws s3 cp s3://nasdaq-equity-batch-pipeline-data-dev-username/raw/stock_quotes/date=2026-01-20/stocks_20260121_023023.json - | jq '.'
```

---

## 🎉 Post-Deployment

### 1. Confirm SNS Subscription

```bash
# Check email for subscription confirmation
# Subject: "AWS Notification - Subscription Confirmation"
# Click "Confirm subscription" link

# Verify subscription
aws sns list-subscriptions-by-topic \
    --topic-arn $(terraform output -raw sns_topic_arn) \
    --region us-east-1
```

### 2. Set Up Monitoring Dashboard

**Create CloudWatch Dashboard**:
```bash
# Navigate to CloudWatch console
echo "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:"

# Add widgets:
# - Lambda invocations (metric: Invocations)
# - Lambda errors (metric: Errors)
# - Glue job success rate (metric: JobSucceededCount)
# - Step Functions executions (metric: ExecutionsSucceeded)
```

### 3. Enable Cost Alerts

```bash
# Create budget alert
aws budgets create-budget \
    --account-id $(aws sts get-caller-identity --query Account --output text) \
    --budget '{
        "BudgetName": "nasdaq-pipeline-monthly",
        "BudgetLimit": {
            "Amount": "10",
            "Unit": "USD"
        },
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }' \
    --notifications-with-subscribers '[{
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80
        },
        "Subscribers": [{
            "SubscriptionType": "EMAIL",
            "Address": "your-email@example.com"
        }]
    }]'
```

### 4. Document Deployment

**Create runbook**:
```bash
cat > RUNBOOK.md << 'EOF'
# NASDAQ Pipeline Runbook

## Daily Operations
- Pipeline runs automatically at 10:30 AM SGT
- Check email for failure alerts
- Query latest data in Athena

## Weekly Tasks
- Review CloudWatch metrics
- Check S3 storage usage
- Verify data quality

## Monthly Tasks
- Review AWS costs
- Rotate API keys (if needed)
- Update stock symbol list

## Emergency Contacts
- Data Engineering: your-email@example.com
- AWS Support: [Account ID]
EOF
```

### 5. Optional: Set Up CI/CD

**Enable GitHub Integration**:
```bash
# 1. Create GitHub Personal Access Token
# GitHub → Settings → Developer Settings → Personal Access Tokens → Generate

# 2. Store token in Secrets Manager
aws secretsmanager create-secret \
    --name github/personal-access-token \
    --secret-string '{"token":"ghp_YOUR_TOKEN"}' \
    --region us-east-1

# 3. Enable CI/CD in terraform.tfvars
enable_cicd = true
github_repo = "yourusername/nasdaq-equity-batch-pipeline"
github_token_secret = "github/personal-access-token"

# 4. Apply Terraform
terraform apply

# 5. Push to trigger pipeline
git push origin main
```

---

## 📚 Next Steps

### Expand the Pipeline

1. **Add More Stocks**:
   - Update `stock_symbols` in terraform.tfvars
   - Add sector/industry enrichment

2. **Add Data Sources**:
   - News sentiment (NewsAPI)
   - Social media sentiment (Twitter API)
   - Economic indicators (FRED API)

3. **Advanced Analytics**:
   - Implement RSI, MACD indicators
   - Build ML models for predictions
   - Create real-time dashboards

4. **Production Hardening**:
   - Add data quality checks
   - Implement SLA monitoring
   - Set up backup/disaster recovery
   - Enable multi-region deployment

### Learning Resources

- **AWS Glue**: https://docs.aws.amazon.com/glue/
- **Apache Iceberg**: https://iceberg.apache.org/docs/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **Financial Modeling Prep API**: https://financialmodelingprep.com/developer/docs/

---

## 🆘 Support

### Getting Help

1. **Check Documentation**:
   - [Architecture Guide](./architecture-detailed.md)
   - [Transformation Guide](./data-transformation-guide.md)
   - [Project Structure](./project-structure-reference.md)

2. **Review Logs**:
   - CloudWatch Logs for all services
   - Step Functions execution history
   - Terraform plan/apply output

3. **Community**:
   - GitHub Issues: [Create issue](https://github.com/yourusername/nasdaq-equity-batch-pipeline/issues)
   - AWS Forums: https://forums.aws.amazon.com/
   - Stack Overflow: Tag with `aws-glue`, `terraform`

---

**Deployment Guide Version**: 1.0  
**Last Updated**: January 21, 2026  
**Tested On**: AWS Academy, Personal AWS Accounts