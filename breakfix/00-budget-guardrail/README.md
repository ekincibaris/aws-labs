# 00 · Budget guardrail

Deploy this lab first and **leave it deployed**. It is the safety net for every other lab.

| | |
|---|---|
| **SOA-C03 domain** | Domain 1: Monitoring, Logging, Analysis, Remediation, and Performance Optimization. Task 1.1, skills 1.1.3 (troubleshoot CloudWatch alarms) and 1.1.5 (alarm notifications through SNS) |
| **Difficulty** | Easy |
| **Cost** | €0.00 per hour |
| **Time** | 20–30 minutes, plus waiting for billing data |

## What gets deployed

- An **AWS Budget** with a €5/month limit that emails you at 50 % and 100 % of actual spend, and when the forecast for the month goes over 100 %. AWS Budgets only works in USD, so the limit is converted with `usd_per_eur` (default 1.10, so €5 becomes $5.50).
- A **CloudWatch billing alarm** on the estimated charges for the month, with an SNS topic that emails you. It is meant as a second tripwire next to the budget.

The budget works as soon as it is deployed and has no deliberate fault. You are protected while you troubleshoot the alarm.

## Before you deploy

1. Use an IAM user or role that can see billing data (administrator access in your sandbox account is fine).
2. In the Billing and Cost Management console, open **Billing preferences** and turn on **Receive CloudWatch billing alerts** under alert preferences. Turning on **Free Tier usage alerts** there too is a good idea.
3. Create your variables file: `cp terraform.tfvars.example terraform.tfvars` and put your email address in it. `*.tfvars` is ignored by git.

## Deploy

```bash
cd breakfix/00-budget-guardrail
terraform init
terraform apply
```

After the apply you get two emails. Confirm both, or no alert will ever reach you:

1. **AWS Budgets verification**, sent from an `@aws.com` address. Open the link while you're signed in to this AWS account. The link expires after 12 hours; the budget detail page in the console has a **Resend verification** button. The recipient status there should change from *Pending* to *Active*.
2. **AWS Notification - Subscription Confirmation** from SNS, for the alarm's topic.

## Incident ticket

> **INC-0100 · Priority P3 · Billing alarm never leaves "Insufficient data"**
>
> **Reported by:** you, the account owner
>
> I set up two cost guardrails. The budget emails arrive. The CloudWatch alarm `budget-lab-estimated-charges` is supposed to email me before my bill passes €5, but in the CloudWatch console it has shown **Insufficient data** since the moment I created it. Billing alerts are enabled in my billing preferences. I don't trust an alarm that has never had a single datapoint. Please make it actually watch my bill.

## Allowed tools

- **Console:** CloudWatch (Alarms, All metrics), Billing and Cost Management, SNS
- **CLI:** `aws cloudwatch describe-alarms`, `aws cloudwatch list-metrics`, `aws cloudwatch get-metric-statistics`, `aws sns list-subscriptions`
- **CloudWatch:** metrics and alarm history

Work out the root cause from what AWS shows you. Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- The alarm watches a metric that has datapoints, and its state is **OK** (or **ALARM** if you really spent more than the limit).
- The alarm's SNS email subscription is confirmed.
- The fix lives in the Terraform code, so `terraform plan` shows no changes afterwards.

Billing data is published only a few times a day. If billing alerts were switched on only recently, the first datapoint can take several hours to appear.

## Cost and clean-up

| Resource | Price |
|---|---|
| AWS Budget without actions | free |
| 1 CloudWatch alarm | free tier (10 alarms) |
| SNS email notifications | free tier (1,000 emails/month) |
| **Total** | **€0.00 per hour** |

**Don't destroy this lab.** Keep it running as long as the account exists. If you ever close the sandbox account, run `terraform destroy` here last. Keep this folder's `terraform.tfstate` safe, because it's the only record Terraform has of these resources.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
