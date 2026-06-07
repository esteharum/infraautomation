# Module: database

Provisions all data storage and messaging resources in the isolated subnet
of lks-vpc (us-east-1). Also creates the two S3 buckets required by the project.

## Resources to create

### Amazon RDS PostgreSQL
- `aws_db_subnet_group` — uses isolated_subnet_ids
- `aws_db_instance` — lks-rds-postgres
  - engine: postgres, engine_version: "15"
  - instance_class: db.t3.micro, allocated_storage: 20
  - db_name, username, password from variables
  - publicly_accessible: false
  - skip_final_snapshot: true (Learner Lab)
  - backup_retention_period: 7
  - vpc_security_group_ids: [var.security_group_id]

### Amazon DynamoDB
- `aws_dynamodb_table` — lks-sessions
  - billing_mode: PAY_PER_REQUEST
  - hash_key: sessionId (S), range_key: createdAt (N)
  - ttl: attribute_name = "expiresAt"
  - point_in_time_recovery: enabled

### Amazon SQS
- `aws_sqs_queue` — lks-event-queue (standard)
  - visibility_timeout_seconds: 30
  - redrive_policy → lks-dlq, maxReceiveCount: 3
- `aws_sqs_queue` — lks-dlq (dead-letter queue)

### Amazon S3
- `aws_s3_bucket` — lks-tfstate-[name]-2026
  - aws_s3_bucket_versioning: enabled
  - aws_s3_bucket_server_side_encryption_configuration: AES256
  - aws_s3_bucket_public_access_block: all blocked
  - aws_s3_bucket_lifecycle_configuration:
      → Standard-IA after 30 days, delete after 365 days

- `aws_s3_bucket` — lks-app-assets-[name]-2026
  - aws_s3_bucket_versioning: enabled
  - aws_s3_bucket_policy: allow s3:GetObject on /public/*
  - aws_s3_bucket_cors_configuration: allow ALB domain

### SSM Parameter Store
After RDS is created, store these parameters:
- `aws_ssm_parameter` — /lks/app/db_host       (SecureString)
- `aws_ssm_parameter` — /lks/app/db_password    (SecureString)
- `aws_ssm_parameter` — /lks/app/sqs_url        (String)
- `aws_ssm_parameter` — /lks/app/dynamodb_table (String)

### CloudWatch
- `aws_cloudwatch_log_group` x3 — /ecs/lks-fe-app, /ecs/lks-api-app, /ecs/lks-analytics-app
  - retention_in_days: 7
- `aws_cloudwatch_log_group` x4 — /ecs/lks-prometheus, /ecs/lks-grafana, /ecs/lks-loki, /ecs/lks-alertmanager
  - retention_in_days: 7
- `aws_cloudwatch_metric_alarm` — ECS CPU > 80%
- `aws_cloudwatch_metric_alarm` — ALB 5xx rate > 5%
- `aws_sns_topic` — lks-alerts
- `aws_sns_topic_subscription` — email endpoint

## Outputs

| Output | Description |
|---|---|
| `rds_endpoint` | Store in SSM /lks/app/db_host |
| `sqs_queue_url` | Store in SSM /lks/app/sqs_url |
| `dlq_url` | Dead-letter queue URL |
| `dynamodb_table_name` | Table name: lks-sessions |
| `tfstate_bucket_name` | Terraform state bucket |
| `assets_bucket_name` | Application assets bucket |
