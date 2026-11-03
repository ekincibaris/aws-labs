# 04 · Memory alarm stays green

| | |
|---|---|
| **SOA-C03 domain** | Domain 1: Monitoring, Logging, Analysis, Remediation, and Performance Optimization. Task 1.1, skills 1.1.2 (configure and manage the CloudWatch agent) and 1.1.3 (configure, identify and troubleshoot CloudWatch alarms) |
| **Difficulty** | Medium |
| **Cost** | ≈ €0.02 per hour |
| **Time** | 30–45 minutes |

## What gets deployed

- A VPC with one public subnet
- A t4g.micro instance `alarm-lab-orders-cache` that runs an in-memory cache service and the **CloudWatch agent** (memory metrics every 60 seconds)
- A CloudWatch alarm `alarm-lab-orders-cache-memory-high` that should fire when memory use goes above 60 %, plus an SNS topic for its notifications

Optional: put your email address in `terraform.tfvars` (copy `terraform.tfvars.example`) to get the alarm emails.

## Deploy

```bash
cd breakfix/04-cloudwatch-alarm-silent
terraform init
terraform apply
```

Wait about 10 minutes after the apply. The instance installs and starts the agent, and the cache loads its data.

## Incident ticket

> **INC-5207 · Priority P2 · orders-cache nearly ran out of memory, alarm stayed green**
>
> **Reported by:** On-call engineer
>
> `alarm-lab-orders-cache` was running close to its memory limit last night. When I log in, `free -m` shows about 80 % used. Our memory alarm `alarm-lab-orders-cache-memory-high` (threshold 60 %) never fired. It's green (**OK**) right now. The CloudWatch agent is installed and running on the box. If the alarm can't see this, what else is it missing?

## Allowed tools

- **Console:** CloudWatch → Alarms (alarm details and graph), CloudWatch → All metrics (the `CWAgent` namespace); Systems Manager → Session Manager (a shell on the instance)
- **CLI:** `aws cloudwatch describe-alarms`, `aws cloudwatch list-metrics --namespace CWAgent`, `aws cloudwatch get-metric-statistics`
- **On the instance:** `free -m`, `sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status`, and the agent's configuration and log files under `/opt/aws/amazon-cloudwatch-agent/`

Don't read the `.tf` files or `user-data.sh` until you have written your diagnosis in `notes/`.

## Definition of done

- The alarm's graph shows memory datapoints, and within about 5 minutes of your fix it goes to **ALARM** (you get an email if you subscribed).
- Bonus: stop the cache with `sudo systemctl stop orders-cache` and watch the alarm return to **OK**.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| t4g.micro | $0.0096/h |
| Public IPv4 address | $0.005/h |
| 8 GB gp3 root volume | $0.001/h |
| 1 custom metric (`mem_used_percent`) | $0.30/month ≈ $0.0004/h |
| 1 alarm, SNS | free tier |
| **Total** | **≈ $0.016/h ≈ €0.02/h** |

> **Destroy reminder:** run `terraform destroy` when you're done. Left running, this lab costs about €11 a month.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
