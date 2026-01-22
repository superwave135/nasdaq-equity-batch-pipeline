# modules/step-functions/variables.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
}

variable "lambda_arn" {
  description = "ARN of the Lambda function for stock extraction"
  type        = string
}

variable "glue_job_dimensions" {
  description = "Name of the Glue job for dimension processing"
  type        = string
}

variable "glue_job_fact" {
  description = "Name of the Glue job for fact table processing"
  type        = string
}

variable "glue_job_aggregations" {
  description = "Name of the Glue job for aggregations processing"
  type        = string
}

variable "max_lambda_retries" {
  description = "Maximum number of retries for Lambda function"
  type        = number
  default     = 2
}

variable "max_glue_retries" {
  description = "Maximum number of retries for Glue jobs"
  type        = number
  default     = 1
}

variable "lambda_timeout_seconds" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 300
}

variable "glue_timeout_minutes" {
  description = "Timeout for Glue jobs in minutes"
  type        = number
  default     = 60
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logging for Step Functions"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}