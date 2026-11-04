# Solution · 12 Config flags open SSH, but auto-remediation never fixes it

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The remediation role `config-lab-remediation-role` has the **wrong trust policy**. It allows `config.amazonaws.com` to assume it, but the service that actually uses the role is **Systems Manager Automation** (`ssm.amazonaws.com`).

How Config remediation works:

1. The rule `config-lab-restricted-ssh` marks `config-lab-bastion-sg` as `NON_COMPLIANT`.
2. Because remediation is automatic, Config starts the SSM Automation runbook `AWS-DisableIncomingSSHOnPort22`, passing the security group ID (`RESOURCE_ID`) and `AutomationAssumeRole = config-lab-remediation-role`.
3. **Automation** tries to assume that role so it can call `ec2:RevokeSecurityGroupIngress`. The trust policy doesn't allow `ssm.amazonaws.com`, so the execution fails right away with *The defined assume role is unable to be assumed*.
4. Config retries 3 times (`maximum_automatic_attempts`), then gives up. The security group stays open.

The role's **permissions** were fine all along (`ec2:DescribeSecurityGroups`, `ec2:RevokeSecurityGroupIngress`). Only the trust policy was wrong.

## Evidence

```bash
aws configservice describe-remediation-execution-status --config-rule-name config-lab-restricted-ssh \
  --query 'RemediationExecutionStatuses[].[ResourceKey.ResourceId,State,StepDetails[0].ErrorMessage]'
# [sg-..., "FAILED", "..."]

aws ssm describe-automation-executions \
  --filters Key=DocumentNamePrefix,Values=AWS-DisableIncomingSSHOnPort22 \
  --query 'AutomationExecutionMetadataList[].[AutomationExecutionId,AutomationExecutionStatus,FailureMessage]' --output table
# Failed   The defined assume role is unable to be assumed.

aws iam get-role --role-name config-lab-remediation-role --query 'Role.AssumeRolePolicyDocument.Statement[].Principal'
# [{"Service": "config.amazonaws.com"}]
```

## Fix

**Terraform.** In `iam.tf`, trust the service that uses the role:

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect    = "Allow"
    Principal = { Service = "ssm.amazonaws.com" }
    Action    = "sts:AssumeRole"
    Condition = {
      StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
    }
  }]
})
```

The `aws:SourceAccount` condition is optional hardening: only Automation executions in your own account can use the role. Run `terraform apply`.

**Run the remediation again.** Automatic attempts are used up, so start one yourself:

```bash
SG=$(terraform output -raw security_group_id)
aws configservice start-remediation-execution --config-rule-name config-lab-restricted-ssh \
  --resource-keys resourceType=AWS::EC2::SecurityGroup,resourceId="$SG"

aws configservice describe-remediation-execution-status --config-rule-name config-lab-restricted-ssh \
  --query 'RemediationExecutionStatuses[].State'
# "SUCCEEDED" after a minute
```

In the console: Config → Rules → `config-lab-restricted-ssh` → select the resource → **Remediate**.

The runbook removes the port 22 rule. Config records the change and re-evaluates, and the security group becomes `COMPLIANT`.

**Make the code match.** `terraform plan` now wants to **re-create** `aws_vpc_security_group_ingress_rule.bastion_ssh_anywhere`, because the automation deleted something Terraform manages. If you applied that, Terraform and Config would fight forever. Delete the "TEMPORARY" rule from `security.tf`. After that, `terraform plan` shows no changes.

## Detect it earlier in production

- **Alert on failed remediations.** An EventBridge rule on `EC2 Automation Execution Status-change Notification` (source `aws.ssm`) with status `Failed` or `TimedOut` sends the failure to SNS. You hear about it the first time, not when the auditors do.
- **Alert on long-lived non-compliance.** EventBridge `Config Rules Compliance Change` events with `NON_COMPLIANT`, plus a daily report of resources that stay non-compliant for more than an hour, catch any remediation that silently stops working.
- **Security Hub** shows the same finding (EC2.13 / restricted SSH) next to your other controls, if you use it.

## Prevent it with automation

- **Test the remediation itself.** After deploying the rule and its remediation, a pipeline step creates a throw-away non-compliant security group and waits for `SUCCEEDED`. A remediation that has never run is just a hope.
- **Use tested building blocks.** Conformance packs and AWS sample templates come with remediation roles that already trust `ssm.amazonaws.com`. Create remediation roles from one shared module instead of by hand.
- **Stop the violation before it exists.** Policy-as-code in CI (rejecting `0.0.0.0/0` on port 22 in Terraform), AWS Firewall Manager security group policies, or proactive Config evaluation / CloudFormation Hooks block the change at deploy time. Session Manager makes port 22 unnecessary in the first place.

## Exam takeaways

- Config rules: **managed**, **custom Lambda** and **custom Guard** rules, triggered by **configuration changes** or **periodically**. One recorder per Region; delivery to S3 and optionally SNS.
- Remediation = an **SSM Automation runbook**, manual or automatic with retries. Parameters can be static or `RESOURCE_ID`. The `AutomationAssumeRole` must **trust `ssm.amazonaws.com`** and have the permissions the runbook needs.
- **Trust policy** (who may assume a role) and **permissions policy** (what the role may do) are separate. "Unable to be assumed" points to the first; "not authorized to perform" points to the second.
- Auto-remediation and IaC have to agree. Otherwise every apply re-creates the violation.
