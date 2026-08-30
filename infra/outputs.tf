output "sync_egress_ip" {
  value = aws_eip.nat.public_ip
}

output "cmk_arn" {
  value = aws_kms_key.payments.arn
}

output "sync_role_arn" {
  value = aws_iam_role.sync.arn
}

output "consumer_role_arn" {
  value = aws_iam_role.consumer.arn
}
