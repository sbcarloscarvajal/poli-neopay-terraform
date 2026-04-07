module "network" {
  source = "./modules/network"

  vpc_cidr                = var.vpc_cidr
  environment             = var.environment
  public_subnets          = var.public_subnets
  private_compute_subnets = var.private_compute_subnets
  private_data_subnets    = var.private_data_subnets
  availability_zones      = var.availability_zones
}

module "security" {
  source = "./modules/security"

  vpc_id      = module.network.vpc_id
  environment = var.environment
}

module "compute" {
  source = "./modules/compute"

  environment                = var.environment
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  private_compute_subnet_ids = module.network.private_compute_subnet_ids
  private_data_subnet_ids    = module.network.private_data_subnet_ids
  alb_sg_id                  = module.security.alb_sg_id
  app_sg_id                  = module.security.app_sg_id
  db_sg_id                   = module.security.db_sg_id
  ec2_instance_profile_name  = module.security.ec2_instance_profile_name
  multi_az_db                = var.multi_az_db
  db_password                = var.db_password
}

locals {
  db_endpoint_parts = split(":", module.compute.db_endpoint)
  db_host             = local.db_endpoint_parts[0]
  db_port             = local.db_endpoint_parts[1]
}

module "serverless" {
  source = "./modules/serverless"

  environment                = var.environment
  private_compute_subnet_ids = module.network.private_compute_subnet_ids
  lambda_security_group_id   = module.security.lambda_payments_sg_id

  db_host     = local.db_host
  db_port     = local.db_port
  db_name     = module.compute.db_name
  db_username = module.compute.db_username
  db_password = var.db_password
}
