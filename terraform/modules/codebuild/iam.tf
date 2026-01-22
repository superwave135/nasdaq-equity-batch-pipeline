# ============================================================================
# IAM Roles and Policies for CodeBuild - NASDAQ Equity Batch Pipeline
# ============================================================================

# ============================================================================
# IAM ROLE FOR CODEBUILD
# ============================================================================

resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codebuild-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# CLOUDWATCH LOGS POLICY
# ============================================================================

resource "aws_iam_role_policy" "codebuild_logs" {
  name = "codebuild-logs-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.project_name}-*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.project_name}-*:*"
        ]
      }
    ]
  })
}

# ============================================================================
# S3 POLICY (Artifacts and Pipeline Bucket)
# ============================================================================

resource "aws_iam_role_policy" "codebuild_s3" {
  name = "codebuild-s3-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}/glue-scripts/*",
          "arn:aws:s3:::${var.s3_bucket_name}/airflow-dags/*"
        ]
      }
    ]
  })
}

# ============================================================================
# LAMBDA POLICY (for CD deployment)
# ============================================================================

resource "aws_iam_role_policy" "codebuild_lambda" {
  name = "codebuild-lambda-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${var.lambda_function_name}"
      }
    ]
  })
}

# ============================================================================
# GLUE POLICY (optional - for Glue job verification)
# ============================================================================

resource "aws_iam_role_policy" "codebuild_glue" {
  count = var.enable_glue_permissions ? 1 : 0
  
  name = "codebuild-glue-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetJob"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:*:catalog",
          "arn:aws:glue:${var.aws_region}:*:database/*",
          "arn:aws:glue:${var.aws_region}:*:table/*/*",
          "arn:aws:glue:${var.aws_region}:*:job/*"
        ]
      }
    ]
  })
}

# ============================================================================
# SECRETS MANAGER POLICY (for API keys, if needed)
# ============================================================================

resource "aws_iam_role_policy" "codebuild_secrets" {
  count = var.enable_secrets_access ? 1 : 0
  
  name = "codebuild-secrets-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/*"
      }
    ]
  })
}

# ============================================================================
# CODECOMMIT/GITHUB POLICY (for source access)
# ============================================================================

resource "aws_iam_role_policy" "codebuild_source" {
  name = "codebuild-source-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# CODEBUILD POLICY (for report groups)
# ============================================================================

resource "aws_iam_role_policy" "codebuild_reports" {
  name = "codebuild-reports-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ]
        Resource = [
          "arn:aws:codebuild:${var.aws_region}:*:report-group/${var.project_name}-*"
        ]
      }
    ]
  })
}
