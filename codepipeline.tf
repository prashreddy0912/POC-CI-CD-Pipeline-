# resource "aws_codepipeline" "app_pipeline" {
#   name     = "${var.app_name}-pipeline"
#   role_arn = aws_iam_role.codebuild_role.arn

#   artifact_store {
#     location = aws_s3_bucket.pipeline_artifacts.bucket
#     type     = "S3"
#   }

#   stage {
#     name = "Source"
#     action {
#       name             = "Source"
#       category         = "Source"
#       owner            = "AWS"
#       provider         = "CodeStarSourceConnection"
#       version          = "1"
#       output_artifacts = ["source_output"]
#       configuration = {
#         ConnectionArn  = "arn:aws:codeconnections:us-west-2:390402565417:connection/a9879025-873c-4ee0-954a-8c1e87d1025b"
#         FullRepositoryId = "prashreddy0912/POC-CI-CD-Pipeline-"
#         BranchName       = "main"
#       }
#     }
#   }

#   stage {
#     name = "Build"
#     action {
#       name             = "Build"
#       category         = "Build"
#       owner            = "AWS"
#       provider         = "CodeBuild"
#       version          = "1"
#       input_artifacts  = ["source_output"]
#       output_artifacts = ["build_output"]
#       configuration = {
#         ProjectName = aws_codebuild_project.build.name
#       }
#     }
#   }
# } 
