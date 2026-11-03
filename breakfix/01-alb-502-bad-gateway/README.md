# 01 · Shop returns 502 Bad Gateway

| | |
|---|---|
| **SOA-C03 domain** | Domain 2: Reliability and Business Continuity. Task 2.2, skill 2.2.1 (configure and troubleshoot ELB health checks) |
| **Difficulty** | Easy |
| **Cost** | ≈ €0.07 per hour |
| **Time** | 30–45 minutes |

## What gets deployed

- A VPC with two public subnets (eu-central-1a and eu-central-1b)
- An internet-facing Application Load Balancer with an HTTP listener on port 80
- Two t4g.micro web servers (Amazon Linux 2023) running the "Orders shop" service. They only accept traffic from the load balancer. You can open a shell on them with Session Manager.

## Deploy

```bash
cd breakfix/01-alb-502-bad-gateway
terraform init
terraform apply
terraform output shop_url
```

Give the servers 2–3 minutes to boot before you open the URL.

## Incident ticket

> **INC-2001 · Priority P1 · Shop returns 502 Bad Gateway**
>
> **Reported by:** Customer support
>
> Since this morning's release, every page of the shop shows **502 Bad Gateway**. Customers can't place orders. The developers logged in to both web servers and say the shop service is up (`systemctl status shop` is green on both). The release only changed infrastructure, not the application.

## Allowed tools

- **Console:** EC2 → Load balancers (including the **Resource map** tab), Target groups and Instances; Systems Manager → Session Manager
- **CLI:** `aws elbv2 describe-listeners`, `describe-target-groups` and `describe-target-health`; `aws ssm start-session` (needs the Session Manager plugin)
- **CloudWatch:** `AWS/ApplicationELB` metrics for the load balancer and the target group

Don't read the `.tf` files or `user-data.sh` until you have written your diagnosis in `notes/`.

## Definition of done

- `curl -i "$(terraform output -raw shop_url)"` returns `200 OK` with the "Orders shop" page. Reload a few times and both instance IDs show up.
- Both targets are **healthy** in the target group.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| Application Load Balancer | $0.027/h, plus LCUs (≈ $0 for lab traffic) |
| 2 × t4g.micro | $0.019/h |
| 4 public IPv4 addresses (2 servers, 2 load balancer nodes) | $0.020/h |
| 2 × 8 GB gp3 root volumes | $0.002/h |
| **Total** | **≈ $0.07/h ≈ €0.07/h** |

> **Destroy reminder:** run `terraform destroy` as soon as you're done. Left running, this lab costs about €45 a month.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
