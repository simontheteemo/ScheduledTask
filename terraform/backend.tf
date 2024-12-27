terraform {
  backend "s3" {
    bucket = "scheduled-task-state-bucket"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}