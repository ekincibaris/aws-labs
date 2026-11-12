# AWS Labs

Hands-on AWS labs with Terraform and the AWS CLI. Each one is built, broken or tested, then destroyed. I'm using them to build real operations skills and to prepare for the **AWS Certified CloudOps Engineer – Associate (SOA-C03)** exam.

> **About `breakfix/`:** the scenarios in [`breakfix/`](breakfix/) are **generated practice exercises**. They are not real incidents or official AWS material. Each one deploys a small setup with one deliberate fault. My own diagnosis notes live in [`notes/`](notes/).

## Labs I built

| Lab | What I did | Tool |
|---|---|---|
| [`01-ec2-cli`](01-ec2-cli/) | Launched an EC2 instance, connected over SSH, cleaned up and verified nothing was left | AWS CLI |
| [`02-hello-terraform`](02-hello-terraform/) | First Terraform run: init, plan, apply, destroy | Terraform |
| [`nacl-break-fix`](nacl-break-fix/) | Broke and fixed a custom network ACL: stateless rules and ephemeral ports | Terraform |
| [`cloudwatch-agent-procstat`](cloudwatch-agent-procstat/) | CloudWatch agent with procstat, and an alarm that emails me when a process stops | Terraform |

## Practice scenarios (breakfix)

| Lab | Symptom / topic | SOA-C03 domain | Difficulty | Cost |
|---|---|---|---|---|
| [`breakfix/00-budget-guardrail`](breakfix/00-budget-guardrail/) | €5/month budget; billing alarm stuck on *Insufficient data*. **Deploy first, keep it.** | 1 · task 1.1 | Easy | €0.00/h |
| [`breakfix/01-alb-502-bad-gateway`](breakfix/01-alb-502-bad-gateway/) | Shop behind an ALB returns 502 Bad Gateway | 2 · task 2.2 | Easy | ≈ €0.07/h |
| [`breakfix/02-asg-not-scaling`](breakfix/02-asg-not-scaling/) | Auto Scaling group doesn't scale out under load | 2 · task 2.1 | Easy | ≈ €0.05–0.14/h |
| [`breakfix/03-s3-access-denied`](breakfix/03-s3-access-denied/) | Writes to S3 work, reads fail with Access Denied | 4 · task 4.2 | Medium | ≈ €0.01/h |
| [`breakfix/04-cloudwatch-alarm-silent`](breakfix/04-cloudwatch-alarm-silent/) | Memory alarm stays green while memory is high | 1 · task 1.1 | Medium | ≈ €0.02/h |
| [`breakfix/05-ssm-instance-missing`](breakfix/05-ssm-instance-missing/) | Private EC2 instance never shows up in Systems Manager | 3 · task 3.2 | Medium | ≈ €0.05/h |
| [`breakfix/06-ecs-task-not-starting`](breakfix/06-ecs-task-not-starting/) | ECS Fargate service never reaches Running | 3 · task 3.1 | Medium | ≈ €0.00–0.02/h |
| [`breakfix/07-eventbridge-rule-not-firing`](breakfix/07-eventbridge-rule-not-firing/) | S3 uploads never trigger the EventBridge rule's Lambda | 1 · task 1.2 | Medium | €0.00/h |
| [`breakfix/08-lambda-vpc-timeout`](breakfix/08-lambda-vpc-timeout/) | Lambda times out after being attached to a VPC | 5 · task 5.3 | Medium | ≈ €0.06/h |
| [`breakfix/09-cloudfront-stale-content`](breakfix/09-cloudfront-stale-content/) | CloudFront keeps serving the old homepage | 5 · task 5.3 | Medium | €0.00/h |
| [`breakfix/10-rds-unreachable`](breakfix/10-rds-unreachable/) | App can't reach RDS in a peered VPC | 5 · task 5.1 | Hard | ≈ €0.04/h |
| [`breakfix/11-flow-logs-blocked-connection`](breakfix/11-flow-logs-blocked-connection/) | Find a blocked connection with VPC Flow Logs | 5 · task 5.3 | Hard | ≈ €0.04/h |
| [`breakfix/12-config-remediation-failing`](breakfix/12-config-remediation-failing/) | AWS Config flags open SSH, auto-remediation never fixes it | 4 · task 4.2 | Hard | ≈ €0.00/h |

Each lab's README gives the exact task and skill numbers, plus a cost breakdown.

### SOA-C03 domains

| # | Domain | Exam weight | Labs |
|---|---|---|---|
| 1 | Monitoring, Logging, Analysis, Remediation, and Performance Optimization | 22 % | 00, 04, 07 |
| 2 | Reliability and Business Continuity | 22 % | 01, 02 |
| 3 | Deployment, Provisioning, and Automation | 22 % | 05, 06, `02-hello-terraform` |
| 4 | Security and Compliance | 16 % | 03, 12 |
| 5 | Networking and Content Delivery | 18 % | 08, 09, 10, 11, `nacl-break-fix` |

Several labs touch a second domain as well. 03 and 06 practise IAM, 05 practises VPC endpoints, 09 practises caching for scalability, and 12 practises Systems Manager Automation.

## How to run a lab

### Once

- Use a **sandbox AWS account** that you own, with administrator access, and nothing important in it.
- Install **Terraform ≥ 1.17**, the **AWS CLI v2**, and the **Session Manager plugin** for the AWS CLI (for `aws ssm start-session`).
- Configure credentials for that account, for example `aws configure sso`, and check them with `aws sts get-caller-identity`. All labs use **eu-central-1**.
- Deploy [`breakfix/00-budget-guardrail`](breakfix/00-budget-guardrail/) and **leave it deployed**. It emails you before you pass €5 in a month.

### Every lab

```bash
cd breakfix/01-alb-502-bad-gateway
terraform init
terraform apply
```

1. Read the lab's `README.md`: the incident ticket, the allowed tools, and the definition of done. Some labs ask for a `terraform.tfvars`; copy `terraform.tfvars.example`.
2. Troubleshoot like on-call: Console, CLI and CloudWatch only. **Don't read the `.tf` files** until you've written your diagnosis. In a real incident you rarely start from the code.
3. Stuck? Open [`hints.md`](breakfix/01-alb-502-bad-gateway/hints.md) **one hint at a time**.
4. Fix it, preferably in the Terraform code. A console-only fix is reverted by the next `terraform apply`. Then check the lab's definition of done.
5. Read `solution.md`: root cause, the fix, how to detect it earlier in production, and how to prevent it with automation.
6. Write your notes: `cp notes/TEMPLATE.md notes/01-alb-502-bad-gateway.md`.
7. **Destroy:** `terraform destroy`.

### Costs and clean-up

- The costs are on-demand prices for eu-central-1 from the AWS Price List (November 2026), converted at 1 USD = €0.91 and rounded **up**, excluding VAT. Free tier or credits can make them lower.
- Every lab's README has a **destroy reminder** and says what the lab costs if you forget it for a month.
- Everything is tagged `Project = aws-labs`. Check for leftovers after a lab. Lab 00's budget alarm is meant to stay; everything else should be gone.

  ```bash
  aws resourcegroupstaggingapi get-resources --region eu-central-1 \
    --tag-filters Key=Project,Values=aws-labs --query 'ResourceTagMappingList[].ResourceARN'
  ```

- Never commit `terraform.tfstate` or `terraform.tfvars`. `.gitignore` already excludes them.

## Progress checklist

- [ ] `02-hello-terraform`
- [ ] `nacl-break-fix`
- [ ] `00-budget-guardrail` (keep deployed)
- [ ] `01-alb-502-bad-gateway`
- [ ] `02-asg-not-scaling`
- [ ] `03-s3-access-denied`
- [ ] `04-cloudwatch-alarm-silent`
- [ ] `05-ssm-instance-missing`
- [ ] `06-ecs-task-not-starting`
- [ ] `07-eventbridge-rule-not-firing`
- [ ] `08-lambda-vpc-timeout`
- [ ] `09-cloudfront-stale-content`
- [ ] `10-rds-unreachable`
- [ ] `11-flow-logs-blocked-connection`
- [ ] `12-config-remediation-failing`

Tick a lab once its notes are in `notes/` and `terraform destroy` has run.

## Repository layout

```
.
├── 02-hello-terraform/          first Terraform lab
├── nacl-break-fix/              NACL troubleshooting lab
├── breakfix/                    generated SOA-C03 troubleshooting labs
│   └── NN-<symptom>/
│       ├── README.md            incident ticket, allowed tools, domain, cost, destroy reminder
│       ├── hints.md             three progressive hints
│       ├── solution.md          root cause, fix, detection, prevention
│       └── *.tf                 the deliberately broken setup
├── notes/                       my own diagnosis notes (start from TEMPLATE.md)
├── scripts/check-labs.sh        terraform fmt + validate + tflint for every breakfix lab
├── .tflint.hcl                  TFLint rules (Terraform recommended preset + AWS ruleset)
└── .github/workflows/           the same checks on every pull request
```

## Checks

Every pull request runs [`.github/workflows/terraform-checks.yml`](.github/workflows/terraform-checks.yml):

- `terraform fmt -check` for the whole repository
- for every lab in `breakfix/`: `terraform init -backend=false`, `terraform validate` and `tflint` (with the AWS ruleset)

Run the same checks locally before you push:

```bash
scripts/check-labs.sh                                 # all breakfix labs
scripts/check-labs.sh breakfix/03-s3-access-denied    # one lab
```

`02-hello-terraform` and `nacl-break-fix` are covered by the format check only. `02-hello-terraform` has no `terraform` block, which TFLint's `terraform_required_version` rule requires. `nacl-break-fix` needs `~/.ssh/nacl-lab.pub` for `terraform validate`, and that file only exists on your machine.
