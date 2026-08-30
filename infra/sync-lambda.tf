data "archive_file" "sync" {
  type        = "zip"
  source_dir  = "${path.module}/../sync"
  output_path = "${path.module}/sync.zip"
}

resource "aws_security_group" "sync_lambda" {
  name   = "acme-keeper-sync-lambda"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lambda_function" "sync" {
  function_name    = "acme-keeper-sync"
  filename         = data.archive_file.sync.output_path
  source_code_hash = data.archive_file.sync.output_base64sha256
  role             = aws_iam_role.sync.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  depends_on       = [aws_iam_role_policy_attachment.sync_vpc]

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.sync_lambda.id]
  }

  environment {
    variables = {
      SECRET_NAME = local.secret_name
      SSM_NAME    = local.ssm_name
      KMS_ALIAS   = local.kms_alias
    }
  }
}
