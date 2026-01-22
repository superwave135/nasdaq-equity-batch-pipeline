# terraform/modules/lambda/variables.tf

variable "s3_bucket" {
  description = "S3 bucket for Lambda to store extracted data"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "lambda_code_version" {
  description = "Optional: S3 object version for Lambda code (if using S3 deployment)"
  type        = string
  default     = null
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = "us-east-1"
}

variable "aws_region" {
  description = "aws_region_for_xxxx"
  type        = string
  default     = "us-east-1"
}
