# current account id, used to name the log bucket uniquely
data "aws_caller_identity" "current" {}
# the AWS account that writes ALB access logs (region-specific)
data "aws_elb_service_account" "main" {}

# security group for the load balancer - allows web traffic from the internet
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "web traffic to the alb"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb-sg" }
}

# S3 bucket that stores the load balancer access logs
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name}-alb-access-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "${var.name}-alb-logs" }
}

# block all public access to the log bucket
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# let the ELB service write log files into the bucket
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = data.aws_elb_service_account.main.arn }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.logs.arn}/*"
    }]
  })
}

# the public application load balancer that receives all user traffic
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    enabled = true
  }

  tags       = { Name = "${var.name}-alb" }
  depends_on = [aws_s3_bucket_policy.logs]
}

# target group the ECS tasks register into, with a /health check
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "${var.name}-tg" }
}

# listener on port 80 that forwards traffic to the target group
# (http only for now, prod should add a 443 listener with acm + redirect)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
