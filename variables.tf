variable "aws_region" {
  type    = string
  default = "eu-central-1"
}
variable "environment" {
  type    = string
  default = "umw"
}
variable "encryption_enabled" {
  type        = bool
  default     = true
  description = "When set to 'true' the resource will have AES256 encryption enabled by default"
}