# modules/eventbridge/main.tf
# EventBridge Rule for Scheduled Execution of Step Functions State Machine

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# EVENTBRIDGE RULE (SCHEDULER)
# ============================================================================

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = var.rule_name
  description         = "Scheduled trigger for ${var.project_name} Step Functions state machine"
  schedule_expression = var.schedule_expression
  state               = var.enabled ? "ENABLED" : "DISABLED"

  tags = merge(
    var.tags,
    {
      Name = var.rule_name
    }
  )
}

# ============================================================================
# EVENTBRIDGE TARGET (STEP FUNCTIONS)
# ============================================================================

resource "aws_cloudwatch_event_target" "step_functions" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "${var.project_name}-step-functions-target"
  arn       = var.target_arn
  role_arn  = aws_iam_role.eventbridge_step_functions.arn
}

# ============================================================================
# IAM ROLE FOR EVENTBRIDGE TO INVOKE STEP FUNCTIONS
# ============================================================================

resource "aws_iam_role" "eventbridge_step_functions" {
  name = "${var.rule_name}-invoke-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.rule_name}-invoke-role"
    }
  )
}

# ============================================================================
# IAM POLICY FOR EVENTBRIDGE TO INVOKE STEP FUNCTIONS
# ============================================================================

resource "aws_iam_role_policy" "eventbridge_step_functions" {
  name = "${var.rule_name}-invoke-policy"
  role = aws_iam_role.eventbridge_step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = var.target_arn
      }
    ]
  })
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.schedule.arn
}

output "rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.schedule.name
}

output "rule_id" {
  description = "ID of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.schedule.id
}

output "target_id" {
  description = "ID of the EventBridge target"
  value       = aws_cloudwatch_event_target.step_functions.target_id
}

output "invoke_role_arn" {
  description = "ARN of the IAM role used by EventBridge to invoke Step Functions"
  value       = aws_iam_role.eventbridge_step_functions.arn
}

output "schedule_expression" {
  description = "The schedule expression for the rule"
  value       = aws_cloudwatch_event_rule.schedule.schedule_expression
}

output "is_enabled" {
  description = "Whether the EventBridge rule is enabled"
  value       = aws_cloudwatch_event_rule.schedule.state == "ENABLED"
}