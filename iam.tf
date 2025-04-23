# resource "aws_iam_role" "codebuild_role" {
#   name = "${var.app_name}-codebuild-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action    = "sts:AssumeRole",
#       Effect    = "Allow",
#       Principal = { Service = "codebuild.amazonaws.com" }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "codebuild_ecr_access" {
#   role       = aws_iam_role.codebuild_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
# }
data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach the AmazonEC2ContainerRegistryPowerUser policy to the CodeBuild role
resource "aws_iam_role_policy_attachment" "codebuild_ecr_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# # Define the EKS node role
# resource "aws_iam_role" "eks_node_role" {
#   name = "eks-node-role"

#   assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json

#   permissions_boundary = "arn:aws:iam::390402565417:policy/YOUR-PERMISSIONS-BOUNDARY"
# }
resource "aws_iam_role" "codebuild_role" {
  name = "nodejs-eks-app-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
# resource "aws_iam_role_policy_attachment" "codepipeline_access" {
#   role       = aws_iam_role.codebuild_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess"
# }

resource "aws_iam_role_policy_attachment" "codebuild_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json

  permissions_boundary = aws_iam_policy.permissions_boundary.arn
}
resource "aws_iam_policy" "permissions_boundary" {
  name        = "YOUR-PERMISSIONS-BOUNDARY"
  description = "Permissions boundary for EKS and related resources"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "*",
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role" "default_eks_node_group" {
  name = "default-eks-node-group"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_policy" "custom_codepipeline_policy" {
  name        = "CustomCodePipelinePolicy"
  description = "Custom policy for CodePipeline access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codepipeline:*",
          "s3:*",
          "cloudwatch:*",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "codepipeline_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.custom_codepipeline_policy.arn
}
