# Activates the AWS Config Recorder and deploys a set of conformance packs.
# The conformance packs as yaml files are taken from the directory "conformance-packs".
# See https://github.com/awslabs/aws-config-rules/tree/master/aws-config-conformance-packs for more.



# Get current region of Terraform stack
data "aws_region" "current" {}

# Get current account number
data "aws_caller_identity" "current" {}

# Retrieves the partition that it resides in
data "aws_partition" "current" {}

# -----------------------------------------------------------
# set up the AWS IAM Role to assign to AWS Config Service
# -----------------------------------------------------------
resource "aws_iam_role" "config_role" {
  name = "awsconfig-example"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "config_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_iam_role_policy_attachment" "read_only_policy_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}

# -----------------------------------------------------------
# set up the AWS Config Recorder
# -----------------------------------------------------------
resource "aws_config_configuration_recorder" "config_recorder" {

  name     = "config_recorder"
  role_arn = aws_iam_role.config_role.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# -----------------------------------------------------------
# Create AWS S3 bucket for AWS Config to record configuration history and snapshots
# -----------------------------------------------------------
resource "aws_s3_bucket" "aws_config_bucket" {
  bucket        = "config-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  acl           = "private"
  force_destroy = true
  dynamic "server_side_encryption_configuration" {
    for_each = var.encryption_enabled ? ["true"] : []

    content {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }
  }
}

# -----------------------------------------------------------
# Define AWS S3 bucket policies
# -----------------------------------------------------------
resource "aws_s3_bucket_policy" "config_logging_policy" {
  bucket = aws_s3_bucket.aws_config_bucket.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBucketAcl",
      "Effect": "Allow",
      "Principal": {
        "Service": [
         "config.amazonaws.com"
        ]
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "${aws_s3_bucket.aws_config_bucket.arn}",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "true"
        }
      }
    },
    {
      "Sid": "AllowConfigWriteAccess",
      "Effect": "Allow",
      "Principal": {
        "Service": [
         "config.amazonaws.com"
        ]
      },
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.aws_config_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        },
        "Bool": {
          "aws:SecureTransport": "true"
        }
      }
    },
    {
      "Sid": "RequireSSL",
      "Effect": "Deny",
      "Principal": {
        "AWS": "*"
      },
      "Action": "s3:*",
      "Resource": "${aws_s3_bucket.aws_config_bucket.arn}/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY
}

# -----------------------------------------------------------
# Set up Delivery channel resource and bucket location to specify configuration history location.
# -----------------------------------------------------------
resource "aws_config_delivery_channel" "config_channel" {
  s3_bucket_name = aws_s3_bucket.aws_config_bucket.id
  depends_on     = [aws_config_configuration_recorder.config_recorder]
}

# -----------------------------------------------------------
# Enable AWS Config Recorder
# -----------------------------------------------------------
resource "aws_config_configuration_recorder_status" "config_recorder_status" {
  name       = aws_config_configuration_recorder.config_recorder.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.config_channel]
}

# -----------------------------------------------------------
# set up the Conformance Pack
# -----------------------------------------------------------
resource "aws_config_conformance_pack" "this" {
  for_each = fileset("${path.module}/conformance-packs", "Operational-Best-Practices-for-*.yaml")

  name = trimsuffix(basename(each.value), ".yaml")

  template_body = file("${path.module}/conformance-packs/${each.value}")

  depends_on = [aws_config_configuration_recorder.config_recorder]
}