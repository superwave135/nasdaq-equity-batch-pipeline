# 📊 NASDAQ Equity Batch Data Pipeline

> **Production-grade, event-driven data engineering pipeline for real-time stock market analytics on AWS**

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-purple?logo=terraform)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)](https://www.python.org/)
[![Apache Iceberg](https://img.shields.io/badge/Apache-Iceberg-00ADD8?logo=apache)](https://iceberg.apache.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🎯 Overview

This project implements an **automated, scalable data pipeline** that extracts real-time stock market data, transforms it into a **star schema data warehouse**, and provides analytics capabilities through AWS Athena. Built entirely on serverless AWS services and managed as Infrastructure as Code using Terraform.

**💡 Key Achievement**: Delivers production-ready data warehouse functionality at **$79/year** compared to **$4,056/year** for AWS MWAA - a **97% cost reduction** while maintaining enterprise-grade features.

### What Makes This Project Special

✨ **Production-Grade Architecture**  
- Fully automated end-to-end pipeline with zero manual intervention
- Event-driven design using AWS Step Functions and EventBridge
- Enterprise-level error handling with automatic retries and notifications

📊 **Professional Data Engineering**  
- Star schema data warehouse optimized for analytical queries
- Apache Iceberg tables with ACID transactions and time travel
- Derived metrics and pre-aggregated tables for fast analytics

💰 **Cost-Optimized Design**  
- Serverless architecture: pay only for what you use
- Strategic use of AWS Free Tier services
- 97% cost savings vs. managed orchestration (MWAA)

🔧 **Infrastructure as Code**  
- Complete Terraform modules for reproducible deployments
- Modular design supporting dev/staging/prod environments
- CI/CD pipeline with GitHub integration

---

## 🏗️ Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EVENT-DRIVEN SERVERLESS PIPELINE                 │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐       ┌───────────────────────────────────────────┐
│ EventBridge  │──────>│   Step Functions State Machine            │
│ (Scheduler)  │       │   ┌─────────────────────────────────────┐ │
│ Daily 10:30  │       │   │ 1. Lambda: Extract Stock Data       │ │
│ AM SGT       │       │   │    └─> FMP API → S3 Raw (JSON)      │ │
└──────────────┘       │   ├─────────────────────────────────────┤ │
                       │   │ 2. Glue: Build Dimension Tables     │ │
                       │   │    └─> dim_stock, dim_date, etc.    │ │
                       │   ├─────────────────────────────────────┤ │
                       │   │ 3. Glue: Build Fact Table           │ │
                       │   │    └─> fact_stock_daily_price       │ │
                       │   │        (24 metrics + derived calc)  │ │
                       │   ├─────────────────────────────────────┤ │
                       │   │ 4. Glue: Build Aggregations         │ │
                       │   │    └─> Weekly/Monthly/Sector views  │ │
                       │   └─────────────────────────────────────┘ │
                       └───────────────────────────────────────────┘
                                          │
                                          ▼
                       ┌───────────────────────────────────────────┐
                       │   S3 Data Lake (Apache Iceberg Format)    │
                       │   ├─ Raw Zone: JSON files                 │
                       │   └─ Warehouse: Star Schema (7 tables)    │
                       └───────────────────────────────────────────┘
                                          │
                                          ▼
                       ┌───────────────────────────────────────────┐
                       │   AWS Athena SQL Analytics                │
                       │   └─ Query data, generate insights        │
                       └───────────────────────────────────────────┘
                                          │
                                          ▼
                       ┌───────────────────────────────────────────┐
                       │   CloudWatch + SNS Monitoring             │
                       │   └─ Logs, metrics, email alerts          │
                       └───────────────────────────────────────────┘
```

### Star Schema Data Model

```
                 ┌──────────────┐
                 │  dim_stock   │
                 ├──────────────┤
                 │ stock_key PK │
                 │ symbol       │
                 │ company_name │
                 │ sector       │
                 │ industry     │
                 └──────┬───────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
    ┌────▼────┐   ┌─────▼──────┐  ┌───▼─────────┐
    │dim_date │   │    FACT    │  │dim_exchange │
    ├─────────┤   │stock_daily │  ├─────────────┤
    │date_key │◄──┤   _price   │──►│exchange_key│
    │calendar │   ├────────────┤  │exchange     │
    │year/qtr │   │ 24 metrics │  │timezone     │
    │month    │   │ • Prices   │  └─────────────┘
    │flags    │   │ • Volume   │
    └─────────┘   │ • Derived  │
                  └────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │  Aggregations   │
              ├─────────────────┤
              │ • Weekly        │
              │ • Monthly       │
              │ • Sector        │
              └─────────────────┘
```

---

## 🚀 Features

### Production-Ready Capabilities

#### 🔄 **Automated Data Pipeline**
- ✅ **Daily Scheduling**: Runs automatically at 10:30 AM Singapore Time (Set your own timezone)
- ✅ **Event-Driven**: EventBridge triggers Step Functions orchestration
- ✅ **Sequential Processing**: Lambda → Glue (Dimensions) → Glue (Facts) → Glue (Aggregations)
- ✅ **Error Handling**: Automatic retries with exponential backoff
- ✅ **Notifications**: Email alerts on failures via SNS

#### 📊 **Enterprise Data Warehouse**
- ✅ **Star Schema Design**: Optimized for analytical queries
- ✅ **Apache Iceberg Tables**: ACID transactions, time travel, schema evolution
- ✅ **7 Warehouse Tables**:
  - 3 Dimension tables (stock, date, exchange)
  - 1 Fact table (daily stock prices with 24 metrics)
  - 3 Aggregation tables (weekly, monthly, sector performance)
- ✅ **Derived Metrics**: Pre-calculated technical indicators and returns
- ✅ **Partitioning**: Efficient date-based partitioning for performance

#### 💻 **Data Engineering Best Practices**
- ✅ **Idempotent ETL**: Safe to re-run for any date
- ✅ **Incremental Loading**: Daily append, not full reload
- ✅ **Referential Integrity**: Proper foreign key relationships
- ✅ **Data Quality**: Deduplication, validation, null handling
- ✅ **Date Synchronization**: All jobs process same trading day data

#### 🛠️ **Infrastructure as Code**
- ✅ **Terraform Modules**: Modular, reusable infrastructure
- ✅ **Environment Isolation**: Separate dev/staging/prod configurations
- ✅ **Version Control**: Full Git history of infrastructure changes
- ✅ **Reproducible**: Deploy identical environments in minutes

#### 🔍 **Monitoring & Observability**
- ✅ **CloudWatch Logs**: Comprehensive logging for all components
- ✅ **CloudWatch Metrics**: Lambda invocations, Glue job status, Step Functions executions
- ✅ **CloudWatch Alarms**: Automatic alerts on errors
- ✅ **SNS Notifications**: Email alerts for pipeline failures
- ✅ **Step Functions Visualization**: Visual execution graph with input/output

#### 🔐 **Security & Compliance**
- ✅ **Secrets Manager**: Secure API key storage (no hardcoded credentials)
- ✅ **IAM Roles**: Least privilege access for each service
- ✅ **S3 Encryption**: AES-256 server-side encryption
- ✅ **VPC Not Required**: Serverless services use AWS backbone
- ✅ **CloudTrail Ready**: Audit trail for all AWS API calls

---

## 📦 Technology Stack

### AWS Services

| Service | Purpose | Key Features |
|---------|---------|--------------|
| **Lambda** | Data extraction | Python 3.11, 512 MB, 5-min timeout |
| **S3** | Data lake storage | Versioning, encryption, lifecycle policies |
| **Glue** | ETL transformation | PySpark 3.3, Glue 4.0, 2 DPU workers |
| **Step Functions** | Orchestration | State machine with retry logic |
| **EventBridge** | Scheduling | Cron-based daily trigger |
| **Athena** | SQL analytics | Serverless query engine |
| **Secrets Manager** | Credentials | Encrypted API key storage |
| **CloudWatch** | Monitoring | Logs, metrics, alarms |
| **SNS** | Notifications | Email alerts |
| **CodeBuild** | CI/CD | Automated build and deploy |

### Open Source Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| **Python** | 3.11 | Lambda and local development |
| **PySpark** | 3.3 | Glue ETL transformations |
| **Apache Iceberg** | 1.x | Data lakehouse table format |
| **Terraform** | 1.5+ | Infrastructure provisioning |
| **Boto3** | 1.34+ | AWS SDK for Python |

### Data Source

- **Financial Modeling Prep (FMP) API**: Real-time stock quotes
  - Free tier: 250 API calls/day
  - Endpoint: `https://financialmodelingprep.com/stable/quote`
  - Stocks: AAPL, GOOGL, MSFT, AMZN, META

---

## 💰 Cost Breakdown

### Monthly Operating Costs

| Service | Usage | Cost/Month | Notes |
|---------|-------|------------|-------|
| **Lambda** | 30 invocations, 512 MB, 30s | $0.00 | Within Free Tier |
| **S3 Storage** | ~1 GB | $0.02 | Raw + warehouse data |
| **S3 Requests** | ~120/day | $0.01 | PUT + GET operations |
| **Glue ETL** | 3 jobs × 2 min × 2 DPU × 30 days | **$5.28** | Primary cost driver |
| **Glue Catalog** | 7 tables | $0.00 | < 1M objects (free) |
| **Athena** | ~100 queries, 10 GB scanned | $0.50 | $5 per TB scanned |
| **CloudWatch Logs** | ~500 MB/month | $0.25 | Ingestion + storage |
| **Step Functions** | 30 executions, 4 transitions | $0.03 | 4,000 free/month |
| **EventBridge** | 30 events/month | $0.00 | Free for scheduled events |
| **CodeBuild** | ~5 builds/month, 5 min each | $0.50 | build.general1.small |
| **SNS** | < 1,000 emails | $0.00 | Within Free Tier |
| **Secrets Manager** | 1 secret | $0.00 | First month free |
| **Total** | | **~$6.59/month** | **~$79/year** |

### Cost Comparison

| Solution | Monthly | Annual | vs This Pipeline |
|----------|---------|--------|------------------|
| **This Pipeline (Serverless)** | $6.59 | $79 | Baseline |
| **AWS MWAA (Managed Airflow)** | $338 | $4,056 | **-5,034% (51× more)** |
| **Self-Hosted Airflow (t3.medium)** | $38 | $456 | **-476% (5.8× more)** |

**💡 ROI Insight**: Serverless architecture provides enterprise functionality at 2% of managed Airflow cost!

---

## 🚀 Quick Start

### Prerequisites

- **AWS Account** (Free Tier eligible or personal account)
- **Terraform** >= 1.5.0
- **AWS CLI** >= 2.0
- **Python** >= 3.9
- **FMP API Key** (free signup at https://financialmodelingprep.com)

### 5-Step Deployment

#### 1. Clone Repository
```bash
git clone https://github.com/yourusername/nasdaq-equity-batch-pipeline.git
cd nasdaq-equity-batch-pipeline
```

#### 2. Configure AWS Credentials
```bash
aws configure
# Enter: Access Key, Secret Key, Region (us-east-1), Output (json)

# Verify
aws sts get-caller-identity
```

#### 3. Store API Key in Secrets Manager
```bash
aws secretsmanager create-secret \
    --name nasdaq-pipeline/fmp-api-key \
    --secret-string '{"api_key":"YOUR_FMP_API_KEY"}' \
    --region us-east-1
```

#### 4. Configure and Deploy Infrastructure
```bash
cd terraform

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Update: S3 bucket name, email, region

# Deploy (takes ~5-10 minutes)
terraform init
terraform plan
terraform apply
```

#### 5. Upload Code and Test
```bash
# Package and deploy Lambda
cd ../cicd/scripts
chmod +x package-lambda.sh
./package-lambda.sh

aws lambda update-function-code \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --zip-file fileb://../../build/lambda/lambda-function.zip \
    --region us-east-1

# Upload Glue scripts
aws s3 sync ../../glue/jobs/ s3://YOUR-BUCKET-NAME/glue-scripts/ \
    --region us-east-1

# Trigger test run
aws stepfunctions start-execution \
    --state-machine-arn $(cd ../../terraform && terraform output -raw step_functions_arn) \
    --region us-east-1
```

**🎉 Done!** Your pipeline will now run automatically daily at 10:30 AM Singapore Time. (Set your own timezone)

---

## 📊 Sample Analytics Queries

### Query Latest Stock Prices

```sql
-- Get today's stock performance
SELECT 
    ds.symbol,
    ds.company_name,
    f.close_price,
    f.daily_return_pct,
    f.volume_normalized,
    f.distance_from_50ma_pct
FROM nasdaq_warehouse_dev.fact_stock_daily_price f
JOIN nasdaq_warehouse_dev.dim_stock ds ON f.stock_key = ds.stock_key
WHERE f.date_key = CAST(date_format(current_date - interval '1' day, '%Y%m%d') AS INT)
ORDER BY f.daily_return_pct DESC;
```

**Output**:
| symbol | company_name | close_price | daily_return_pct | volume_normalized | distance_from_50ma_pct |
|--------|--------------|-------------|------------------|-------------------|------------------------|
| META | Meta Platforms | 604.12 | -2.60 | 15.06 | -5.50 |
| GOOGL | Alphabet Inc. | 322.00 | -2.42 | 35.09 | 4.08 |

### Technical Analysis Signals

```sql
-- Identify bullish/bearish trends
SELECT 
    ds.symbol,
    f.close_price,
    f.price_avg_50,
    f.price_avg_200,
    CASE 
        WHEN f.close_price > f.price_avg_50 
         AND f.price_avg_50 > f.price_avg_200 THEN 'Strong Bullish'
        WHEN f.close_price > f.price_avg_50 THEN 'Bullish'
        WHEN f.close_price < f.price_avg_50 
         AND f.price_avg_50 < f.price_avg_200 THEN 'Strong Bearish'
        ELSE 'Bearish'
    END as trend_signal
FROM nasdaq_warehouse_dev.fact_stock_daily_price f
JOIN nasdaq_warehouse_dev.dim_stock ds ON f.stock_key = ds.stock_key
WHERE f.date_key = CAST(date_format(current_date - interval '1' day, '%Y%m%d') AS INT);
```

### Monthly Performance Summary

```sql
-- Use pre-aggregated table for fast queries
SELECT 
    symbol,
    month_key,
    avg_price,
    monthly_return_pct,
    volatility,
    trading_days
FROM nasdaq_warehouse_dev.agg_monthly_performance
WHERE year = 2026 AND month = 1
ORDER BY monthly_return_pct DESC;
```

### Time Travel Query (Iceberg Feature)

```sql
-- Query data as of a specific date
SELECT * 
FROM nasdaq_warehouse_dev.fact_stock_daily_price
FOR SYSTEM_TIME AS OF TIMESTAMP '2026-01-15 00:00:00'
WHERE symbol = 'AAPL';
```

---

## 📁 Project Structure

```
nasdaq-equity-batch-pipeline/
│
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # Root module
│   ├── variables.tf           # Input variables
│   ├── modules/               # Reusable modules
│   │   ├── lambda/            # Lambda function
│   │   ├── s3/                # Data lake bucket
│   │   ├── glue/              # Glue jobs & database
│   │   ├── step-functions/    # Orchestration
│   │   ├── eventbridge/       # Scheduling
│   │   ├── cloudwatch/        # Monitoring
│   │   └── sns/               # Notifications
│   └── environments/          # Environment configs
│
├── lambda/                    # Lambda function code
│   └── stock_extractor/
│       ├── lambda_function.py # Main handler (259 lines)
│       ├── config.py          # Configuration
│       └── requirements.txt   # Dependencies
│
├── glue/                      # Glue ETL jobs
│   └── jobs/
│       ├── build_stock_dimensions.py      # Dimension builder (174 lines)
│       ├── build_stock_fact_table.py      # Fact table builder (267 lines)
│       └── build_stock_aggregations.py    # Aggregation builder (180 lines)
│
├── cicd/                      # CI/CD pipeline
│   ├── buildspec-ci.yml       # Continuous Integration
│   ├── buildspec-cd.yml       # Continuous Deployment
│   └── scripts/
│       ├── package-lambda.sh  # Lambda packaging
│       ├── deploy.sh          # Deployment automation
│       └── test-pipeline.sh   # Integration tests
│
├── docs/                      # Documentation
│   ├── architecture-detailed.md           # Architecture guide
│   ├── data-transformation-guide.md       # ETL documentation
│   ├── DEPLOYMENT_GUIDE.md                # Deployment instructions
│   └── project-structure-reference.md     # Code organization
│
└── README.md                  # This file
```

**See**: [Project Structure Reference](docs/project-structure-reference.md) for detailed file descriptions

---

## 📚 Documentation

| Document | Description | Audience |
|----------|-------------|----------|
| [Architecture Guide](docs/architecture-detailed.md) | Complete system architecture, components, data flow | Architects, Engineers |
| [Data Transformation Guide](docs/data-transformation-guide.md) | ETL processes, star schema, transformations | Data Engineers, Analysts |
| [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) | Step-by-step setup and deployment | DevOps, New Users |
| [Project Structure](docs/project-structure-reference.md) | Codebase organization, file descriptions | Developers, Contributors |

---

## 🐛 Troubleshooting

### Common Issues

#### Pipeline Fails at Lambda Step

**Error**: "Unable to retrieve API key from Secrets Manager"

**Solution**:
```bash
# Verify secret exists
aws secretsmanager get-secret-value \
    --secret-id nasdaq-pipeline/fmp-api-key \
    --region us-east-1

# If missing, create it
aws secretsmanager create-secret \
    --name nasdaq-pipeline/fmp-api-key \
    --secret-string '{"api_key":"YOUR_KEY"}' \
    --region us-east-1
```

#### Glue Job Fails: "Path does not exist"

**Error**: `S3 path does not exist: s3://bucket/raw/stock_quotes/date=2026-01-20/`

**Solution**:
```bash
# Check if Lambda wrote data
aws s3 ls s3://YOUR-BUCKET/raw/stock_quotes/ --recursive

# If empty, manually invoke Lambda
aws lambda invoke \
    --function-name nasdaq-equity-batch-pipeline-extractor-dev \
    --payload '{}' \
    --region us-east-1 \
    /tmp/response.json
```

#### No Data in Athena

**Symptom**: Query returns 0 rows

**Solution**:
```bash
# Check if tables exist
aws glue get-tables --database-name nasdaq_warehouse_dev --region us-east-1

# Verify Step Functions execution
aws stepfunctions list-executions \
    --state-machine-arn YOUR_STATE_MACHINE_ARN \
    --region us-east-1 \
    --max-results 5

# Check CloudWatch logs
aws logs tail /aws/glue/jobs/build-stock-dimensions-dev --follow
```

**See**: [Deployment Guide - Troubleshooting](docs/DEPLOYMENT_GUIDE.md#troubleshooting) for more solutions

---

## 🎓 Learning Resources

### AWS Documentation
- [AWS Glue](https://docs.aws.amazon.com/glue/) - ETL service documentation
- [AWS Step Functions](https://docs.aws.amazon.com/step-functions/) - Orchestration guide
- [Apache Iceberg](https://iceberg.apache.org/docs/) - Table format specification
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/) - IaC reference

### Data Engineering Concepts
- **Star Schema Design**: Kimball's "The Data Warehouse Toolkit"
- **Serverless Architectures**: AWS Well-Architected Framework
- **ETL Best Practices**: Idempotency, incremental loading, data quality

### Financial Data Analysis
- **Technical Indicators**: Moving averages, RSI, MACD
- **Risk Metrics**: Volatility, Sharpe ratio, drawdown
- **FMP API Docs**: https://financialmodelingprep.com/developer/docs/

---

## 🔄 Roadmap & Future Enhancements

### Phase 2: Advanced Analytics
- [ ] Add more technical indicators (RSI, MACD, Bollinger Bands)
- [ ] Implement ML models for price prediction
- [ ] Real-time streaming data (replace daily batch)
- [ ] Add options and derivatives data

### Phase 3: Data Enrichment
- [ ] News sentiment analysis integration
- [ ] Social media sentiment (Twitter/Reddit)
- [ ] Economic indicators (FRED API)
- [ ] Sector/industry classifications enrichment

### Phase 4: Visualization
- [ ] QuickSight dashboards
- [ ] Grafana integration for metrics
- [ ] Real-time price charts
- [ ] Portfolio performance tracking

### Phase 5: Production Hardening
- [ ] Multi-region deployment
- [ ] Disaster recovery procedures
- [ ] Data quality monitoring
- [ ] SLA monitoring and alerting
- [ ] Automated backups

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** following the coding standards
4. **Test thoroughly**: Run integration tests
5. **Commit**: `git commit -m 'Add amazing feature'`
6. **Push**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

**See**: [Project Structure](docs/project-structure-reference.md#development-guidelines) for coding standards

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **AWS** for providing comprehensive cloud services and excellent documentation
- **Apache Iceberg** for the modern table format that enables ACID transactions
- **Financial Modeling Prep** for the free stock market API
- **HashiCorp** for Terraform and excellent IaC tooling
- **Data Engineering Community** for best practices and guidance

---

## 📧 Contact & Support

### Author
**GeekyTan** - Data Engineering Portfolio Project

### Get Help
- **GitHub Issues**: [Create an issue](https://github.com/yourusername/nasdaq-equity-batch-pipeline/issues)
- **Documentation**: See [docs/](docs/) directory
- **AWS Forums**: https://forums.aws.amazon.com/

### Connect
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://linkedin.com/in/alvin-tan-8a569349/)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black?logo=github)](https://github.com/superwave135)

---

## ⭐ Show Your Support

If this project helped you learn about data engineering, AWS, or building production pipelines, please consider:

- ⭐ **Starring the repository**
- 🍴 **Forking for your own projects**
- 📢 **Sharing with others**
- 💬 **Providing feedback via issues**

---

**Built with ❤️ for the data engineering community**

**Last Updated**: January 22, 2026  
**Version**: 1.0.0  
**Status**: Production Ready ✅
