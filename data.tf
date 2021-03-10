data "aws_caller_identity" "current" {}

data "archive_file" "lambda-sqs-to-s3" {
  type        = "zip"
  output_path = "${path.module}/lambda-code.zip"
  source_dir  = "${path.module}/code"
}