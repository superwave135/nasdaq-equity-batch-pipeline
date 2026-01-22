# terraform/modules/cloudwatch/variables.tf

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "glue_job_dimensions" {
  description = "Glue dimensions job name"
  type        = string
}

variable "glue_job_fact" {
  description = "Glue fact table job name"
  type        = string
}

variable "glue_job_aggregations" {
  description = "Glue aggregations job name"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 7
}
