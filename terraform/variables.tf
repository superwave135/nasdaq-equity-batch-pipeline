# terraform/variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
}

variable "glue_database_name" {
  description = "Glue catalog database name"
  type        = string
  default     = "nasdaq-equity-batch-pipeline-warehouse"
}

variable "alert_email" {
  description = "Email for SNS alerts"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# ============================================================================
# GITHUB CI/CD CONFIGURATION
# ============================================================================

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub personal access token for webhook"
  type        = string
  sensitive   = true
}

variable "ec2_instance_id" {
  description = "EC2 instance ID for Airflow (future)"
  type        = string
  default     = ""
}

# ============================================================================
# ORCHESTRATION CONFIGURATION (EventBridge + Step Functions)
# ============================================================================

variable "enable_orchestration" {
  description = "Enable EventBridge + Step Functions orchestration"
  type        = bool
  default     = false  # ✅ Safe default - won't break existing deployments
}

variable "orchestration_schedule" {
  description = "Cron expression for pipeline execution (default: daily at 10:30 AM SGT = 2:30 AM UTC)"
  type        = string
  default     = "cron(30 2 * * ? *)"
  
  validation {
    condition     = can(regex("^(cron|rate)\\(", var.orchestration_schedule))
    error_message = "Schedule expression must start with 'cron(' or 'rate('"
  }
}

variable "orchestration_schedule_enabled" {
  description = "Enable or disable the EventBridge schedule (useful for testing)"
  type        = bool
  default     = false  # ✅ Start disabled for safety
}

variable "orchestration_lambda_retries" {
  description = "Maximum number of retries for Lambda function in Step Functions"
  type        = number
  default     = 2
  
  validation {
    condition     = var.orchestration_lambda_retries >= 0 && var.orchestration_lambda_retries <= 5
    error_message = "Lambda retries must be between 0 and 5."
  }
}

variable "orchestration_glue_retries" {
  description = "Maximum number of retries for Glue jobs in Step Functions"
  type        = number
  default     = 1
  
  validation {
    condition     = var.orchestration_glue_retries >= 0 && var.orchestration_glue_retries <= 3
    error_message = "Glue retries must be between 0 and 3."
  }
}

variable "enable_orchestration_logging" {
  description = "Enable CloudWatch Logs for Step Functions execution history"
  type        = bool
  default     = true
}

variable "orchestration_log_retention_days" {
  description = "Number of days to retain Step Functions CloudWatch logs"
  type        = number
  default     = 30
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.orchestration_log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention value."
  }
}

variable "enable_orchestration_monitoring" {
  description = "Enable CloudWatch Alarms for pipeline orchestration monitoring"
  type        = bool
  default     = true
}

variable "orchestration_timeout_threshold_ms" {
  description = "Pipeline execution timeout threshold in milliseconds (default: 60 minutes)"
  type        = number
  default     = 3600000  # 60 minutes - matches your Glue job timeout
}