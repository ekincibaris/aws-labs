# 02 · Fleet doesn't scale out under load

| | |
|---|---|
| **SOA-C03 domain** | Domain 2: Reliability and Business Continuity. Task 2.1, skill 2.1.1 (configure and manage scaling mechanisms in compute environments) |
| **Difficulty** | Easy |
| **Cost** | ≈ €0.05 per hour with 1 instance, up to ≈ €0.14 per hour once it scales to 3 |
| **Time** | 30–45 minutes |

## What gets deployed

- A VPC with two public subnets (eu-central-1a and eu-central-1b)
- An Auto Scaling group `asg-lab-workers` (min 1, max 3) of t4g.micro "transcoding workers", built from a launch template with detailed monitoring
- A target tracking scaling policy that keeps the group's average CPU around **40 %**
- Each worker runs a simulated transcoding job that keeps one of its two vCPUs busy, so a single worker sits at about 50 % CPU

## Deploy

```bash
cd breakfix/02-asg-not-scaling
terraform init
terraform apply
```

Wait about 10 minutes after the apply. The first worker has to boot and CloudWatch needs a few datapoints.

## Incident ticket

> **INC-3104 · Priority P2 · Transcoding backlog grows, fleet never grows**
>
> **Reported by:** Media team
>
> Our transcoding fleet `asg-lab-workers` is configured to scale between 1 and 3 servers and to add servers when average CPU goes above 40 %. CPU has been sitting around 50 % for a while, and the scaling alarm in CloudWatch even shows **In alarm**, but we still have exactly **one** instance. The backlog keeps growing. Nobody touched the scaling policy.

## Allowed tools

- **Console:** EC2 → Auto Scaling groups (the **Activity**, **Monitoring** and **Details** tabs, plus the automatic scaling policy), CloudWatch → Alarms (history), CloudTrail → Event history
- **CLI:** `aws autoscaling describe-auto-scaling-groups`, `describe-scaling-activities` and `describe-policies`; `aws cloudwatch describe-alarms` and `describe-alarm-history`
- **CloudWatch:** `AWS/EC2 CPUUtilization` per Auto Scaling group, plus the group metrics (`GroupDesiredCapacity`, `GroupInServiceInstances`)

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- Within about 5 minutes of your fix, the group launches new instances on its own. The **Activity** tab shows the launch, with a cause that mentions the alarm, and the desired capacity grows to 2 and then 3.
- The fix is in the Terraform code: `terraform plan` shows no changes.

Then destroy straight away. Every worker keeps burning CPU.

## Cost and clean-up

| Resource | Price per instance in eu-central-1 |
|---|---|
| t4g.micro | $0.0096/h |
| Public IPv4 address | $0.005/h |
| T4g unlimited CPU credits (one vCPU busy, above the 10 % baseline) | ≈ $0.032/h |
| Detailed monitoring (7 metrics) | ≈ $0.003/h |
| 8 GB gp3 root volume | $0.001/h |
| **Per instance** | **≈ $0.05/h ≈ €0.05/h** |

Group metrics and the two target tracking alarms are free.

> **Destroy reminder:** run `terraform destroy` as soon as the group has scaled out. Left running at 3 instances, this lab costs about €100 a month.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
