# Configure AWS Provider
provider "aws" {
  region = "us-west-2"  # Change to your desired region
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "scheduled-task-state-bucket"
}

# Enable versioning for state files
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "scheduled_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda basic execution policy attachment
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Lambda function
resource "aws_lambda_function" "scheduled_lambda" {
  filename         = "function.zip"
  function_name    = "scheduled_task"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30
  memory_size     = 128

  environment {
    variables = {
      NODE_ENV = "production"
      LOG_LEVEL = "info"
    }
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.scheduled_lambda.function_name}"
  retention_in_days = 14
}

# EventBridge Scheduler Role
resource "aws_iam_role" "scheduler_role" {
  name = "eventbridge_scheduler_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

# Separate CloudWatch Logs policy for Scheduler
resource "aws_iam_role_policy" "scheduler_cloudwatch_policy" {
  name = "scheduler_cloudwatch_logs"
  role = aws_iam_role.scheduler_role.id

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
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# EventBridge Scheduler policy to invoke Lambda
resource "aws_iam_role_policy" "scheduler_lambda_policy" {
  name = "scheduler_lambda_policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.scheduled_lambda.arn,
          "${aws_lambda_function.scheduled_lambda.arn}:*"
        ]
      }
    ]
  })
}

# EventBridge Scheduler
resource "aws_scheduler_schedule" "lambda_schedule" {
  name        = "lambda_scheduled_task"
  description = "Schedule for Lambda function execution"
  group_name  = "default"
  
  schedule_expression          = "cron(0 12 * * ? *)"  # Runs daily at 12:00 PM UTC
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.scheduled_lambda.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      detail = "Scheduled execution"
    })

    retry_policy {
      maximum_retry_attempts = 3
    }
  }

  state = "ENABLED"
}

# Add explicit Lambda permission for EventBridge Scheduler
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduled_lambda.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.lambda_schedule.arn
}