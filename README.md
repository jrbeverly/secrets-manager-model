# Secrets Manager Model

> [!WARNING]
> **AI-authored:** This change was autonomously planned and implemented by an AI software factory from a human-authored specification, with possible subsequent human review or modification.

Tests a Secrets Manager authorization model: tag-gated consumer reads, a VPC sync Lambda (stubbed Keeper source) that writes the secret and an SSM pointer through a NAT with a fixed EIP, and a per-scope KMS CMK used as a kill switch.

```sh
terraform -chdir=infra init
terraform -chdir=infra apply
bash verify.sh
terraform -chdir=infra destroy
```

## Notes

- idea; larger system for syncing secrets + managing provisioning
- potentially operate from a restricted account/session
- push secrets/config into target accounts using tags + restrictive flows
- needs more research; interesting area for a broader AWS secrets-management system
- similar concepts could apply to artifact management/distribution
- current scope; narrow experiment in the space
- Factory did a solid job overall
