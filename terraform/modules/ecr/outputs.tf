output "fe_app_repository_url" {
  value = aws_ecr_repository.fe_app.repository_url
}

output "api_app_repository_url" {
  value = aws_ecr_repository.api_app.repository_url
}

output "monitoring_repository_url" {
  value = aws_ecr_repository.monitoring.repository_url
}
