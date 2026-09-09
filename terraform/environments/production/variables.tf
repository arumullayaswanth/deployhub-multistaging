variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project" {
  type    = string
  default = "deployhub-multistaging"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "ecr_repo_name" {
  type    = string
  default = "production"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "container_image" {
  type        = string
  description = "ECR image URI:tag to run."
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "db_multi_az" {
  type    = bool
  default = true
}

# kept off so a one-click destroy can tear prod down cleanly for this demo.
# in a real prod account these would be true / false respectively.
variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "alert_email" {
  type    = string
  default = ""
}
