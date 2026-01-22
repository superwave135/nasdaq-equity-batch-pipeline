# ============================================================================
# AWS CodeBuild Module - NASDAQ Equity Batch Pipeline
# ============================================================================
# Purpose: Create CodeBuild projects for CI/CD pipeline
# Components: CI project, CD project, S3 artifacts bucket
# ============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# S3 BUCKET FOR BUILD ARTIFACTS
# ============================================================================

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-codebuild-artifacts-${var.environment}"

  tags = {
    Name        = "${var.project_name}-codebuild-artifacts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "delete-old-artifacts"
    status = "Enabled"

    filter {
      prefix = ""  # Apply to all objects
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# ============================================================================
# CODEBUILD CI PROJECT
# ============================================================================

resource "aws_codebuild_project" "ci" {
  name          = "${var.project_name}-ci-${var.environment}"
  description   = "CI pipeline for ${var.project_name} - Build, test, and package"
  build_timeout = var.build_timeout
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
    packaging = "ZIP"
    name      = "ci-artifacts"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.artifacts.bucket}/cache"
  }

  environment {
    compute_type                = var.compute_type
    image                      = var.build_image
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = false

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "S3_BUCKET"
      value = var.s3_bucket_name
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = var.ci_buildspec_path

    git_submodules_config {
      fetch_submodules = false
    }
  }

  source_version = var.github_branch

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-ci-${var.environment}"
      stream_name = "build"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.artifacts.bucket}/build-logs"
    }
  }

  tags = {
    Name        = "${var.project_name}-ci"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Pipeline    = "CI"
  }
}

# ============================================================================
# CODEBUILD CD PROJECT
# ============================================================================

resource "aws_codebuild_project" "cd" {
  name          = "${var.project_name}-cd-${var.environment}"
  description   = "CD pipeline for ${var.project_name} - Deploy to AWS"
  build_timeout = var.build_timeout
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = var.compute_type
    image                      = var.build_image
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = false

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "LAMBDA_FUNCTION_NAME"
      value = var.lambda_function_name
    }

    environment_variable {
      name  = "S3_BUCKET"
      value = var.s3_bucket_name
    }
    # Orchestration environment variables
    environment_variable {
      name  = "EVENTBRIDGE_RULE_NAME"
      value = var.eventbridge_rule_name
    }

    environment_variable {
      name  = "STATE_MACHINE_ARN"
      value = var.state_machine_arn
    }

    environment_variable {
      name  = "STATE_MACHINE_NAME"
      value = var.state_machine_name
    }

  }   # ← environment block closes

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = var.cd_buildspec_path

    git_submodules_config {
      fetch_submodules = false
    }
  }

  source_version = var.github_branch

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-cd-${var.environment}"
      stream_name = "deploy"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.artifacts.bucket}/deploy-logs"
    }
  }

  tags = {
    Name        = "${var.project_name}-cd"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Pipeline    = "CD"
  }
}

# ============================================================================
# CLOUDWATCH LOG GROUPS
# ============================================================================

resource "aws_cloudwatch_log_group" "ci" {
  name              = "/aws/codebuild/${var.project_name}-ci-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-ci-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "cd" {
  name              = "/aws/codebuild/${var.project_name}-cd-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-cd-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

