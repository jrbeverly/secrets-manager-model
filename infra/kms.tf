data "aws_caller_identity" "current" {}

resource "aws_kms_key" "payments" {
  description             = "Payments scope CMK"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Root"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "SyncRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.sync.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
      {
        Sid    = "ConsumerRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.consumer.arn
        }
        Action   = "kms:Decrypt"
        Resource = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "payments" {
  name          = local.kms_alias
  target_key_id = aws_kms_key.payments.key_id
}
