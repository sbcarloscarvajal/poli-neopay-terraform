output "api_invoke_url" {
  description = "URL base del HTTP API (POST /pagos)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  value = aws_apigatewayv2_api.pagos.id
}

output "sqs_queue_url" {
  value = aws_sqs_queue.pagos.url
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.pagos.arn
}

output "lambda_producer_name" {
  value = aws_lambda_function.producer.function_name
}

output "lambda_consumer_name" {
  value = aws_lambda_function.consumer.function_name
}
