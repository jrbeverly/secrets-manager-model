import json
import os
import urllib.request
import boto3

SECRET_NAME = os.environ["SECRET_NAME"]
SSM_NAME    = os.environ["SSM_NAME"]
KMS_ALIAS   = os.environ["KMS_ALIAS"]

sm  = boto3.client("secretsmanager")
ssm = boto3.client("ssm")

with open("keeper-stub.json") as f:
    KEEPER_RECORD = json.load(f)


def handler(event, context):
    with urllib.request.urlopen("https://checkip.amazonaws.com", timeout=5) as r:
        egress_ip = r.read().decode().strip()
    print(f"egress_ip={egress_ip}")

    secret_value = KEEPER_RECORD["value"]

    try:
        resp = sm.create_secret(
            Name=SECRET_NAME,
            KmsKeyId=KMS_ALIAS,
            SecretString=secret_value,
            Tags=[{"Key": "acme:secret/payments", "Value": "true"}],
        )
        secret_arn = resp["ARN"]
    except sm.exceptions.ResourceExistsException:
        sm.put_secret_value(SecretId=SECRET_NAME, SecretString=secret_value)
        secret_arn = sm.describe_secret(SecretId=SECRET_NAME)["ARN"]

    ssm.put_parameter(
        Name=SSM_NAME,
        Value=secret_arn,
        Type="String",
        Overwrite=True,
    )

    print(f"secret_arn={secret_arn} ssm_name={SSM_NAME}")
    return {"egress_ip": egress_ip, "secret_arn": secret_arn}
