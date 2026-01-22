# ============================================================================
# Outputs for CodeBuild Module - NASDAQ Equity Batch Pipeline
# ============================================================================

output "ci_project_name" {
  description = "Name of the CI CodeBuild project"
  value       = aws_codebuild_project.ci.name
}

output "ci_project_arn" {
  description = "ARN of the CI CodeBuild project"
  value       = aws_codebuild_project.ci.arn
}

output "cd_project_name" {
  description = "Name of the CD CodeBuild project"
  value       = aws_codebuild_project.cd.name
}

output "cd_project_arn" {
  description = "ARN of the CD CodeBuild project"
  value       = aws_codebuild_project.cd.arn
}

output "artifacts_bucket_name" {
  description = "Name of the S3 artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild.arn
}

output "codebuild_role_name" {
  description = "Name of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild.name
}

output "ci_log_group_name" {
  description = "Name of the CI CloudWatch log group"
  value       = aws_cloudwatch_log_group.ci.name
}

output "cd_log_group_name" {
  description = "Name of the CD CloudWatch log group"
  value       = aws_cloudwatch_log_group.cd.name
}


# ============================================================================
# AWS CONSOLE URLs
# ============================================================================

output "ci_project_url" {
  description = "AWS Console URL for CI project"
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codebuild/projects/${aws_codebuild_project.ci.name}"
}

output "cd_project_url" {
  description = "AWS Console URL for CD project"
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codebuild/projects/${aws_codebuild_project.cd.name}"
}

output "artifacts_bucket_url" {
  description = "AWS Console URL for artifacts bucket"
  value       = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.artifacts.bucket}"
}
