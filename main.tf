provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    region = "eu-central-1"
    # enable SSE-S3 for tfstate bucket
    encrypt = true
  }
}