# ScheduledTask
Using AWS scheduler to trigger lambda task on CRON base.

Prerequisites
- Deployment role need to have permission to manage resources

- S3 bucket: scheduled-task-state-bucket
this is the terraform state bucket and it is used to store the terraform state file. it is created manually in the aws console before running terraform apply.

