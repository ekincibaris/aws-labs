# 10 · App can't reach its database across VPC peering

| | |
|---|---|
| **SOA-C03 domain** | Domain 5: Networking and Content Delivery. Task 5.1, skill 5.1.2 (VPC peering), and Task 5.3, skill 5.3.1 (troubleshoot route tables and security groups) |
| **Difficulty** | Hard |
| **Cost** | ≈ €0.04 per hour |
| **Time** | 45–60 minutes, plus 5–10 minutes each for RDS to be created and deleted |

## What gets deployed

- An **application VPC** (`10.10.0.0/16`) with one public subnet and the app server `rds-lab-app` (t4g.micro, Session Manager access)
- A shared **data VPC** (`10.100.0.0/16`) with two private subnets and an RDS for PostgreSQL instance `rds-lab-orders` (db.t4g.micro, Single-AZ, not publicly accessible)
- A **VPC peering connection** between the two VPCs
- On the app server, a check `check-db` that tries to open a TCP connection to the database. A systemd timer runs it every minute.

## Deploy

```bash
cd breakfix/10-rds-unreachable
terraform init
terraform apply
```

The apply takes about 10 minutes, mostly waiting for RDS.

## Reproduce

Open a shell on the app server and run the check:

```bash
aws ssm start-session --target "$(terraform output -raw app_instance_id)"
# on the instance:
check-db
journalctl -u orders-db-check --since "-10 min"
```

## Incident ticket

> **INC-1010 · Priority P1 · orders-app can't reach its database**
>
> **Reported by:** App team
>
> As part of the platform migration, our orders database now lives in the shared **data VPC**, and the platform team connected it to our app VPC with VPC peering. Since then the app server `rds-lab-app` can't talk to the database. Every connection attempt to the endpoint on port 5432 **hangs and times out**; we don't get "connection refused". The database is **Available**, the peering connection is **Active**, and the database security group allows 5432 from our whole app VPC (`10.10.0.0/16`). We're down until this works.

## Allowed tools

- **Console:** RDS (Connectivity & security), VPC (peering connections, route tables, security groups, network ACLs, **Reachability Analyzer**), Systems Manager → Session Manager
- **CLI:** `aws rds describe-db-instances`, `aws ec2 describe-vpc-peering-connections`, `aws ec2 describe-route-tables`, `aws ec2 describe-security-groups`, `aws ec2 describe-network-interfaces`
- **CloudWatch:** RDS metrics (`DatabaseConnections`). You may create VPC Flow Logs if you want to see the packets.

Reachability Analyzer costs $0.10 per analysis and checks **one direction** per analysis.

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- `check-db` on the app server prints `OK: connected to ...:5432`, and the timer's log shows OK lines.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| RDS db.t4g.micro PostgreSQL, Single-AZ | $0.019/h |
| 20 GB gp3 database storage | $0.004/h |
| Secrets Manager secret for the RDS-managed master password | $0.40/month ≈ $0.001/h |
| t4g.micro app server and its public IPv4 address | $0.0146/h |
| 8 GB gp3 root volume | $0.001/h |
| VPC peering | free (traffic within one AZ is free) |
| **Total** | **≈ $0.039/h ≈ €0.04/h** |

> **Destroy reminder:** run `terraform destroy` as soon as you're done. Left running, this lab costs about €26 a month. The database is deleted without a final snapshot.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
