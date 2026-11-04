# 11 · Find the blocked connection with VPC Flow Logs

| | |
|---|---|
| **SOA-C03 domain** | Domain 5: Networking and Content Delivery. Task 5.3, skill 5.3.2 (collect and interpret networking logs such as VPC flow logs to troubleshoot issues) |
| **Difficulty** | Hard |
| **Cost** | ≈ €0.04 per hour |
| **Time** | 45–60 minutes |

## What gets deployed

- A VPC with two subnets: `flowlogs-lab-reporting` (eu-central-1a) and `flowlogs-lab-inventory` (eu-central-1b)
- `flowlogs-lab-inventory-api`: a t4g.micro that serves stock levels on port 8080. Its security group allows 8080 from the reporting servers' security group.
- `flowlogs-lab-reporting-01`: a t4g.micro that runs a **stock report** against inventory-api every minute. It looks up the inventory-api URL in Parameter Store.
- **VPC Flow Logs** for the whole VPC (all traffic, 1-minute aggregation) sent to the CloudWatch Logs group `/vpc/flowlogs-lab`

Both servers are reachable with Session Manager.

## Deploy

```bash
cd breakfix/11-flow-logs-blocked-connection
terraform init
terraform apply
```

Wait about 10 minutes. The report has to run a few times, and flow log records arrive in CloudWatch Logs with a delay of a few minutes.

## Incident ticket

> **INC-1111 · Priority P2 · Stock report times out talking to inventory-api**
>
> **Reported by:** Reporting team
>
> Since inventory-api was redeployed this week, our stock report on `flowlogs-lab-reporting-01` fails on every run with **Connection timed out** when it calls inventory-api on port 8080 (`journalctl -u stock-report`). The inventory team says it isn't their problem: the service answers locally (`curl localhost:8080/stock.json`), and their security group allows port 8080 from our reporting security group. **VPC Flow Logs are enabled for the whole VPC.** Use them to find out where the connection is dropped and why.

## Allowed tools

- **CloudWatch Logs Insights** on the log group `/vpc/flowlogs-lab`. This is the main tool for this lab.
- **Console:** EC2 (instances, network interfaces: private **and** public IPs), VPC (security groups, flow logs), Systems Manager (Session Manager, Parameter Store)
- **CLI:** `aws logs start-query` and `get-query-results`, `aws ec2 describe-instances`, `aws ec2 describe-network-interfaces`, `aws ssm get-parameter`

Don't read the `.tf` files or the user data scripts until you have written your diagnosis in `notes/`.

## Definition of done

- `journalctl -u stock-report` on reporting-01 shows `OK: fetched stock ...` lines.
- The flow logs show `ACCEPT` records for the reporting → inventory-api connection on port 8080.
- You didn't open inventory-api to the internet or to public IP addresses.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| 2 × t4g.micro | $0.019/h |
| 2 public IPv4 addresses | $0.010/h |
| 2 × 8 GB gp3 root volumes | $0.002/h |
| Flow logs into CloudWatch Logs (vended logs, a few MB per hour) | ≈ $0.003/h |
| **Total** | **≈ $0.034/h ≈ €0.04/h** |

> **Destroy reminder:** run `terraform destroy` when you're done. Left running, this lab costs about €23 a month.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
