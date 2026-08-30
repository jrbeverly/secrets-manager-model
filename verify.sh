#!/usr/bin/env bash
set -euo pipefail

REGION=us-east-1
OUT=$(mktemp)
SECRET_NAME=/acme/payments/production/database
SSM_NAME=/acme/secrets/payments/database

pass() { printf "PASS  %s\n" "$*"; }
fail() { printf "FAIL  %s\n" "$*"; }

EIP=$(terraform -chdir=infra output -raw sync_egress_ip)
CMK_ARN=$(terraform -chdir=infra output -raw cmk_arn)
CONSUMER_ROLE=$(terraform -chdir=infra output -raw consumer_role_arn)
SYNC_ROLE=$(terraform -chdir=infra output -raw sync_role_arn)

assume() {
  aws sts assume-role --role-arn "$1" --role-session-name "$2" \
    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
    --output text
}

# 1. Sync invoke / egress IP match
aws lambda invoke \
  --function-name acme-keeper-sync \
  --region "$REGION" \
  "$OUT" >/dev/null
EGRESS_IP=$(python3 -c "import json; print(json.load(open('$OUT'))['egress_ip'])")
[ "$EGRESS_IP" = "$EIP" ] \
  && pass "egress_ip=$EGRESS_IP matches EIP" \
  || fail "egress_ip=$EGRESS_IP != EIP=$EIP"

# 2. Secret shape: KMS key and tag
GOT_KMS=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" \
  --query KmsKeyId --output text)
GOT_TAG=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" \
  --query "Tags[?Key=='acme:secret/payments'].Value | [0]" --output text)
[ "$GOT_KMS" = "$CMK_ARN" ] \
  && pass "secret kms=$CMK_ARN" \
  || fail "secret kms mismatch got=$GOT_KMS"
[ "$GOT_TAG" = "true" ] \
  && pass "secret tag acme:secret/payments=true" \
  || fail "secret tag missing or wrong"

# 3. SSM resolve -> secret ARN
SECRET_ARN=$(aws ssm get-parameter --name "$SSM_NAME" --region "$REGION" \
  --query Parameter.Value --output text)
[ -n "$SECRET_ARN" ] \
  && pass "ssm $SSM_NAME -> $SECRET_ARN" \
  || fail "ssm resolve empty"

# 4. Authorized read (consumer role)
read -r C_AK C_SK C_ST <<< "$(assume "$CONSUMER_ROLE" verify-consumer)"
if AWS_ACCESS_KEY_ID="$C_AK" AWS_SECRET_ACCESS_KEY="$C_SK" AWS_SESSION_TOKEN="$C_ST" \
   aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  pass "authorized read (consumer role) allowed"
else
  fail "authorized read (consumer role) denied"
fi

# 5. Negative read (sync role — no GetSecretValue in identity policy)
read -r S_AK S_SK S_ST <<< "$(assume "$SYNC_ROLE" verify-negative)"
if AWS_ACCESS_KEY_ID="$S_AK" AWS_SECRET_ACCESS_KEY="$S_SK" AWS_SESSION_TOKEN="$S_ST" \
   aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  fail "negative read (sync role) should be denied"
else
  pass "negative read (sync role) correctly denied"
fi

# 6. KMS kill switch: disable -> blocked -> enable -> restored
aws kms disable-key --key-id "$CMK_ARN" --region "$REGION"
if AWS_ACCESS_KEY_ID="$C_AK" AWS_SECRET_ACCESS_KEY="$C_SK" AWS_SESSION_TOKEN="$C_ST" \
   aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  fail "read after CMK disable should be blocked"
else
  pass "read blocked after CMK disable"
fi

aws kms enable-key --key-id "$CMK_ARN" --region "$REGION"
if AWS_ACCESS_KEY_ID="$C_AK" AWS_SECRET_ACCESS_KEY="$C_SK" AWS_SESSION_TOKEN="$C_ST" \
   aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  pass "read restored after CMK enable"
else
  fail "read failed after CMK enable"
fi
