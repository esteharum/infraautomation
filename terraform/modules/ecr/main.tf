# ── ECR Repositories ────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_ecr_repository" "fe_app" {
  name                 = "lks-fe-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = { Name = "lks-fe-app" }
}

resource "aws_ecr_repository" "api_app" {
  name                 = "lks-api-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = { Name = "lks-api-app" }
}

resource "aws_ecr_repository" "monitoring" {
  name                 = "lks-monitoring"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  provider = aws.oregon
  tags     = { Name = "lks-monitoring" }
}
