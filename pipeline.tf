
resource "aws_ecr_repository" "app" {
  name = "my-app-task-test"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicPowerUser"
}

resource "aws_iam_policy" "codepipeline_s3_access" {
  name = "codepipeline-s3-access-policy"
 
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
          "arn:aws:s3:::nodejs-ecs-app-artifacts",
          "arn:aws:s3:::nodejs-ecs-app-artifacts/*"
        ]
      }
    ]
  })
}
 
resource "aws_iam_policy_attachment" "attach_s3_access_to_pipeline" {
  name       = "codepipeline-s3-access"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = aws_iam_policy.codepipeline_s3_access.arn
}

resource "aws_iam_policy" "codepipeline_codebuild_access" {
  name = "codepipeline-codebuild-access"
 
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ],
        Resource = "arn:aws:codebuild:us-east-1:390402565417:project/ecs-app-build"
      }
    ]
  })
}
 
resource "aws_iam_policy_attachment" "attach_codebuild_access_to_pipeline" {
  name       = "codepipeline-codebuild-access"
  roles = [aws_iam_role.codepipeline_role.name]
  policy_arn = aws_iam_policy.codepipeline_codebuild_access.arn
}

resource "aws_iam_policy" "codepipeline_ecs_access" {
  name = "codepipeline-ecs-access"
 
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ],
        Resource = "*"
      }
    ]
  })
}
 
resource "aws_iam_policy_attachment" "attach_ecs_access_to_pipeline" {
  name       = "codepipeline-ecs-access"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = aws_iam_policy.codepipeline_ecs_access.arn
}
 

resource "aws_ecs_cluster" "main" {
  name = "node-ecs-cluster"
}
// filepath: c:\Users\15769\Desktop\AWS CICD\POC-CI-CD-Pipeline--1\pipeline.tf
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "my-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = jsonencode([
    {
      name      = "my-app-task",
      image     = "${aws_ecr_repository.app.repository_url}:latest",
      essential = true,
      portMappings = [
        {
          containerPort = 3000,
          protocol      = "tcp"
        }
      ]
    }
  ])
}
# resource "aws_ecs_task_definition" "app-task" {
#   family                   = "my-app-task"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
#   container_definitions    = jsonencode([
#     {
#       name      = "my-app-task",
#       image     = "${aws_ecr_repository.app.repository_url}:latest",
#       essential = true,
#       portMappings = [
#         {
#           containerPort = 3000,
#           protocol      = "tcp"
#         }
#       ]
#     }
#   ])
# }
# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "ecsTaskExecutionRole"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "ecs-tasks.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }


resource "aws_ecs_service" "my-app-test" {
  name            = "my-app-test"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-0dcad7a2a716631be", "subnet-0d1f057476b350364"]
    assign_public_ip = true
    security_groups  = ["sg-0e10486d3b9954656"]
  }

  # load_balancer {
  #   target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:390402565417:targetgroup/my-target-group/1234567890abcdef"
  #   container_name   = "my-app-task"
  #   container_port   = 3000
  # }

  depends_on = [aws_ecr_repository.app]
}

resource "aws_codepipeline" "github_pipeline" {
  name     = "github-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  execution_mode = "QUEUED"
  pipeline_type  = "V2"

  artifact_store {
    location = var.s3_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "prashreddy0912"
        Repo       = "POC-CI-CD-Pipeline-"
        Branch     = "main"
        OAuthToken = var.github_oauth_token
        PollForSourceChanges = true
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = "ecs-app-build"
        BuildspecOverride = "buildspec.yaml"
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.my-app-test.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}