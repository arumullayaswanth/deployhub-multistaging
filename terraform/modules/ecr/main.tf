# private container registry the CI/CD pipeline pushes images to
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  # allow terraform destroy to remove the repo even if it still has images
  force_delete = true

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
  }

  tags = { Name = var.name }
}

# lifecycle rule to drop untagged images so storage doesn't pile up
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "expire untagged images older than ${var.untagged_expiry_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.untagged_expiry_days
      }
      action = { type = "expire" }
    }]
  })
}
