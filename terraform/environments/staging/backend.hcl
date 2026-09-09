# terraform init -backend-config=backend.hcl
# bucket and lock table are created manually before the first pipeline run
bucket         = "deployhub-tfstate-yaswanth"
dynamodb_table = "terraform-state-lock"
