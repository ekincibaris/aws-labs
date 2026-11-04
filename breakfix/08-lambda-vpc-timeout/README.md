# 08 · Lambda times out since it moved into the VPC

| | |
|---|---|
| **SOA-C03 domain** | Domain 5: Networking and Content Delivery. Task 5.3, skill 5.3.1 (troubleshoot VPC configurations: subnets, route tables, NAT gateways) |
| **Difficulty** | Medium |
| **Cost** | ≈ €0.06 per hour (NAT gateway) |
| **Time** | 30–45 minutes, plus up to 40 minutes for `terraform destroy` |

## What gets deployed

- A VPC with two **public** subnets (route to an internet gateway) and two **private** subnets (route to a NAT gateway)
- One NAT gateway with an Elastic IP
- A Lambda function `lambda-lab-partner-sync` (Python 3.13, arm64, 10-second timeout), attached to the VPC. Before it calls the partner's API, it looks up its public egress IP at `https://checkip.amazonaws.com`.

## Deploy

```bash
cd breakfix/08-lambda-vpc-timeout
terraform init
terraform apply
```

## Reproduce

```bash
aws lambda invoke --function-name lambda-lab-partner-sync /tmp/partner-sync.json && cat /tmp/partner-sync.json
```

## Incident ticket

> **INC-9120 · Priority P2 · partner-sync times out since it moved into the VPC**
>
> **Reported by:** Integrations team
>
> We attached `lambda-lab-partner-sync` to our VPC last week, because it will soon need a database that lives there. Since then every run fails with **Task timed out after 10.0 seconds**. Before the move it finished in well under a second. Our VPC has an internet gateway *and* a NAT gateway, so internet access should be fine. The function only calls a public HTTPS endpoint.

## Allowed tools

- **Console:** Lambda (Test, Monitor, Configuration → VPC), VPC (subnets, route tables, internet and NAT gateways, **Reachability Analyzer**), EC2 → Network interfaces
- **CLI:** `aws lambda invoke`, `aws lambda get-function-configuration`, `aws ec2 describe-route-tables`, `aws ec2 describe-network-interfaces`
- **CloudWatch:** Logs for the function, `AWS/Lambda` metrics (`Duration`, `Errors`)

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- The invoke returns `{"egress_ip": "...", "status": "ready to sync"}` in well under a second.
- `egress_ip` equals `terraform output nat_public_ip`. That's the address you would give the partner for their allowlist.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| NAT gateway | $0.052/h, plus $0.052/GB processed (≈ $0 for this lab) |
| Elastic IP of the NAT gateway (public IPv4) | $0.005/h |
| Lambda, CloudWatch Logs | free tier |
| **Total** | **≈ $0.057/h ≈ €0.06/h** |

> **Destroy reminder:** run `terraform destroy` as soon as you're done. The NAT gateway costs about €38 a month, even when idle. Lambda releases its VPC network interfaces asynchronously, so the destroy can take 20–40 minutes. If it still times out, run it again.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
