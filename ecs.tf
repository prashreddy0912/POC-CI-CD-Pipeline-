# ECS + CodeBuild Terraform Setup

# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "node-ecs-cluster"
}

# 2. ECR Repository
resource "aws_ecr_repository" "app" {
  name = "my-app-task"
}

# 3. IAM Roles
# resource "aws_iam_role" "codebuild_role" {
#   name = "codebuild-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Service = "codebuild.amazonaws.com"
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

resource "aws_iam_role_policy_attachment" "codebuild_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}
resource "aws_iam_role" "ecs_execution" {
  name               = "ecsTaskExecutionRole_update"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. CodeBuild Project
resource "aws_codebuild_project" "app-build-test" {
  name         = "app-build-test"
  service_role = aws_iam_role.codebuild_role.arn

  source {
    type     = "GITHUB"
    location = "https://github.com/prashreddy0912/POC-CI-CD-Pipeline-.git"
    buildspec = file("buildspec.yaml")
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "REPO_URI"
      value = aws_ecr_repository.app.repository_url
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }
}

# 5. ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "my-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "my-app-task",
    image     = "${aws_ecr_repository.app.repository_url}:latest",
    essential = true,
    portMappings = [{
      containerPort = 3000,
      protocol      = "tcp"
    }]
  }])
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-task"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# 6. Security Group (example, allows port 3000)
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg-task"
  description = "Allow traffic to ECS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# 7. ALB Resources
resource "aws_lb" "app_alb" {
  name               = "app-alb-task"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# 8. ECS Service
resource "aws_ecs_service" "my-app-test" {
  name            = "my-app-test"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "my-app-task"
    container_port   = 3000
  }
  depends_on = [
    aws_lb_listener.app_listener
  ]
}