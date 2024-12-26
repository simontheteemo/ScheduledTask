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