resource "aws_codebuild_project" "build" {
  name          = "${var.app_name}-build"
  description   = "Build Docker image and push to ECR"
  service_role  = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "REPO_URI"
      value = aws_ecr_repository.app_repo.repository_url
    }
  }

 logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/aws/codebuild/${var.app_name}-build"
      stream_name = "build-log"
    }
  }
  source {
    type     = "GITHUB"
    location = "https://github.com/prashreddy0912/POC-CI-CD-Pipeline-.git"
    buildspec = file("buildspec.yaml")
  }
}
