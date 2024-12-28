# ScheduledTask

- A Node.js Lambda function triggered by EventBridge Scheduler
- Infrastructure as code using Terraform
- CI/CD pipeline with GitHub Actions
- State management using S3 backend
- CloudWatch logging for monitoring


Prerequisites
- Deployment role need to have permission to manage resources

- S3 bucket: scheduled-task-state-bucket
this is the terraform state bucket and it is used to store the terraform state file. it is created manually in the aws console before running terraform apply.

