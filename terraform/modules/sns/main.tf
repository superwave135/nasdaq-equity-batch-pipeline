# terraform/modules/sns/main.tf
# SNS Topic for Pipeline Notifications

resource "aws_sns_topic" "pipeline_alerts" {
  name         = "nasdaq-equity-batch-pipeline-alerts-${var.environment}"
  display_name = "NASDAQ Equity Batch Pipeline Alerts"

  tags = {
    Name        = "nasdaq-equity-batch-pipeline-alerts-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

output "topic_arn" {
  value = aws_sns_topic.pipeline_alerts.arn
}
