module "sns-dlq-topic" {
  source  = "genstackio/sns/aws"
  version = "0.1.0"
  name    = local.name
}

module "sqs-dlq-queue" {
  source  = "genstackio/sqs/aws"
  version = "0.1.0"
  name    = local.name
}

module "sns-dlq-topic-policy" {
  source  = "genstackio/sns/aws//modules/topic-policy"
  version = "0.1.0"
  topic   = module.sns-dlq-topic.arn
  sources = ["arn:*:*:*:${data.aws_caller_identity.current.account_id}:*"]
}

module "sqs-dlq-policy" {
  source   = "genstackio/sqs/aws//modules/policy"
  version  = "0.1.0"
  policies = {
    dlq = {
      arn     = module.sqs-dlq-queue.arn
      id      = module.sqs-dlq-queue.id
      sources = [module.sns-dlq-topic.arn]
    }
  }
}

resource "aws_s3_bucket" "dlq" {
  bucket = var.bucket_name
  tags   = {Env = var.env}
}

module "lambda-sqs-to-s3" {
  source      = "genstackio/lambda/aws"
  version     = "0.1.0"
  file        = data.archive_file.lambda-sqs-to-s3.output_path
  name        = "${local.name}-sqs-to-s3"
  handler     = "index.handler"
  variables   = {
    S3_BUCKET_ID         = aws_s3_bucket.dlq.id
    S3_BUCKET_KEY_PREFIX = var.bucket_key_prefix
  }
  policy_statements = [
    {
      actions   = ["s3:PutObject"]
      resources = [aws_s3_bucket.dlq.arn]
      effect    = "Allow"
    },
  ]
}

module "lambda-event-source-mapping" {
  source           = "genstackio/sqs/aws//modules/to-lambda-event-source-mapping"
  version          = "0.1.0"
  queue            = module.sqs-dlq-queue.arn
  lambda_arn       = module.lambda-sqs-to-s3.arn
  lambda_role_name = module.lambda-sqs-to-s3.role_name
}

module "dlq-sns-to-dlq-sqs" {
  source        = "genstackio/sns/aws//modules/sqs-subscriptions"
  version       = "0.1.0"
  subscriptions = {
    local = {
      topic = module.sns-dlq-topic.arn
      queue = module.sqs-dlq-queue.arn
    }
  }
}