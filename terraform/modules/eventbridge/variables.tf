# modules/eventbridge/variables.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "rule_name" {
  description = "Name of the EventBridge rule"
  type        = string
}

variable "schedule_expression" {
  description = "Cron or rate expression for the schedule (e.g., 'cron(30 2 * * ? *)' for 10:30 AM SGT daily)"
  type        = string
}

variable "enabled" {
  description = "Whether the EventBridge rule is enabled"
  type        = bool
  default     = false
}

variable "target_arn" {
  description = "ARN of the Step Functions state machine to invoke"
  type        = string
}

variable "state_machine_role_arn" {
  description = "ARN of the Step Functions execution role (used for reference)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
