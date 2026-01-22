# CI/CD Pipeline - NASDAQ Stock Data Pipeline

> **Automated build, test, and deployment pipeline for the NASDAQ Stock Data Pipeline project**

[![AWS CodeBuild](https://img.shields.io/badge/AWS-CodeBuild-orange?logo=amazon-aws)](https://aws.amazon.com/codebuild/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple?logo=terraform)](https://www.terraform.io/)
[![GitHub](https://img.shields.io/badge/Source-GitHub-black?logo=github)](https://github.com)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Components](#components)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Usage](#usage)
- [CI/CD Workflow](#cicd-workflow)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

---

## 🎯 Overview

This CI/CD pipeline automates the build, test, and deployment process for the NASDAQ Stock Data Pipeline. It follows a **separated CI/CD architecture** where:

- **CI (Continuous Integration)**: Builds, tests, and packages application code
- **CD (Continuous Deployment)**: Deploys packaged artifacts to AWS infrastructure

### Key Features

✅ **Fully Separated CI/CD** - Independent execution and failure isolation  
✅ **Artifact-Based Deployment** - S3 acts as the interface between CI and CD  
✅ **Infrastructure as Code** - Entire pipeline managed by Terraform  
✅ **Cost Optimized** - Serverless architecture with minimal AWS costs  
✅ **Production Ready** - Enterprise-grade security and best practices  
✅ **Orchestration Visibility** - CD logs EventBridge and Step Functions status  

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TERRAFORM LAYER                          │
│   Manages Infrastructure (EventBridge, Step Functions)      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ manages
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 ORCHESTRATION LAYER                          │
│                                                              │
│  ┌──────────────┐              ┌─────────────────┐         │
│  │ EventBridge  │──triggers──→ │ Step Functions  │         │
│  │ (Schedule)   │              │ (Orchestrator)  │         │
│  └──────────────┘              └─────────────────┘         │
│                                        │                     │
│                                        │ coordinates         │
│                                        ↓                     │
│                          ┌──────────────────────┐           │
│                          │  Lambda + Glue Jobs  │           │
│                          └──────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
                            ↑
                            │ deploys code
                            │
┌─────────────────────────────────────────────────────────────┐
│                     CI/CD LAYER                              │
│                                                              │
│  ┌─────────────────┐           ┌─────────────────┐         │
│  │   CI PROJECT    │           │   CD PROJECT    │         │
│  │                 │           │                 │         │
│  │ • Build code    │           │ • Deploy Lambda │         │
│  │ • Run tests     │───S3─────→│ • Deploy Glue   │         │
│  │ • Package       │ artifacts │ • Log orch      │         │
│  └─────────────────┘           └─────────────────┘         │
│         ↑                              │                    │
└─────────┼──────────────────────────────┼────────────────────┘
          │                              │
          │                              │
┌─────────┼──────────────────────────────┼────────────────────┐
│         │      SOURCE CONTROL          │                    │
│  ┌──────┴──────────────────────────────┴──────┐           │
│  │          GitHub Repository                   │           │
│  │  (nasdaq-equity-batch-pipeline)              │           │
│  └──────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

### Separation of Concerns

| Layer | Responsibility | Managed By | Changes Via |
|-------|---------------|------------|-------------|
| **CI/CD** | Build & Deploy Code | CodeBuild | Git Push |
| **Orchestration** | Schedule & Coordinate | Terraform | `terraform apply` |
| **Application** | Process Data | Lambda/Glue | CD Deployment |

---

## 🧩 Components

### 1. CI Project (Continuous Integration)

**Name:** `nasdaq-equity-batch-pipeline-ci-dev`  
**Purpose:** Build, test, and package application code  
**Trigger:** GitHub webhook (automatic on push to `main` branch)  
**Buildspec:** `cicd/buildspec-ci.yml`

**Responsibilities:**
- Install dependencies
- Run code linting and validation
- Package Lambda function code into ZIP
- Copy Glue ETL scripts
- Upload artifacts to S3

**Environment Variables:**
```yaml
ENVIRONMENT:  dev
AWS_REGION:   us-east-1
S3_BUCKET:    nasdaq-equity-batch-pipeline-data-dev-username
```

**Artifacts Produced:**
```
s3://nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/
├── lambda/
│   └── lambda-function.zip
└── glue-scripts/
    ├── transform_dimensions.py
    ├── transform_fact.py
    └── transform_aggregations.py
```

---

### 2. CD Project (Continuous Deployment)

**Name:** `nasdaq-equity-batch-pipeline-cd-dev`  
**Purpose:** Deploy packaged code to AWS infrastructure  
**Trigger:** Manual (AWS CLI or Console)  
**Buildspec:** `cicd/buildspec-cd.yml`

**Responsibilities:**
- Download artifacts from S3
- Update Lambda function code
- Deploy Glue scripts to data bucket
- Log orchestration resource status (EventBridge, Step Functions)
- Verify deployment success

**Environment Variables:**
```yaml
ENVIRONMENT:           dev
AWS_REGION:            us-east-1
LAMBDA_FUNCTION_NAME:  nasdaq-equity-batch-pipeline-extractor-dev-username
S3_BUCKET:             nasdaq-equity-batch-pipeline-data-dev-username
EC2_INSTANCE_ID:       (optional - for Airflow)
EVENTBRIDGE_RULE_NAME: nasdaq-equity-batch-pipeline-daily-trigger-dev
STATE_MACHINE_ARN:     arn:aws:states:us-east-1:...:stateMachine:...
STATE_MACHINE_NAME:    nasdaq-equity-batch-pipeline-orchestrator-dev
```

**Deployment Targets:**
```
Lambda Function:
  └── nasdaq-equity-batch-pipeline-extractor-dev-username

S3 Bucket (Glue Scripts):
  └── s3://nasdaq-equity-batch-pipeline-data-dev-username/glue-scripts/

Orchestration (Read-Only Logging):
  ├── EventBridge Rule: nasdaq-equity-batch-pipeline-daily-trigger-dev
  └── Step Functions:   nasdaq-equity-batch-pipeline-orchestrator-dev
```

---

### 3. S3 Artifacts Bucket

**Name:** `nasdaq-equity-batch-pipeline-codebuild-artifacts-dev`  
**Purpose:** Interface between CI and CD (artifact storage)

**Features:**
- ✅ Versioning enabled (rollback capability)
- ✅ Server-side encryption (AES256)
- ✅ Lifecycle policy (30-day retention)
- ✅ Separate directories for CI artifacts and logs

**Structure:**
```
nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/
├── lambda/                    # Lambda deployment packages
│   └── lambda-function.zip
├── glue-scripts/              # Glue ETL scripts
│   ├── transform_dimensions.py
│   ├── transform_fact.py
│   └── transform_aggregations.py
├── airflow-dags/              # Airflow DAGs (if EC2 enabled)
├── build-logs/                # CI build logs
├── deploy-logs/               # CD deployment logs
└── cache/                     # Build cache for faster builds
```

---

### 4. GitHub Webhook Integration

**Configuration:**
```hcl
module "github_webhook" {
  enable_cd_webhook = false  # CD webhook disabled (manual deployment)
}
```

**Behavior:**
- **CI Webhook:** ✅ Enabled - Auto-triggers on push to `main`
- **CD Webhook:** ❌ Disabled - Manual deployment required

**Why CD is Manual:**
- Controlled deployment timing
- Production safety
- Approval gate before deployment
- Prevents accidental deployments

---

## 📋 Prerequisites

### Required Tools

- **AWS CLI** - Version 2.x or higher
  ```bash
  aws --version
  ```

- **Git** - For version control
  ```bash
  git --version
  ```

- **Terraform** - Version 1.5.0 or higher (for infrastructure management)
  ```bash
  terraform version
  ```

### AWS Configuration

1. **AWS Credentials**
   ```bash
   aws configure
   ```
   
   Required information:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region: `us-east-1`
   - Output format: `json`

2. **Required IAM Permissions**
   - `codebuild:StartBuild` (to trigger builds)
   - `codebuild:BatchGetBuilds` (to check build status)
   - `s3:GetObject` (to access artifacts)
   - `logs:GetLogEvents` (to view build logs)

### GitHub Access

- GitHub repository access (read/write)
- GitHub personal access token (for webhook setup)
- Branch: `main` (or your default branch)

---

## 🚀 Setup

### 1. Deploy Infrastructure with Terraform

```bash
# Navigate to Terraform directory
cd terraform/

# Initialize Terraform
terraform init

# Review infrastructure plan
terraform plan

# Deploy infrastructure
terraform apply

# Type 'yes' to confirm
```

**What This Creates:**
- ✅ CodeBuild CI project
- ✅ CodeBuild CD project
- ✅ S3 artifacts bucket
- ✅ IAM roles and policies
- ✅ CloudWatch log groups
- ✅ GitHub webhook (CI only)

### 2. Verify Deployment

```bash
# Check CI project
aws codebuild batch-get-projects \
  --names nasdaq-equity-batch-pipeline-ci-dev \
  --region us-east-1

# Check CD project
aws codebuild batch-get-projects \
  --names nasdaq-equity-batch-pipeline-cd-dev \
  --region us-east-1

# Check artifacts bucket
aws s3 ls s3://nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/
```

### 3. Test GitHub Webhook

```bash
# Make a small change and push
git add .
git commit -m "Test CI webhook"
git push origin main

# CI should automatically start building
```

---

## 💻 Usage

### Triggering CI (Automatic)

CI is **automatically triggered** when you push to the `main` branch:

```bash
# Make your code changes
vim lambda/lambda_function.py

# Commit and push
git add .
git commit -m "feat: Add new stock ticker"
git push origin main

# CI will automatically start
# Monitor at: https://console.aws.amazon.com/codesuite/codebuild/
```

### Triggering CD (Manual)

CD requires **manual triggering** for controlled deployments:

#### Method 1: AWS CLI (Recommended)

```bash
# Basic deployment
aws codebuild start-build \
  --project-name nasdaq-equity-batch-pipeline-cd-dev \
  --region us-east-1

# Get build ID and monitor
BUILD_ID=$(aws codebuild start-build \
  --project-name nasdaq-equity-batch-pipeline-cd-dev \
  --region us-east-1 \
  --query 'build.id' \
  --output text)

echo "Build ID: $BUILD_ID"

# Check build status
aws codebuild batch-get-builds \
  --ids $BUILD_ID \
  --region us-east-1 \
  --query 'builds[0].buildStatus' \
  --output text
```

#### Method 2: AWS Console

1. Navigate to AWS Console → CodeBuild
2. Find `nasdaq-equity-batch-pipeline-cd-dev`
3. Click **"Start build"**
4. Monitor progress in real-time

#### Method 3: Deployment Script (Recommended)

Create `scripts/deploy.sh`:

```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME="nasdaq-equity-batch-pipeline"
REGION="us-east-1"

echo "🚀 Starting CD deployment for $ENVIRONMENT..."

BUILD_ID=$(aws codebuild start-build \
  --project-name ${PROJECT_NAME}-cd-${ENVIRONMENT} \
  --region ${REGION} \
  --query 'build.id' \
  --output text)

echo "✅ Build started: $BUILD_ID"
echo "📊 Monitor at: https://console.aws.amazon.com/codesuite/codebuild/projects/${PROJECT_NAME}-cd-${ENVIRONMENT}/build/${BUILD_ID}"

# Optional: Wait for completion
echo "⏳ Waiting for build to complete..."
aws codebuild wait build-complete \
  --ids $BUILD_ID \
  --region ${REGION}

STATUS=$(aws codebuild batch-get-builds \
  --ids $BUILD_ID \
  --region ${REGION} \
  --query 'builds[0].buildStatus' \
  --output text)

echo "🎉 Deployment status: $STATUS"
```

Usage:
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh dev
```

---

## 🔄 CI/CD Workflow

### Complete Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: DEVELOPER WORKFLOW                                  │
└─────────────────────────────────────────────────────────────┘

Developer:
  1. Makes code changes (Lambda, Glue scripts)
  2. git add .
  3. git commit -m "feat: New feature"
  4. git push origin main
  
     ↓

┌─────────────────────────────────────────────────────────────┐
│ STEP 2: CONTINUOUS INTEGRATION (Automatic)                  │
└─────────────────────────────────────────────────────────────┘

GitHub Webhook → Triggers CI Project

CI Process (buildspec-ci.yml):
  ┌─────────────────────────────────────────┐
  │ install:                                │
  │   - Install Python dependencies         │
  │   - Install AWS CLI                     │
  └─────────────────────────────────────────┘
              ↓
  ┌─────────────────────────────────────────┐
  │ pre_build:                              │
  │   - Lint Python code (flake8)           │
  │   - Validate JSON/YAML files            │
  │   - Run unit tests                      │
  └─────────────────────────────────────────┘
              ↓
  ┌─────────────────────────────────────────┐
  │ build:                                  │
  │   - Package Lambda function → ZIP       │
  │   - Copy Glue scripts                   │
  │   - Prepare artifacts                   │
  └─────────────────────────────────────────┘
              ↓
  ┌─────────────────────────────────────────┐
  │ post_build:                             │
  │   - Upload to S3 artifacts bucket       │
  │   - Generate build report               │
  │   - Send notifications (if configured)  │
  └─────────────────────────────────────────┘

Result: ✅ Artifacts ready in S3
         ❌ Build failed (fix and retry)

     ↓

┌─────────────────────────────────────────────────────────────┐
│ STEP 3: CONTINUOUS DEPLOYMENT (Manual Trigger)              │
└─────────────────────────────────────────────────────────────┘

Developer/DevOps:
  aws codebuild start-build \
    --project-name nasdaq-equity-batch-pipeline-cd-dev \
    --region us-east-1

CD Process (buildspec-cd.yml):
  ┌─────────────────────────────────────────┐
  │ install:                                │
  │   - Install AWS CLI                     │
  └─────────────────────────────────────────┘
              ↓
  ┌─────────────────────────────────────────┐
  │ pre_build:                              │
  │   - Display environment config          │
  │   - Verify AWS credentials              │
  │   - Check deployment targets            │
  └─────────────────────────────────────────┘
              ↓
  ┌─────────────────────────────────────────┐
  │ build:                                  │
  │   - Download artifacts from S3          │
  │   - Update Lambda function code         │
  │   - Deploy Glue scripts to S3           │
  │   - Log orchestration status            │
  │     • EventBridge rule details          │
  │     • Step Functions details            │
  └─────────────────────────────────────────┘
              ↓
  ┌─────────────────────────────────────────┐
  │ post_build:                             │
  │   - Verify Lambda deployment            │
  │   - Display deployment summary          │
  │   - Log orchestration resources         │
  └─────────────────────────────────────────┘

Result: ✅ Deployment successful
         ❌ Deployment failed (rollback or retry)

     ↓

┌─────────────────────────────────────────────────────────────┐
│ STEP 4: RUNTIME EXECUTION (Independent from CI/CD)          │
└─────────────────────────────────────────────────────────────┘

EventBridge (Daily at 10:30 AM SGT):
  → Triggers Step Functions
    → Executes Lambda (extract stock data)
    → Executes Glue Jobs (transform data)
    → Stores results in S3
```

### Key Points

✅ **CI and CD are independent** - Can run separately  
✅ **S3 acts as interface** - Decouples CI from CD  
✅ **Orchestration is separate** - Managed by Terraform, not CI/CD  
✅ **CD is manual** - Controlled deployment timing  
✅ **No automatic cascade** - CI doesn't auto-trigger CD  

---

## 📦 Deployment

### Standard Deployment Process

#### Full Deployment (Recommended)

```bash
# Step 1: Push code changes (triggers CI)
git push origin main

# Step 2: Wait for CI to complete
# Monitor: https://console.aws.amazon.com/codesuite/codebuild/

# Step 3: Verify CI succeeded
aws codebuild batch-get-builds \
  --ids <BUILD_ID> \
  --region us-east-1

# Step 4: Trigger CD (manual)
aws codebuild start-build \
  --project-name nasdaq-equity-batch-pipeline-cd-dev \
  --region us-east-1

# Step 5: Verify deployment
aws lambda get-function \
  --function-name nasdaq-equity-batch-pipeline-extractor-dev-username \
  --region us-east-1 \
  --query 'Configuration.LastModified'
```

### Rollback Deployment

If you need to rollback to a previous version:

```bash
# Step 1: Find the artifact version you want
aws s3 ls s3://nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/lambda/ \
  --recursive

# Step 2: Download specific version (if versioning enabled)
aws s3api list-object-versions \
  --bucket nasdaq-equity-batch-pipeline-codebuild-artifacts-dev \
  --prefix lambda/lambda-function.zip

# Step 3: Restore specific version
aws s3api copy-object \
  --bucket nasdaq-equity-batch-pipeline-codebuild-artifacts-dev \
  --copy-source nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/lambda/lambda-function.zip?versionId=VERSION_ID \
  --key lambda/lambda-function.zip

# Step 4: Trigger CD to deploy old artifact
aws codebuild start-build \
  --project-name nasdaq-equity-batch-pipeline-cd-dev \
  --region us-east-1
```

### Hotfix Deployment

For urgent fixes:

```bash
# Step 1: Create hotfix branch
git checkout -b hotfix/urgent-fix

# Step 2: Make fix and commit
git add .
git commit -m "hotfix: Critical bug fix"

# Step 3: Push to main (triggers CI)
git checkout main
git merge hotfix/urgent-fix
git push origin main

# Step 4: Immediately trigger CD after CI completes
./scripts/deploy.sh dev
```

---

## 📊 Monitoring

### Viewing Build Logs

#### CI Logs

```bash
# Get latest CI build ID
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name nasdaq-equity-batch-pipeline-ci-dev \
  --region us-east-1 \
  --max-items 1 \
  --query 'ids[0]' \
  --output text)

# View build logs
aws logs tail /aws/codebuild/nasdaq-equity-batch-pipeline-ci-dev \
  --since 1h \
  --follow
```

#### CD Logs

```bash
# View CD deployment logs
aws logs tail /aws/codebuild/nasdaq-equity-batch-pipeline-cd-dev \
  --since 1h \
  --follow
```

### Build Status

```bash
# Check CI build status
aws codebuild batch-get-builds \
  --ids $BUILD_ID \
  --region us-east-1 \
  --query 'builds[0].[buildStatus,startTime,endTime]' \
  --output table

# List recent builds
aws codebuild list-builds-for-project \
  --project-name nasdaq-equity-batch-pipeline-ci-dev \
  --region us-east-1 \
  --max-items 10
```

### CloudWatch Dashboards

Access CloudWatch to view:
- Build success/failure rates
- Build duration trends
- Deployment frequency
- Error patterns

Navigate to: AWS Console → CloudWatch → Dashboards

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: CI Build Fails

**Symptom:** CI build fails during `pre_build` or `build` phase

**Possible Causes:**
- Linting errors (flake8)
- Missing dependencies
- Syntax errors in code
- Invalid JSON/YAML files

**Solution:**
```bash
# Check build logs
aws logs tail /aws/codebuild/nasdaq-equity-batch-pipeline-ci-dev --since 1h

# Run linting locally
flake8 lambda/ glue/

# Test locally before pushing
python -m pytest tests/
```

---

#### Issue 2: CD Deployment Fails

**Symptom:** CD fails to update Lambda or Glue scripts

**Possible Causes:**
- Artifacts not found in S3
- Lambda function doesn't exist
- IAM permission issues
- S3 bucket doesn't exist

**Solution:**
```bash
# Verify artifacts exist
aws s3 ls s3://nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/lambda/

# Check Lambda function exists
aws lambda get-function \
  --function-name nasdaq-equity-batch-pipeline-extractor-dev-username \
  --region us-east-1

# Verify IAM permissions
aws codebuild batch-get-projects \
  --names nasdaq-equity-batch-pipeline-cd-dev \
  --query 'projects[0].serviceRole'
```

---

#### Issue 3: S3 Artifacts Not Found

**Symptom:** CD can't find Lambda package or Glue scripts

**Possible Causes:**
- CI didn't complete successfully
- S3 upload failed
- Wrong bucket name
- Lifecycle policy deleted artifacts

**Solution:**
```bash
# Check if artifacts exist
aws s3 ls s3://nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/ --recursive

# Check CI build completed successfully
aws codebuild list-builds-for-project \
  --project-name nasdaq-equity-batch-pipeline-ci-dev \
  --region us-east-1 \
  --max-items 1

# Manually upload if needed (temporary fix)
aws s3 cp lambda-function.zip \
  s3://nasdaq-equity-batch-pipeline-codebuild-artifacts-dev/lambda/
```

---

#### Issue 4: GitHub Webhook Not Triggering CI

**Symptom:** Pushing to GitHub doesn't trigger CI build

**Possible Causes:**
- Webhook not configured
- GitHub token expired
- Wrong branch pattern
- CodeBuild project doesn't exist

**Solution:**
```bash
# Check webhook configuration
cd terraform/
terraform show | grep enable_cd_webhook

# Verify CodeBuild project exists
aws codebuild list-projects --region us-east-1

# Re-apply Terraform to fix webhook
terraform apply -auto-approve

# Test webhook manually
aws codebuild start-build \
  --project-name nasdaq-equity-batch-pipeline-ci-dev \
  --region us-east-1
```

---

#### Issue 5: Build Timeout

**Symptom:** Build exceeds timeout limit

**Possible Causes:**
- Large Lambda package
- Slow dependency installation
- Network issues
- Timeout too short

**Solution:**
```bash
# Check current timeout
aws codebuild batch-get-projects \
  --names nasdaq-equity-batch-pipeline-ci-dev \
  --query 'projects[0].timeoutInMinutes'

# Increase timeout in Terraform (if needed)
# Edit: terraform/modules/codebuild/variables.tf
# build_timeout = 30  # Increase from default

# Apply change
cd terraform/
terraform apply
```

---

#### Issue 6: Orchestration Logging Errors

**Symptom:** CD logs show errors describing EventBridge or Step Functions

**Possible Causes:**
- Resources don't exist (orchestration not deployed)
- IAM permissions missing (read-only)
- Wrong resource names

**Solution:**
```bash
# Verify EventBridge rule exists
aws events describe-rule \
  --name nasdaq-equity-batch-pipeline-daily-trigger-dev \
  --region us-east-1

# Verify Step Functions exists
aws stepfunctions list-state-machines \
  --region us-east-1

# This is informational only - errors won't block deployment
# To disable logging, remove from buildspec-cd.yml
```

---

### Debug Mode

Enable debug mode for more verbose logging:

```bash
# Set debug environment variable
aws codebuild start-build \
  --project-name nasdaq-equity-batch-pipeline-cd-dev \
  --region us-east-1 \
  --environment-variables-override \
    name=DEBUG,value=true,type=PLAINTEXT
```

---

## 🎓 Advanced Topics

### Enabling Automatic CD Deployment

To enable automatic CD deployment after CI completes:

#### Option 1: Enable GitHub Webhook for CD

```hcl
# Edit: terraform/main.tf
module "github_webhook" {
  # ...
  enable_cd_webhook = true  # ← Change from false
}
```

Apply change:
```bash
cd terraform/
terraform apply
```

**Result:** Git push → Auto CI → Auto CD

**⚠️ Warning:** Not recommended for production (less control)

---

#### Option 2: CI Triggers CD (Recommended)

Add to `cicd/buildspec-ci.yml` post_build phase:

```yaml
post_build:
  commands:
    # ... existing commands ...
    
    # ✅ NEW: Trigger CD after successful CI
    - echo "Triggering CD deployment..."
    - |
      aws codebuild start-build \
        --project-name nasdaq-equity-batch-pipeline-cd-${ENVIRONMENT} \
        --region ${AWS_REGION}
```

Update IAM permissions:

```hcl
# Add to: terraform/modules/codebuild/iam.tf

resource "aws_iam_role_policy" "codebuild_trigger_cd" {
  name = "codebuild-trigger-cd-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild"
        ]
        Resource = "arn:aws:codebuild:${var.aws_region}:*:project/${var.project_name}-cd-*"
      }
    ]
  })
}
```

Apply:
```bash
cd terraform/
terraform apply
```

**Result:** CI success → Auto triggers CD

**✅ Recommended:** Safer than webhook, deploys only after tests pass

---

### Multi-Environment Deployments

Deploy to different environments (dev, staging, prod):

```bash
# Deploy to dev
./scripts/deploy.sh dev

# Deploy to staging
./scripts/deploy.sh staging

# Deploy to production
./scripts/deploy.sh prod
```

Create environment-specific projects in Terraform:

```hcl
# For each environment
module "codebuild_dev" {
  source = "./modules/codebuild"
  environment = "dev"
  # ...
}

module "codebuild_staging" {
  source = "./modules/codebuild"
  environment = "staging"
  # ...
}

module "codebuild_prod" {
  source = "./modules/codebuild"
  environment = "prod"
  enable_cd_webhook = false  # Always manual for prod
  # ...
}
```

---

### Integration with External CI/CD Tools

#### GitHub Actions Integration

`.github/workflows/deploy.yml`:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Trigger CodeBuild CI
        run: |
          aws codebuild start-build \
            --project-name nasdaq-equity-batch-pipeline-ci-dev \
            --region us-east-1
      
      - name: Wait for CI to complete
        run: |
          # Add waiting logic here
      
      - name: Trigger CodeBuild CD
        run: |
          aws codebuild start-build \
            --project-name nasdaq-equity-batch-pipeline-cd-dev \
            --region us-east-1
```

---

### Notifications and Alerts

#### SNS Integration

Add SNS notifications for build status:

```hcl
# Add to: terraform/main.tf

resource "aws_sns_topic" "build_notifications" {
  name = "codebuild-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.build_notifications.arn
  protocol  = "email"
  endpoint  = "team@example.com"
}

# Add notification configuration to CodeBuild projects
# (requires additional Terraform configuration)
```

#### Slack Integration

Use AWS Chatbot or Lambda to send notifications to Slack:

```bash
# Install AWS Chatbot or create Lambda function
# Configure SNS → Lambda → Slack webhook
```

---

### Cost Optimization

#### Current Costs (Estimated)

| Resource | Monthly Cost |
|----------|--------------|
| CodeBuild (CI) | ~$2-5 (based on build frequency) |
| CodeBuild (CD) | ~$1-2 (manual deployments) |
| S3 Storage | ~$0.50 (with lifecycle) |
| CloudWatch Logs | ~$0.50 (7-day retention) |
| **Total** | **~$4-8/month** |

**vs AWS MWAA:** $306/month (79x cheaper!)

#### Optimization Tips

1. **Reduce build frequency** (use branch filtering)
2. **Enable S3 cache** (speeds up builds, reduces time)
3. **Use lifecycle policies** (auto-delete old artifacts)
4. **Reduce log retention** (7 days is sufficient for dev)
5. **Use smaller build images** (faster, cheaper)

---

## 📚 Additional Resources

### Documentation

- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks)

### Project Documentation

- [Main README](../README.md) - Project overview
- [Architecture Guide](../docs/ARCHITECTURE.md) - System architecture
- [Terraform Guide](../terraform/README.md) - Infrastructure setup
- [Deployment Guide](../docs/DEPLOYMENT.md) - Deployment procedures

### Support

- **Issues:** Create a GitHub issue
- **Questions:** Contact the DevOps team
- **Terraform Errors:** Check Terraform state and logs

---

## 🤝 Contributing

### CI/CD Pipeline Changes

When modifying the CI/CD pipeline:

1. **Test in dev environment first**
   ```bash
   cd terraform/
   terraform workspace select dev
   terraform apply
   ```

2. **Update documentation** (this README)

3. **Test both CI and CD** manually

4. **Submit pull request** with changes

5. **Get review** from DevOps team

### Buildspec Changes

- **CI changes:** Test with `aws codebuild start-build`
- **CD changes:** Test deployment to dev environment
- **Always backup** current working buildspec

---

## 📄 License

This CI/CD pipeline is part of the NASDAQ Stock Data Pipeline project.

---

## 📞 Contact

- **Project Owner:** geekytan
- **DevOps Team:** [Contact Info]
- **GitHub:** [Repository URL]

---

**Last Updated:** January 22, 2026  
**Version:** 1.0.0  
**Status:** ✅ Production Ready
