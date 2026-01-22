# modules/step-functions/main.tf
# Step Functions State Machine for NASDAQ Equity Batch Pipeline Orchestration
# KEY: Lambda returns data_date, which is passed to all Glue jobs

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
# IAM ROLE FOR STEP FUNCTIONS EXECUTION
# ============================================================================

resource "aws_iam_role" "step_functions_execution" {
  name = "${var.state_machine_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.state_machine_name}-execution-role"
    }
  )
}

# ============================================================================
# IAM POLICY FOR STEP FUNCTIONS
# ============================================================================

resource "aws_iam_role_policy" "step_functions_execution" {
  name = "${var.state_machine_name}-execution-policy"
  role = aws_iam_role.step_functions_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.lambda_arn
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = [
          "arn:aws:glue:*:*:job/${var.glue_job_dimensions}",
          "arn:aws:glue:*:*:job/${var.glue_job_fact}",
          "arn:aws:glue:*:*:job/${var.glue_job_aggregations}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# CLOUDWATCH LOG GROUP FOR STEP FUNCTIONS
# ============================================================================

resource "aws_cloudwatch_log_group" "step_functions" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/states/${var.state_machine_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.state_machine_name}-logs"
    }
  )
}

# ============================================================================
# STEP FUNCTIONS STATE MACHINE
# ============================================================================

resource "aws_sfn_state_machine" "this" {
  name     = var.state_machine_name
  role_arn = aws_iam_role.step_functions_execution.arn

  definition = jsonencode({
    Comment = "NASDAQ Equity Batch Pipeline - Lambda returns data_date, all Glue jobs use it"
    StartAt = "Extract Stock Data"
    States = {
      # Step 1: Lambda - Extract stock data and get data_date
      "Extract Stock Data" = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_arn
          Payload = {
            "execution_id.$"   = "$$.Execution.Id"
            "execution_time.$" = "$$.Execution.StartTime"
          }
        }
        ResultSelector = {
          "data_date.$"      = "$.Payload.data_date"
          "execution_date.$" = "$.Payload.execution_date"
          "statusCode.$"     = "$.Payload.statusCode"
          "body.$"           = "$.Payload.body"
        }
        ResultPath = "$.lambdaResult"
        Retry = [
          {
            ErrorEquals = [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
              "Lambda.TooManyRequestsException"
            ]
            IntervalSeconds = 2
            MaxAttempts     = var.max_lambda_retries
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "Lambda Extraction Failed"
          }
        ]
        Next = "Wait After Lambda"
      }

      # Wait to ensure S3 data is fully written
      "Wait After Lambda" = {
        Type    = "Wait"
        Seconds = 3
        Next    = "Process Dimensions"
      }

      # Step 2: Glue - Process dimension tables
      "Process Dimensions" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.glue_job_dimensions
          Timeout = var.glue_timeout_minutes
          Arguments = {
            "--processing_date.$" = "$.lambdaResult.data_date"
          }
        }
        ResultPath = "$.dimensionsResult"
        Retry = [
          {
            ErrorEquals = [
              "Glue.ConcurrentRunsExceededException",
              "States.TaskFailed"
            ]
            IntervalSeconds = 30
            MaxAttempts     = var.max_glue_retries
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "Glue Dimensions Failed"
          }
        ]
        Next = "Wait After Dimensions"
      }

      # Wait between Glue jobs
      "Wait After Dimensions" = {
        Type    = "Wait"
        Seconds = 3
        Next    = "Process Fact Table"
      }

      # Step 3: Glue - Process fact table
      "Process Fact Table" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.glue_job_fact
          Timeout = var.glue_timeout_minutes
          Arguments = {
            "--processing_date.$" = "$.lambdaResult.data_date"
          }
        }
        ResultPath = "$.factTableResult"
        Retry = [
          {
            ErrorEquals = [
              "Glue.ConcurrentRunsExceededException",
              "States.TaskFailed"
            ]
            IntervalSeconds = 30
            MaxAttempts     = var.max_glue_retries
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "Glue Fact Table Failed"
          }
        ]
        Next = "Wait After Fact"
      }

      # Wait between Glue jobs
      "Wait After Fact" = {
        Type    = "Wait"
        Seconds = 3
        Next    = "Process Aggregations"
      }

      # Step 4: Glue - Process aggregations
      "Process Aggregations" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.glue_job_aggregations
          Timeout = var.glue_timeout_minutes
          Arguments = {
            "--processing_date.$" = "$.lambdaResult.data_date"
          }
        }
        ResultPath = "$.aggregationsResult"
        Retry = [
          {
            ErrorEquals = [
              "Glue.ConcurrentRunsExceededException",
              "States.TaskFailed"
            ]
            IntervalSeconds = 30
            MaxAttempts     = var.max_glue_retries
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "Glue Aggregations Failed"
          }
        ]
        Next = "Pipeline Succeeded"
      }

      # Success state
      "Pipeline Succeeded" = {
        Type = "Succeed"
      }

      # Error states
      "Lambda Extraction Failed" = {
        Type  = "Fail"
        Error = "LambdaExtractionFailed"
        Cause = "Lambda function failed to extract stock data"
      }

      "Glue Dimensions Failed" = {
        Type  = "Fail"
        Error = "GlueDimensionsFailed"
        Cause = "Glue job failed to process dimension tables"
      }

      "Glue Fact Table Failed" = {
        Type  = "Fail"
        Error = "GlueFactTableFailed"
        Cause = "Glue job failed to process fact table"
      }

      "Glue Aggregations Failed" = {
        Type  = "Fail"
        Error = "GlueAggregationsFailed"
        Cause = "Glue job failed to process aggregations"
      }
    }
  })

  dynamic "logging_configuration" {
    for_each = var.enable_cloudwatch_logs ? [1] : []
    
    content {
      log_destination        = "${aws_cloudwatch_log_group.step_functions[0].arn}:*"
      include_execution_data = true
      level                  = "ALL"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.state_machine_name
    }
  )
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.this.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.this.name
}

output "state_machine_id" {
  description = "ID of the Step Functions state machine"
  value       = aws_sfn_state_machine.this.id
}

output "execution_role_arn" {
  description = "ARN of the Step Functions execution role"
  value       = aws_iam_role.step_functions_execution.arn
}

output "execution_role_name" {
  description = "Name of the Step Functions execution role"
  value       = aws_iam_role.step_functions_execution.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group (if logging is enabled)"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.step_functions[0].name : null
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group (if logging is enabled)"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.step_functions[0].arn : null
}