# terraform init -backend-config=backend.hcl
bucket         = "deployhub-tfstate-yaswanth"
dynamodb_table = "terraform-state-lock"
