# ── ECS Image Tag — passed by CI/CD pipeline ─────────────────
# Usage: terraform apply -var="image_tag=<commit-sha>"

variable "image_tag" {
  description = "Docker image tag - commit SHA passed by GitHub Actions"
  type        = string
  default     = "latest"
}
