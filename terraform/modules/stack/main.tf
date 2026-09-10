# groups every resource of this environment (by its Environment tag) into one
# AWS Resource Group, so staging and production each show up as a single group.
resource "aws_resourcegroups_group" "this" {
  name = "${var.name}-resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [{
        Key    = "Environment"
        Values = [var.name]
      }]
    })
  }

  tags = { Name = "${var.name}-resources" }
}

# app SG lives here (not in the ecs module) so rds can reference it and we
# avoid an ecs <-> rds dependency cycle
resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "ecs tasks, allow traffic from alb only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "app port from alb"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [module.alb.alb_security_group_id]
  }

  egress {
    description = "allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app-sg" }
}

# the network: VPC, subnets, gateways, route tables
module "vpc" {
  source   = "../vpc"
  name     = var.name
  vpc_cidr = var.vpc_cidr
}

# the container registry for the app image
module "ecr" {
  source = "../ecr"
  name   = var.ecr_repo_name
}

# the public load balancer + its security group and access logs
module "alb" {
  source            = "../alb"
  name              = var.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  container_port    = var.container_port
}

# the PostgreSQL database with AWS-managed rotating credentials
module "rds" {
  source                  = "../rds"
  name                    = var.name
  vpc_id                  = module.vpc.vpc_id
  private_data_subnet_ids = module.vpc.private_data_subnet_ids
  app_security_group_id   = aws_security_group.app.id
  multi_az                = var.db_multi_az
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
}

# the ECS Fargate cluster/service that runs the app container
module "ecs" {
  source                 = "../ecs"
  name                   = var.name
  vpc_id                 = module.vpc.vpc_id
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  app_security_group_id  = aws_security_group.app.id
  alb_listener_arn       = module.alb.listener_arn
  target_group_arn       = module.alb.target_group_arn
  db_secret_arn          = module.rds.db_secret_arn
  db_host                = module.rds.db_endpoint
  db_name                = module.rds.db_name
  container_image        = var.container_image
  container_port         = var.container_port
  desired_count          = var.desired_count
}

# dashboards, alarms and SNS alerts for the whole stack
module "monitoring" {
  source           = "../monitoring"
  name             = var.name
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name
  alb_arn_suffix   = module.alb.alb_arn_suffix
  db_instance_id   = module.rds.db_instance_id
  alert_email      = var.alert_email
}
