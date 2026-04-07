variable "environment" {
  description = "Nombre del entorno (dev, prod, ...)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "private_compute_subnet_ids" {
  description = "Subredes privadas con ruta al NAT (Lambda consumidora + SQS API)"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group para Lambdas que acceden a RDS"
  type        = string
}

variable "db_host" {
  description = "Hostname RDS (sin puerto)"
  type        = string
}

variable "db_port" {
  description = "Puerto PostgreSQL"
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "db_username" {
  description = "Usuario de la base de datos"
  type        = string
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}
