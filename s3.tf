resource "aws_s3_bucket" "cloudwatch_firehose" {
  bucket = var.s3_bucket_firehose
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudwatch_firehose" {
  bucket   = aws_s3_bucket.cloudwatch_firehose.bucket
  rule {
    id = "expirelogs"

    expiration {
      days = 30
    }

    status = "Enabled"
  }
}

resource "aws_sqs_queue" "metrics_stream" {
  name  = var.s3_bucket_firehose

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:*:*:${var.s3_bucket_firehose}",
      "Condition": {
        "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.cloudwatch_firehose.arn}" }
      }
    }
  ]
}
POLICY
}

resource "aws_ssm_parameter" "metrics_stream" {
  name = "/mts-dev-usw2/vector/metrics-stream-sqs-queue-url"
  type = "String"
  value = aws_sqs_queue.metrics_stream.url
}

resource "aws_ssm_parameter" "metrics_stream_region" {
  name = "/mts-dev-usw2/vector/metrics-stream-region"
  type = "String"
  value = data.aws_region.current.name
}

resource "aws_s3_bucket_notification" "metrics_stream" {
  bucket = aws_s3_bucket.cloudwatch_firehose.id

  queue {
    queue_arn     = aws_sqs_queue.metrics_stream.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "metrics/"
    filter_suffix = ".gz"
  }
}