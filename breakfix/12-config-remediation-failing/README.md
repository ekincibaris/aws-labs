# 12 · Config flags open SSH, but auto-remediation never fixes it

| | |
|---|---|
| **SOA-C03 domain** | Domain 4: Security and Compliance. Task 4.2, skill 4.2.5 (remediate findings from AWS Config), and Task 4.1, skill 4.1.5 (continuous monitoring). Also Domain 1, skill 1.2.3 (Systems Manager Automation runbooks) |
| **Difficulty** | Hard |
| **Cost** | ≈ €0.00 per hour, plus a few cents of AWS Config charges in total |
| **Time** | 45–60 minutes |

## What gets deployed

- An **AWS Config** recorder (security groups only) with a delivery channel and an S3 bucket. This part is optional; see below.
- The Config managed rule `config-lab-restricted-ssh` (`INCOMING_SSH_DISABLED`)
- **Automatic remediation** on that rule with the AWS runbook `AWS-DisableIncomingSSHOnPort22` and the IAM role `config-lab-remediation-role`
- A VPC with the security group `config-lab-bastion-sg`, which someone opened to `0.0.0.0/0` on port 22 "temporarily"

## Before you deploy

AWS Config allows **one recorder per account and Region**. Check whether you already have one in eu-central-1:

```bash
aws configservice describe-configuration-recorders --region eu-central-1
```

If that returns a recorder, it must record `AWS::EC2::SecurityGroup` (or all resource types). Then deploy with `-var create_config_recorder=false` so the lab uses your recorder instead of creating a second one.

## Deploy

```bash
cd breakfix/12-config-remediation-failing
terraform init
terraform apply
```

Wait 10–15 minutes. Config has to record the security group, evaluate the rule and try the remediation.

## Incident ticket

> **INC-1212 · Priority P1 (security) · World-open SSH is not auto-remediated**
>
> **Reported by:** Security team
>
> AWS Config flagged `config-lab-bastion-sg` as **NON_COMPLIANT** with our rule `config-lab-restricted-ssh`. Someone opened SSH (port 22) to `0.0.0.0/0` "temporarily". The rule has **automatic remediation**, which is supposed to revoke rules like this within minutes. The security group is still open, and the rule still lists it as non-compliant. Find out why the remediation doesn't work and fix it. The security group must be fixed **by the automation**, not by hand.

## Allowed tools

- **Console:** AWS Config (Rules → `config-lab-restricted-ssh` → resources in scope, remediation action status, **Remediate** button), Systems Manager → **Automation** → executions and step details, IAM (roles, trust relationships), CloudTrail → Event history
- **CLI:** `aws configservice get-compliance-details-by-config-rule`, `describe-remediation-configurations`, `describe-remediation-execution-status` and `start-remediation-execution`; `aws ssm describe-automation-executions` and `get-automation-execution`; `aws iam get-role`
- **CloudWatch:** not the main tool here. The evidence is in Config and Systems Manager.

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- A remediation execution for `config-lab-bastion-sg` shows **SUCCEEDED**, and the security group no longer allows `0.0.0.0/0` on port 22. The runbook removed the rule; you didn't.
- The rule shows the security group as **COMPLIANT** after it re-evaluates.
- The code matches reality: `terraform plan` shows no changes. Think about what Terraform wants to do with a rule the automation removed.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| AWS Config configuration items | $0.003 each. Only security groups are recorded, so expect 5–20 items: the lab's and your other VPCs' security groups |
| AWS Config rule evaluations | $0.001 each, a handful |
| Systems Manager Automation, S3 | fractions of a cent |
| **Total** | **≈ €0.00/h, a few cents in total** |

> **Destroy reminder:** run `terraform destroy` when you're done. It stops and deletes the recorder (if the lab created it), the rule, the remediation and the bucket. If you used your own recorder, it stays as it was.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
