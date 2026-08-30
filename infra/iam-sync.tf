resource "aws_iam_role" "sync" {
  name = local.sync_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy" "sync_write" {
  name = "sync-write"
  role = aws_iam_role.sync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:CreateSecret"
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestTag/acme:secret/payments" = "true" }
          StringLike   = { "secretsmanager:Name" = "/acme/payments/*" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:PutSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutResourcePolicy",
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:/acme/payments/*"
        Condition = {
          StringEquals = { "secretsmanager:ResourceTag/acme:secret/payments" = "true" }
        }
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:TagResource"
        Resource = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:/acme/payments/*"
        Condition = {
          "ForAllValues:StringLike" = { "aws:TagKeys" = "acme:secret/*" }
        }
      },
      {
        Effect   = "Allow"
        Action   = "ssm:PutParameter"
        Resource = "arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/acme/secrets/payments/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sync_vpc" {
  role       = aws_iam_role.sync.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
