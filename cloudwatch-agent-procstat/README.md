# CloudWatch agent: alert when a process dies

An EC2 instance runs nginx. The CloudWatch agent watches the nginx process with the
procstat plugin, and an alarm sends me an email when the process stops.

| | |
|---|---|
| **Region** | eu-central-1 |
| **Cost** | About €0.02/h (t3.micro + public IPv4). Destroyed the same day |
| **Built with** | Terraform, AWS CLI, Systems Manager Session Manager |

## What it builds

- EC2 t3.micro, Amazon Linux 2023, IMDSv2 required. User data installs nginx and the CloudWatch agent
- Security group with no inbound rules. I connect only through Session Manager, no SSH
- IAM role with `AmazonSSMManagedInstanceCore` and `CloudWatchAgentServerPolicy`
- CloudWatch alarm on `procstat_lookup_pid_count` for nginx: below 1 for 2 minutes, missing data counts as breaching
- SNS topic with an email subscription, used for both ALARM and OK

```
nginx process → CloudWatch agent (procstat) → CWAgent metric → alarm → SNS → email
```

The agent config (memory, disk and procstat for nginx) is not in this Terraform.
I wrote it by hand on the instance through Session Manager and started the agent with
`amazon-cloudwatch-agent-ctl`. Moving it to SSM Parameter Store is the next improvement.

## What I broke

1. **Stopped nginx** (`sudo systemctl stop nginx`). The pid count went to 0 and the alarm
   went into ALARM after about 2 minutes. I got the email. After I started nginx again,
   the alarm went back to OK and I got a second email.
2. **Stopped the CloudWatch agent.** nginx was still running, but the alarm fired anyway.
   With no agent, no data reaches CloudWatch, and `treat_missing_data = "breaching"`
   counts missing data as a failure.
3. **Filled the disk** with `fallocate`. `disk_used_percent` went up in the CWAgent
   metrics, but no email came, because there is no alarm on disk. I only saw it because
   I went and looked.

## What I learned

- Missing data is a decision. With `breaching`, a dead agent looks the same as dead nginx.
  That is safer than silence, but the email alone can't tell me which one failed.
- An alarm only covers what it watches. The disk filled up and nothing told me.
- The OK action matters too. Without it I would not know the problem was fixed.
- Session Manager was enough for everything I did. No port 22, no key pair.
- Agent config done by hand is lost when the instance is replaced. It should live in code.

## Clean-up

```bash
terraform destroy
aws ec2 describe-instances --filters Name=tag:Project,Values=aws-labs \
  --query 'Reservations[].Instances[].State.Name'
```
