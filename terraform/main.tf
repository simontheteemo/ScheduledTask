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

  # Add inline policy for CloudWatch Logs
  inline_policy {
    name = "scheduler_cloudwatch_logs"
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
          "${aws_lambda_function.scheduled_lambda.arn}:*"  # Add permission for all function versions
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