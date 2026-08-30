locals {
  region        = "us-east-1"
  secret_name   = "/acme/payments/production/database"
  secret_tag    = { "acme:secret/payments" = "true" }
  ssm_name      = "/acme/secrets/payments/database"
  sync_role     = "acme-keeper-sync-role"
  consumer_role = "acme-payments-consumer-role"
  kms_alias     = "alias/acme-secrets-payments"
}
