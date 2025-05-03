variable "aws_region" {
  default = "us-east-1"
}

variable "s3_bucket_name" {
  description = "S3 bucket for storing CodePipeline artifacts"
  type        = string
  default     = "nodejs-ecs-app-artifacts"
}

variable "github_oauth_token" {
  description = "GitHub personal access token with repo access"
  type        = string
  sensitive   = true
  default     = "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"
}
