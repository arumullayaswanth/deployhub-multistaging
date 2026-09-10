# tells RDS which subnets it can live in (the private data subnets)
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_data_subnet_ids
  tags       = { Name = "${var.name}-db-subnets" }
}

# database security group - only the app can reach postgres on 5432
resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "postgres from app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "postgres from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    description = "allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-db-sg" }
}

# the PostgreSQL database - private, encrypted, with automated backups
resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  # AWS manages the master password in Secrets Manager and rotates it natively.
  # no rotation lambda, no SAR app, no python runtime headaches.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  multi_az = var.multi_az

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot   = true
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true

  tags = { Name = "${var.name}-postgres" }
}

# rotate the AWS-managed master password on a daily schedule
resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id = aws_db_instance.this.master_user_secret[0].secret_arn

  rotation_rules {
    automatically_after_days = 1
  }
}
