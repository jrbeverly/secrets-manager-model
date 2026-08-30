resource "aws_secretsmanager_secret" "payments_db" {
  name       = local.secret_name
  kms_key_id = aws_kms_key.payments.arn

  tags = local.secret_tag
}

resource "aws_secretsmanager_secret_policy" "payments_db" {
  secret_arn = aws_secretsmanager_secret.payments_db.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.consumer.arn
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
        Condition = {
          StringEquals = { "secretsmanager:ResourceTag/acme:secret/payments" = "true" }
        }
      },
    ]
  })
}
