# terraform/modules/cloudwatch/main.tf
# CloudWatch Logging and Monitoring

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# LOG GROUPS
# ============================================================================

# Lambda log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "lambda-logs-${var.environment}"
    Environment = var.environment
    Service     = "lambda"
  }
}

# Glue job logs (continuous logging)
resource "aws_cloudwatch_log_group" "glue_dimensions_logs" {
  name              = "/aws-glue/jobs/${var.glue_job_dimensions}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "glue-dimensions-logs-${var.environment}"
    Environment = var.environment
    Service     = "glue"
  }
}

resource "aws_cloudwatch_log_group" "glue_fact_logs" {
  name              = "/aws-glue/jobs/${var.glue_job_fact}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "glue-fact-logs-${var.environment}"
    Environment = var.environment
    Service     = "glue"
  }
}

resource "aws_cloudwatch_log_group" "glue_aggregations_logs" {
  name              = "/aws-glue/jobs/${var.glue_job_aggregations}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "glue-aggregations-logs-${var.environment}"
    Environment = var.environment
    Service     = "glue"
  }
}

# ============================================================================
# CLOUDWATCH ALARMS - Lambda
# ============================================================================

# Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300  # 5 minutes
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when Lambda function has errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [var.sns_topic_arn]

  tags = {
    Name        = "lambda-errors-alarm-${var.environment}"
    Environment = var.environment
  }
}

# Lambda duration (timeout warning)
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "lambda-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = 270000  # 4.5 minutes (90% of 5 min timeout)
  alarm_description   = "Alert when Lambda is close to timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [var.sns_topic_arn]

  tags = {
    Name        = "lambda-duration-alarm-${var.environment}"
    Environment = var.environment
  }
}

# ============================================================================
# CLOUDWATCH ALARMS - Glue Jobs
# ============================================================================

# Glue job failures
resource "aws_cloudwatch_metric_alarm" "glue_job_failures" {
  alarm_name          = "glue-job-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Glue jobs have failures"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]

  tags = {
    Name        = "glue-failures-alarm-${var.environment}"
    Environment = var.environment
  }
}

# ============================================================================
# CLOUDWATCH DASHBOARD
# ============================================================================

resource "aws_cloudwatch_dashboard" "pipeline_dashboard" {
  dashboard_name = "nasdaq-equity-batch-pipeline-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Lambda Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Lambda Errors" }],
            [".", "Duration", { stat = "Average", label = "Lambda Duration (ms)" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Lambda Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["Glue", "glue.driver.aggregate.numCompletedTasks", { stat = "Sum", label = "Glue Completed Tasks" }],
            [".", "glue.driver.aggregate.numFailedTasks", { stat = "Sum", label = "Glue Failed Tasks" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Glue Job Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.lambda_logs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent Lambda Logs"
        }
      }
    ]
  })
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "log_groups" {
  value = {
    lambda            = aws_cloudwatch_log_group.lambda_logs.name
    glue_dimensions   = aws_cloudwatch_log_group.glue_dimensions_logs.name
    glue_fact         = aws_cloudwatch_log_group.glue_fact_logs.name
    glue_aggregations = aws_cloudwatch_log_group.glue_aggregations_logs.name
  }
  description = "CloudWatch log group names"
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.pipeline_dashboard.dashboard_name
  description = "CloudWatch dashboard name"
}

output "alarm_names" {
  value = {
    lambda_errors   = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
    lambda_duration = aws_cloudwatch_metric_alarm.lambda_duration.alarm_name
    glue_failures   = aws_cloudwatch_metric_alarm.glue_job_failures.alarm_name
  }
  description = "CloudWatch alarm names"
}
