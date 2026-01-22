# terraform/modules/glue/variables.tf

variable "database_name" {
  description = "Name of the Glue catalog database"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name for Glue scripts and data"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}
