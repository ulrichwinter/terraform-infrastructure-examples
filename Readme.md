# Terraform stack template.

## Setup
* Create / adapt environment backend config e.g. `umw.backend`
* Manually create the S3 bucket using aws console.
* Manually create the DynamoDB table.
  Specify a Partition key named `LockID` of type String.
* Execute `ENV=umw make init`
* Execute `ENV=umw make apply`