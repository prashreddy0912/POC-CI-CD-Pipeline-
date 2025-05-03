# ECS Deployment Pipeline using GitHub as Source (Terraform)

#---------------------------
# Variables
#---------------------------
variable "region"              { default = "us-east-1" }
variable "s3_bucket"           { default = "nodejs-ecs-app-artifacts" }
variable "github_owner"        { default = "prashreddy0912" }
variable "github_repo"         { default = "POC-CI-CD-Pipeline-" }
variable "github_branch"       { default = "main" }
variable "github_oauth_token"  { sensitive = true }
variable "ecr_repo_name"       { default = "my-app-task" }
variable "ecs_cluster"         { default = "node-ecs-cluster" }
variable "ecs_service"         { default = "ecs-test"}

#---------------------------
# ECR Repository
#---------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

#---------------------------
# S3 Bucket for Artifacts
#---------------------------
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = var.s3_bucket
}

resource "aws_s3_bucket_ownership_controls" "codepipeline_bucket_ownership" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.codepipeline_bucket_ownership]
  bucket = aws_s3_bucket.codepipeline_bucket.id
  acl    = "private"
}

#---------------------------
# IAM Roles
#---------------------------
resource "aws_iam_role" "codebuild_role_test" {
  name = "codebuild-ecs-role-test"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr" {
  role       = aws_iam_role.codebuild_role_test.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "codebuild_ecs" {
  role       = aws_iam_role.codebuild_role_test.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

# Add specific permissions for CodeBuild to access S3
resource "aws_iam_policy" "codebuild_s3" {
  name        = "codebuild-s3-policy"
  description = "Policy for CodeBuild to access S3"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      Resource = [
        aws_s3_bucket.codepipeline_bucket.arn,
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  role       = aws_iam_role.codebuild_role_test.name
  policy_arn = aws_iam_policy.codebuild_s3.arn
}

resource "aws_iam_role" "pipeline_role" {
  name = "codepipeline-ecs-role-test"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "pipeline_full" {
  role       = aws_iam_role.pipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

resource "aws_iam_role_policy" "s3_access" {
  role = aws_iam_role.pipeline_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}
 
resource "aws_iam_role_policy_attachment" "codestar_access" {
  role       = aws_iam_role.pipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeStarFullAccess"
}

#---------------------------
# CodeBuild Project for Docker Build & Push
#---------------------------
resource "aws_codebuild_project" "build_app" {
  name         = "ecs-app-build"
  service_role = aws_iam_role.codebuild_role_test.arn

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true  # Required for Docker operations
    
    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = "${aws_ecr_repository.app_repo.repository_url}"
    }
    
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    
    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.ecr_repo_name
    }
  }
}

#---------------------------
# CodePipeline with GitHub Source, Docker build and ECS Deploy
#---------------------------
resource "aws_codepipeline" "ecs_pipeline" {
  name     = "ecs-github-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      version          = "1"
      name             = "BuildAndPushToECR"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.build_app.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      version         = "1"
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      configuration = {
        ClusterName = var.ecs_cluster
        ServiceName = var.ecs_service
        FileName    = "imagedefinitions.json"
      }
    }
  }
}