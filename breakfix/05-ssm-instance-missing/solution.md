# Solution · 05 Instance missing from Systems Manager

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The three interface endpoints were created with **private DNS disabled** (`private_dns_enabled = false`). That is also the Terraform default, which makes this a very common mistake. In the console the box is ticked by default.

- SSM Agent connects to the Regional names `ssm.eu-central-1.amazonaws.com`, `ssmmessages.eu-central-1.amazonaws.com` and `ec2messages.eu-central-1.amazonaws.com`.
- With private DNS enabled, AWS adds a private hosted zone to the VPC, and those names resolve to the endpoints' private IPs (`10.5.1.x`).
- With private DNS disabled, the VPC resolver returns the services' **public** IPs. The subnet has no route to the internet, and the instance security group only allows HTTPS to `10.5.0.0/16`. Every connection attempt times out, the agent never registers, and the instance never appears in Fleet Manager.

The endpoints themselves were fine (`Available`, correct security group, correct subnet). Nothing ever sent traffic to them.

## Evidence

```bash
ID=$(terraform output -raw instance_id)

aws ssm describe-instance-information --filters Key=InstanceIds,Values="$ID"
# "InstanceInformationList": []

aws ec2 describe-vpc-endpoints --filters Name=tag:Lab,Values=breakfix/05-ssm-instance-missing \
  --query 'VpcEndpoints[].[ServiceName,State,PrivateDnsEnabled]' --output table
# com.amazonaws.eu-central-1.ssm   available   False   (same for ssmmessages and ec2messages)
```

From a CloudShell VPC environment in `ssm-lab-private`:

```bash
getent hosts ssm.eu-central-1.amazonaws.com
# public AWS addresses: not inside 10.5.0.0/16
```

`AWSSupport-TroubleshootManagedInstance` passes all its checks. Reachability Analyzer from the instance to an endpoint network interface on TCP 443 shows the path is **reachable**. Both results tell you the problem isn't routing, security groups or IAM. That leaves name resolution.

## Fix

**Terraform.** In `endpoints.tf`, set `private_dns_enabled = true` and run `terraform apply`. The endpoints are modified in place. The VPC already has `enable_dns_support` and `enable_dns_hostnames` turned on, and private DNS needs both.

**Console.** VPC → **Endpoints** → select an endpoint → **Actions** → **Modify private DNS name** → **Enable for this endpoint**. Do it for all three.

**CLI.**

```bash
for id in $(terraform output -json vpc_endpoint_ids | jq -r '.[]'); do
  aws ec2 modify-vpc-endpoint --vpc-endpoint-id "$id" --private-dns-enabled
done
```

The agent retries with a growing back-off. The instance usually shows up within 5–10 minutes. `aws ec2 reboot-instances --instance-ids "$ID"` makes it happen sooner. Fix the code as well, or the next apply turns private DNS off again.

## Detect it earlier in production

- **AWS Config managed rule `ec2-instance-managed-by-systems-manager`** marks every instance that isn't managed by Systems Manager as NON_COMPLIANT, so you find out within minutes instead of on patch day.
- **The Systems Manager console** lists **unmanaged** EC2 instances next to managed nodes. Review it, or alarm on the count.
- **Event-driven check:** an EventBridge rule on `EC2 Instance State-change Notification` (`running`) starts a small Lambda function or Automation runbook. Fifteen minutes later it calls `describe-instance-information` and alerts if the instance isn't `Online`.

## Prevent it with automation

- **A shared endpoints module** that always sets `private_dns_enabled = true` for interface endpoints of AWS services. A `validation` block or a `terraform test` assertion keeps it that way.
- **Policy-as-code in CI** (OPA/Conftest or a custom Checkov check) that rejects `aws_vpc_endpoint` resources of type `Interface` without private DNS.
- **A launch smoke test.** The pipeline that creates the instance waits for `PingStatus = Online` before it reports success.

## Exam takeaways

- A managed node needs four things: **SSM Agent** running, **permissions** (an instance profile with `AmazonSSMManagedInstanceCore`, or Default Host Management Configuration), **network access** to the `ssm`, `ssmmessages` (and older agents: `ec2messages`) endpoints, and a reachable **instance metadata** service.
- Without internet access you need **interface endpoints with private DNS**, which in turn need VPC `enableDnsSupport` and `enableDnsHostnames`. The endpoint security group must allow 443 from the instances.
- **Gateway endpoints** (S3, DynamoDB) work through route tables and prefix lists. **Interface endpoints** (almost every other service) work through ENIs and DNS.
- `AWSSupport-TroubleshootManagedInstance` and **Reachability Analyzer** are the AWS tools for "why isn't this instance managed?". Know what each one checks, and what it doesn't.
