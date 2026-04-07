output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "db_endpoint" {
  value = module.compute.db_endpoint
}

output "db_name" {
  value = module.compute.db_name
}

output "db_username" {
  value = module.compute.db_username
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_compute_subnet_ids" {
  value = module.network.private_compute_subnet_ids
}

output "private_data_subnet_ids" {
  value = module.network.private_data_subnet_ids
}

output "pagos_api_invoke_url" {
  description = "HTTP API NeoPay pagos (POST /pagos). Complementa el ALB para el flujo serverless."
  value       = module.serverless.api_invoke_url
}

output "pagos_sqs_queue_url" {
  description = "Cola SQS de eventos PagoPendiente"
  value       = module.serverless.sqs_queue_url
}
