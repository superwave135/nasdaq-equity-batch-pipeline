# ============================================================================
# GitHub Webhook Module - NASDAQ Equity Batch Pipeline
# ============================================================================
# Purpose: Configure GitHub webhook to trigger CodeBuild on push
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
# GITHUB SOURCE CREDENTIALS
# ============================================================================

resource "aws_codebuild_source_credential" "github" {
  count = var.github_token != "" ? 1 : 0

  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_token
}

# ============================================================================
# CODEBUILD WEBHOOK FOR CI PROJECT
# ============================================================================

resource "aws_codebuild_webhook" "ci" {
  project_name = var.codebuild_ci_project_name

  # Trigger on push to specified branch
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = var.trigger_branch_pattern
    }
  }

  # Optional: Trigger on pull request
  dynamic "filter_group" {
    for_each = var.trigger_on_pr ? [1] : []
    
    content {
      filter {
        type    = "EVENT"
        pattern = "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED,PULL_REQUEST_REOPENED"
      }

      filter {
        type    = "BASE_REF"
        pattern = var.pr_base_branch_pattern
      }
    }
  }

  # Optional: Trigger on specific file patterns
  dynamic "filter_group" {
    for_each = var.file_path_filters
    
    content {
      filter {
        type    = "EVENT"
        pattern = "PUSH"
      }

      filter {
        type    = "HEAD_REF"
        pattern = var.trigger_branch_pattern
      }

      filter {
        type    = "FILE_PATH"
        pattern = filter_group.value
      }
    }
  }

  build_type = "BUILD"
}

# ============================================================================
# OPTIONAL: CODEBUILD WEBHOOK FOR CD PROJECT
# ============================================================================

resource "aws_codebuild_webhook" "cd" {
  count = var.enable_cd_webhook ? 1 : 0

  project_name = var.codebuild_cd_project_name

  # Only trigger CD on specific branch (e.g., main/production)
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = var.cd_trigger_branch_pattern
    }
  }

  build_type = "BUILD"
}

# ============================================================================
# CLOUDWATCH EVENT RULE (Alternative to webhook)
# ============================================================================

# If you prefer CloudWatch Events instead of direct webhook
resource "aws_cloudwatch_event_rule" "github_push" {
  count = var.use_cloudwatch_events ? 1 : 0

  name        = "${var.project_name}-github-push"
  description = "Trigger CodeBuild on GitHub push"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = [var.trigger_branch_pattern]
    }
  })
}

resource "aws_cloudwatch_event_target" "codebuild_ci" {
  count = var.use_cloudwatch_events ? 1 : 0

  rule      = aws_cloudwatch_event_rule.github_push[0].name
  target_id = "CodeBuildCI"
  arn       = var.codebuild_ci_project_arn
  role_arn  = var.cloudwatch_events_role_arn
}
