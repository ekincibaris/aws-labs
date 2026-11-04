# 05 · Instance missing from Systems Manager

| | |
|---|---|
| **SOA-C03 domain** | Domain 3: Deployment, Provisioning, and Automation. Task 3.2, skill 3.2.1 (use AWS services such as Systems Manager to automate operational processes). Also Domain 5, skill 5.1.2 (VPC endpoints) |
| **Difficulty** | Medium |
| **Cost** | ≈ €0.05 per hour |
| **Time** | 30–60 minutes |

## What gets deployed

- An **isolated** VPC: one private subnet, with no internet gateway and no NAT gateway
- Interface VPC endpoints for `ssm`, `ssmmessages` and `ec2messages`, with a security group that allows HTTPS from the VPC
- A t4g.micro instance `ssm-lab-batch` (Amazon Linux 2023, SSM Agent preinstalled) with an instance profile that includes `AmazonSSMManagedInstanceCore`

## Deploy

```bash
cd breakfix/05-ssm-instance-missing
terraform init
terraform apply
```

## Incident ticket

> **INC-6631 · Priority P3 · New private server never shows up in Systems Manager**
>
> **Reported by:** Platform team
>
> We launched `ssm-lab-batch` into our isolated subnet. It has no internet access by design. Systems Manager is supposed to work through the VPC interface endpoints, and all three show as **Available**. The instance has our standard instance profile with `AmazonSSMManagedInstanceCore`, and its status checks are 2/2. But it never appeared in **Fleet Manager**, and **Connect → Session Manager** says the SSM Agent isn't online. We can neither patch it nor log in.

## Allowed tools

- **Console:** Systems Manager (Fleet Manager; Automation → run `AWSSupport-TroubleshootManagedInstance`), EC2, VPC (endpoints, route tables, security groups, **Reachability Analyzer**), **CloudShell** (including a CloudShell **VPC environment**, which is free)
- **CLI:** `aws ssm describe-instance-information`, `aws ec2 describe-vpc-endpoints`, `describe-security-groups` and `describe-route-tables`
- **CloudWatch:** not much help here. Part of the exercise is noticing that an agent that can't connect can't send logs either.

Reachability Analyzer costs $0.10 per analysis.

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- `aws ssm describe-instance-information --filters Key=InstanceIds,Values=$(terraform output -raw instance_id)` shows `PingStatus: Online`.
- You can open a Session Manager shell on `ssm-lab-batch`.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| 3 interface endpoints (1 AZ each) | 3 × $0.012/h = $0.036/h |
| t4g.micro | $0.0096/h |
| 8 GB gp3 root volume | $0.001/h |
| **Total** | **≈ $0.047/h ≈ €0.05/h** |

No public IPv4 address, no NAT gateway.

> **Destroy reminder:** run `terraform destroy` when you're done. Left running, this lab costs about €31 a month, mostly for the endpoints.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
