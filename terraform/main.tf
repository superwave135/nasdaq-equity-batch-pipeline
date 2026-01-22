# terraform/main.tf
# NASDAQ Equity Batch Pipeline - Complete Infrastructure with Orchestration
# Services: S3, Lambda, Glue, CloudWatch, SNS, CodeBuild + EventBridge & Step Functions

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Configure backend for state management
  # backend "s3" {
  #   bucket = "nasdaq-terraform-state"
  #   key    = "nasdaq-equity-batch-pipeline/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "nasdaq-equity-batch-pipeline"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ============================================================================
# DATA SOURCES (needed for Step Functions IAM)
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# S3 BUCKETS MODULE
# ============================================================================

module "s3" {
  source = "./modules/s3"

  bucket_name = var.s3_bucket_name
  environment = var.environment
}

# ============================================================================
# LAMBDA FUNCTIONS MODULE
# ============================================================================

module "lambda" {
  source = "./modules/lambda"

  s3_bucket     = module.s3.bucket_name
  environment   = var.environment
  sns_topic_arn = module.sns.topic_arn
  aws_region    = var.aws_region
}

# ============================================================================
# GLUE MODULE (Database, Jobs, IAM)
# ============================================================================

module "glue" {
  source = "./modules/glue"

  database_name = var.glue_database_name
  s3_bucket     = module.s3.bucket_name
  environment   = var.environment

  depends_on = [module.s3]
}

# ============================================================================
# SNS MODULE (Notifications)
# ============================================================================

module "sns" {
  source = "./modules/sns"

  environment = var.environment
  alert_email = var.alert_email
}

# ============================================================================
# CLOUDWATCH MODULE (Logging & Monitoring)
# ============================================================================

module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment            = var.environment
  aws_region             = var.aws_region
  lambda_function_name   = module.lambda.function_name
  glue_job_dimensions    = module.glue.job_names.dimensions
  glue_job_fact          = module.glue.job_names.fact_table
  glue_job_aggregations  = module.glue.job_names.aggregations
  sns_topic_arn          = module.sns.topic_arn
  log_retention_days     = var.log_retention_days

  depends_on = [module.lambda, module.glue, module.sns]
}

# ============================================================================
# CODEBUILD MODULE (CI/CD)
# ============================================================================

module "codebuild" {
  source = "./modules/codebuild"

  project_name         = "nasdaq-equity-batch-pipeline"
  environment          = var.environment
  aws_region           = var.aws_region
  
  # GitHub configuration
  github_repo_url      = var.github_repo_url
  github_branch        = var.github_branch
  
  # Deployment targets
  s3_bucket_name       = module.s3.bucket_name
  lambda_function_name = module.lambda.function_name
  
  # Optional features
  enable_glue_permissions = true
  enable_secrets_access   = false
  log_retention_days      = 7

  # Orchestration references (for CodeBuild environment)
  eventbridge_rule_name = var.enable_orchestration ? module.eventbridge[0].rule_name : ""
  state_machine_arn     = var.enable_orchestration ? module.step_functions[0].state_machine_arn : ""
  state_machine_name    = var.enable_orchestration ? module.step_functions[0].state_machine_name : ""

  depends_on = [module.lambda, module.glue, module.s3]
}

# ============================================================================
# GITHUB WEBHOOK MODULE
# ============================================================================

module "github_webhook" {
  source = "./modules/github-webhook"

  project_name              = "nasdaq-equity-batch-pipeline"
  github_token             = var.github_token
  codebuild_ci_project_name = module.codebuild.ci_project_name
  codebuild_cd_project_name = module.codebuild.cd_project_name
  
  trigger_branch_pattern = "refs/heads/main"
  trigger_on_pr         = false
  enable_cd_webhook     = false

  depends_on = [module.codebuild]
}

# ============================================================================
# STEP FUNCTIONS MODULE - Workflow Orchestration
# ============================================================================

module "step_functions" {
  source = "./modules/step-functions"
  
  # Only create if orchestration is enabled
  count = var.enable_orchestration ? 1 : 0
  
  project_name       = "nasdaq-equity-batch-pipeline"
  environment        = var.environment
  state_machine_name = "nasdaq-equity-batch-pipeline-orchestrator-${var.environment}"
  
  # Lambda configuration
  lambda_arn = module.lambda.function_arn
  
  # Glue job names - VERIFIED: Your code uses fact_table
  glue_job_dimensions   = module.glue.job_names.dimensions
  glue_job_fact         = module.glue.job_names.fact_table
  glue_job_aggregations = module.glue.job_names.aggregations
  
  # Retry and timeout configuration
  max_lambda_retries     = var.orchestration_lambda_retries
  max_glue_retries       = var.orchestration_glue_retries
  lambda_timeout_seconds = 300  # 5 minutes
  glue_timeout_minutes   = 60   # 60 minutes (matches your Glue job timeout)
  
  # Monitoring configuration
  enable_cloudwatch_logs = var.enable_orchestration_logging
  log_retention_days     = var.orchestration_log_retention_days
  
  tags = {
    Project     = "nasdaq-equity-batch-pipeline"
    Environment = var.environment
  }
  
  depends_on = [module.lambda, module.glue]
}

# ============================================================================
# EVENTBRIDGE MODULE - Scheduled Execution
# ============================================================================

module "eventbridge" {
  source = "./modules/eventbridge"
  
  # Only create if orchestration is enabled
  count = var.enable_orchestration ? 1 : 0
  
  project_name = "nasdaq-equity-batch-pipeline"
  environment  = var.environment
  rule_name    = "nasdaq-equity-batch-pipeline-daily-trigger-${var.environment}"
  
  # Schedule configuration
  schedule_expression = var.orchestration_schedule
  enabled             = var.orchestration_schedule_enabled
  
  # Target: Step Functions State Machine
  target_arn             = module.step_functions[0].state_machine_arn
  state_machine_role_arn = module.step_functions[0].execution_role_arn
  
  tags = {
    Project     = "nasdaq-equity-batch-pipeline"
    Environment = var.environment
  }
  
  depends_on = [module.step_functions]
}

# ============================================================================
# CLOUDWATCH ALARMS - Orchestration Monitoring
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "orchestration_pipeline_failures" {
  count = var.enable_orchestration && var.enable_orchestration_monitoring ? 1 : 0
  
  alarm_name          = "nasdaq-pipeline-orchestration-failures-${var.environment}"
  alarm_description   = "Alert when orchestrated pipeline execution fails"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300  # 5 minutes
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    StateMachineArn = module.step_functions[0].state_machine_arn
  }
  
  # Reuse existing SNS topic
  alarm_actions = [module.sns.topic_arn]
  
  tags = {
    Project     = "nasdaq-equity-batch-pipeline"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "orchestration_pipeline_duration" {
  count = var.enable_orchestration && var.enable_orchestration_monitoring ? 1 : 0
  
  alarm_name          = "nasdaq-pipeline-orchestration-duration-${var.environment}"
  alarm_description   = "Alert when orchestrated pipeline takes too long"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionTime"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Average"
  threshold           = var.orchestration_timeout_threshold_ms
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    StateMachineArn = module.step_functions[0].state_machine_arn
  }
  
  # Reuse existing SNS topic
  alarm_actions = [module.sns.topic_arn]
  
  tags = {
    Project     = "nasdaq-equity-batch-pipeline"
    Environment = var.environment
  }
}

# ============================================================================
# LOCAL VALUES - Using Template Directives
# ============================================================================

locals {
  # Using %{if} template directives instead of ternary with heredocs
  deployment_info = <<-EOT
  
  ========================================
  NASDAQ Equity Batch Pipeline Deployed!
  ========================================
  
  Environment: ${var.environment}
  Region: ${var.aws_region}
  
  Resources Created:
  - S3 Bucket: ${module.s3.bucket_name}
  - Lambda: ${module.lambda.function_name}
  - Glue Database: ${module.glue.database_name}
  - Glue Jobs: 3 (dimensions, fact_table, aggregations)
  - SNS Topic: ${module.sns.topic_arn}
  - CloudWatch Dashboard: ${module.cloudwatch.dashboard_name}
%{if var.enable_orchestration~}
  - Step Functions: ${module.step_functions[0].state_machine_name}
  - EventBridge Rule: ${module.eventbridge[0].rule_name} (${var.orchestration_schedule_enabled ? "ENABLED" : "DISABLED"})
%{endif~}
  
  Next Steps:
  1. Configure API key in Secrets Manager
%{if var.enable_orchestration~}
  2. Test orchestration: cd scripts && ./orchestrate_pipeline.sh trigger
  3. Enable schedule: ./orchestrate_pipeline.sh enable
  4. View CloudWatch dashboard for monitoring
  
  Orchestration Commands:
  cd scripts
  ./orchestrate_pipeline.sh check     # Check status
  ./orchestrate_pipeline.sh trigger   # Manual run
  ./orchestrate_pipeline.sh enable    # Enable daily schedule
  ./orchestrate_pipeline.sh logs      # View logs
  
  Console URLs:
  - Step Functions: https://${var.aws_region}.console.aws.amazon.com/states/home
  - EventBridge: https://${var.aws_region}.console.aws.amazon.com/events/home
%{else~}
  2. Use orchestration script to run pipeline
  3. View CloudWatch dashboard for monitoring
  
  Manual Trigger:
  ./scripts/run_pipeline.sh ${var.environment}
  
  To Enable Orchestration:
  1. Set enable_orchestration = true in terraform.tfvars
  2. Run: terraform apply
  3. Test: cd scripts && ./orchestrate_pipeline.sh trigger
%{endif~}
  
  ========================================
  EOT
}

# ============================================================================
# OUTPUTS
# ============================================================================

# CI/CD Outputs
output "codebuild_ci_project" {
  value       = module.codebuild.ci_project_name
  description = "CodeBuild CI project name"
}

output "codebuild_cd_project" {
  value       = module.codebuild.cd_project_name
  description = "CodeBuild CD project name"
}

output "codebuild_artifacts_bucket" {
  value       = module.codebuild.artifacts_bucket_name
  description = "S3 bucket for build artifacts"
}

# Core Infrastructure Outputs
output "s3_bucket_name" {
  value       = module.s3.bucket_name
  description = "S3 bucket for pipeline data"
}

output "lambda_function_name" {
  value       = module.lambda.function_name
  description = "Lambda function for stock extraction"
}

output "glue_database_name" {
  value       = module.glue.database_name
  description = "Glue catalog database"
}

output "glue_job_names" {
  value       = module.glue.job_names
  description = "Glue job names"
}

output "sns_topic_arn" {
  value       = module.sns.topic_arn
  description = "SNS topic for alerts"
}

output "cloudwatch_dashboard" {
  value       = module.cloudwatch.dashboard_name
  description = "CloudWatch dashboard name"
}

# Orchestration Outputs
output "orchestration_enabled" {
  value       = var.enable_orchestration
  description = "Whether orchestration is enabled"
}

output "state_machine_arn" {
  value       = var.enable_orchestration ? module.step_functions[0].state_machine_arn : null
  description = "ARN of the Step Functions state machine"
}

output "state_machine_name" {
  value       = var.enable_orchestration ? module.step_functions[0].state_machine_name : null
  description = "Name of the Step Functions state machine"
}

output "state_machine_console_url" {
  value       = var.enable_orchestration ? "https://${var.aws_region}.console.aws.amazon.com/states/home?region=${var.aws_region}#/statemachines/view/${module.step_functions[0].state_machine_arn}" : null
  description = "AWS Console URL for Step Functions state machine"
}

output "eventbridge_rule_name" {
  value       = var.enable_orchestration ? module.eventbridge[0].rule_name : null
  description = "Name of the EventBridge rule"
}

output "eventbridge_rule_arn" {
  value       = var.enable_orchestration ? module.eventbridge[0].rule_arn : null
  description = "ARN of the EventBridge rule"
}

output "orchestration_schedule" {
  value       = var.enable_orchestration ? var.orchestration_schedule : null
  description = "Cron expression for the pipeline schedule"
}

output "schedule_enabled" {
  value       = var.enable_orchestration ? var.orchestration_schedule_enabled : null
  description = "Whether the EventBridge schedule is enabled"
}

# Deployment info using template directives
output "deployment_info" {
  value       = local.deployment_info
  description = "Deployment information and next steps"
}