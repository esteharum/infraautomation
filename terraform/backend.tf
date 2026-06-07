# ── Terraform Backend — S3 ─────────────────────────────────
# BUG FIX: Backend S3 diperlukan agar CI/CD pipeline bisa share state
# Jalankan terraform init -backend-config=... seperti di pipeline
# ATAU isi values di sini setelah S3 bucket dibuat
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment dan isi setelah S3 bucket lks-tfstate-* dibuat:
  # backend "s3" {
  #   bucket = "lks-tfstate-[yourname]-[suffix]"
  #   key    = "prod/terraform.tfstate"
  #   region = "us-east-1"
  # }
}
