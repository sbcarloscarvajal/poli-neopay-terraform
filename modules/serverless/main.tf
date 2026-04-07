data "archive_file" "producer" {
  type        = "zip"
  source_file = "${path.module}/lambda/producer/main.py"
  output_path = "${path.module}/builds/producer.zip"
}

data "archive_file" "consumer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/consumer/package"
  output_path = "${path.module}/builds/consumer.zip"
}

resource "aws_sqs_queue" "pagos_dlq" {
  name = "neopay-pagos-dlq-${var.environment}"
}

resource "aws_sqs_queue" "pagos" {
  name                       = "neopay-pagos-${var.environment}"
  visibility_timeout_seconds = 180
  receive_wait_time_seconds  = 0

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.pagos_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_iam_role" "producer" {
  name = "neopay-pagos-producer-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "producer_logs" {
  role       = aws_iam_role.producer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "producer_sqs" {
  name = "neopay-producer-sqs-${var.environment}"
  role = aws_iam_role.producer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.pagos.arn
    }]
  })
}

resource "aws_lambda_function" "producer" {
  function_name = "neopay-pagos-producer-${var.environment}"
  role          = aws_iam_role.producer.arn
  runtime       = "python3.12"
  handler       = "main.handler"
  filename      = data.archive_file.producer.output_path
  source_code_hash = data.archive_file.producer.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.pagos.url
    }
  }
}

resource "aws_iam_role" "consumer" {
  name = "neopay-pagos-consumer-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "consumer_logs" {
  role       = aws_iam_role.consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "consumer_vpc" {
  role       = aws_iam_role.consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "consumer_sqs" {
  name = "neopay-consumer-sqs-${var.environment}"
  role = aws_iam_role.consumer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.pagos.arn
    }]
  })
}

resource "aws_lambda_function" "consumer" {
  function_name = "neopay-pagos-consumer-${var.environment}"
  role          = aws_iam_role.consumer.arn
  runtime       = "python3.12"
  handler       = "main.handler"
  filename      = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256
  timeout       = 60
  memory_size   = 256

  vpc_config {
    subnet_ids         = var.private_compute_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_PORT     = var.db_port
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.consumer_vpc,
    aws_iam_role_policy_attachment.consumer_logs,
  ]
}

resource "aws_lambda_event_source_mapping" "consumer" {
  event_source_arn = aws_sqs_queue.pagos.arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 5
}

resource "aws_apigatewayv2_api" "pagos" {
  name          = "neopay-pagos-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.pagos.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "producer" {
  api_id                 = aws_apigatewayv2_api.pagos.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.producer.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_pagos" {
  api_id    = aws_apigatewayv2_api.pagos.id
  route_key = "POST /pagos"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

resource "aws_lambda_permission" "apigw_invoke_producer" {
  statement_id  = "AllowInvokeFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pagos.execution_arn}/*/*"
}
