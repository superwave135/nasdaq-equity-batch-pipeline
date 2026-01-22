# ============================================================================
# Variables for CodeBuild Module - NASDAQ Equity Batch Pipeline
# ============================================================================

variable "project_name" {
  description = "Project name (e.g., nasdaq-equity-batch-pipeline"
  type        = string
  default     = "nasdaq-equity-batch-pipeline"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ============================================================================
# GITHUB CONFIGURATION
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

# ============================================================================
# BUILDSPEC PATHS
# ============================================================================

variable "ci_buildspec_path" {
  description = "Path to CI buildspec file in repository"
  type        = string
  default     = "cicd/buildspec-ci.yml"
}

variable "cd_buildspec_path" {
  description = "Path to CD buildspec file in repository"
  type        = string
  default     = "cicd/buildspec-cd.yml"
}

# ============================================================================
# CODEBUILD CONFIGURATION
# ============================================================================

variable "build_image" {
  description = "Docker image for CodeBuild environment"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"

  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL",
      "BUILD_GENERAL1_MEDIUM",
      "BUILD_GENERAL1_LARGE"
    ], var.compute_type)
    error_message = "Invalid compute type."
  }
}

variable "build_timeout" {
  description = "Build timeout in minutes"
  type        = number
  default     = 20

  validation {
    condition     = var.build_timeout >= 5 && var.build_timeout <= 480
    error_message = "Build timeout must be between 5 and 480 minutes."
  }
}

# ============================================================================
# DEPLOYMENT TARGETS
# ============================================================================

variable "s3_bucket_name" {
  description = "S3 bucket name for pipeline data"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name for deployment"
  type        = string
}

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Invalid log retention days."
  }
}

# ============================================================================
# OPTIONAL FEATURES
# ============================================================================

variable "enable_glue_permissions" {
  description = "Enable Glue permissions for CodeBuild"
  type        = bool
  default     = true
}

variable "enable_secrets_access" {
  description = "Enable Secrets Manager access for CodeBuild"
  type        = bool
  default     = false
}

variable "enable_cache" {
  description = "Enable S3 cache for builds"
  type        = bool
  default     = true
}

# ============================================================================
# ORCHESTRATION DEPLOYMENT CONFIGURATION
# ============================================================================

variable "eventbridge_rule_name" {
  description = "EventBridge rule name for deployment"
  type        = string
  default     = ""
}

variable "state_machine_arn" {
  description = "Step Functions state machine ARN"
  type        = string
  default     = ""
}

variable "state_machine_name" {
  description = "Step Functions state machine name"
  type        = string
  default     = ""
}

variable "enable_cache" {
  description = "Enable S3 cache for builds"
  type        = bool
  default     = true
}

# ============================================================================
# TAGS
# ============================================================================

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
