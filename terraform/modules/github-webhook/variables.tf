# ============================================================================
# Variables for GitHub Webhook Module - NASDAQ Equity Batch Pipeline
# ============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "nasdaq-equity-batch-pipeline"
}

# ============================================================================
# GITHUB CONFIGURATION
# ============================================================================

variable "github_token" {
  description = "GitHub personal access token for webhook authentication"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================================
# CODEBUILD PROJECTS
# ============================================================================

variable "codebuild_ci_project_name" {
  description = "Name of the CodeBuild CI project"
  type        = string
}

variable "codebuild_ci_project_arn" {
  description = "ARN of the CodeBuild CI project (for CloudWatch Events)"
  type        = string
  default     = ""
}

variable "codebuild_cd_project_name" {
  description = "Name of the CodeBuild CD project"
  type        = string
  default     = ""
}

# ============================================================================
# WEBHOOK TRIGGERS
# ============================================================================

variable "trigger_branch_pattern" {
  description = "Branch pattern to trigger CI builds (regex)"
  type        = string
  default     = "refs/heads/main"
}

variable "trigger_on_pr" {
  description = "Enable webhook trigger on pull requests"
  type        = bool
  default     = false
}

variable "pr_base_branch_pattern" {
  description = "Base branch pattern for PR triggers"
  type        = string
  default     = "refs/heads/main"
}

variable "file_path_filters" {
  description = "List of file path patterns to trigger builds (optional)"
  type        = list(string)
  default     = []
}

# ============================================================================
# CD WEBHOOK (OPTIONAL)
# ============================================================================

variable "enable_cd_webhook" {
  description = "Enable separate webhook for CD project"
  type        = bool
  default     = false
}

variable "cd_trigger_branch_pattern" {
  description = "Branch pattern to trigger CD deployments"
  type        = string
  default     = "refs/heads/main"
}

# ============================================================================
# CLOUDWATCH EVENTS (ALTERNATIVE TO WEBHOOK)
# ============================================================================

variable "use_cloudwatch_events" {
  description = "Use CloudWatch Events instead of direct webhook"
  type        = bool
  default     = false
}

variable "cloudwatch_events_role_arn" {
  description = "IAM role ARN for CloudWatch Events to invoke CodeBuild"
  type        = string
  default     = ""
}
