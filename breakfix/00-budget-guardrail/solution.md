# Solution · 00 Budget guardrail

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The billing alarm and its SNS topic were created in **eu-central-1**, because that is the region of the only provider in the code. AWS publishes billing metrics (`AWS/Billing` → `EstimatedCharges`) **only in US East (N. Virginia), `us-east-1`**, and those metrics cover the whole account's charges worldwide. A CloudWatch alarm can only evaluate metrics in its own Region. In eu-central-1 the metric doesn't exist, so the alarm never gets a datapoint and stays in `INSUFFICIENT_DATA` forever.

The budget kept working because AWS Budgets is a global service that doesn't depend on CloudWatch metrics.

## Evidence

```bash
# The alarm exists and has never been evaluated against real data
aws cloudwatch describe-alarms --region eu-central-1 \
  --alarm-names budget-lab-estimated-charges \
  --query 'MetricAlarms[0].[StateValue,StateReason]'

# There is no billing metric in eu-central-1 ...
aws cloudwatch list-metrics --namespace AWS/Billing --region eu-central-1

# ... but there is one in us-east-1 (once billing alerts are enabled)
aws cloudwatch list-metrics --namespace AWS/Billing --region us-east-1 \
  --metric-name EstimatedCharges --dimensions Name=Currency,Value=USD
```

In the console you see the same: CloudWatch → **All metrics** in eu-central-1 has no **Billing** namespace. Switch the Region selector to **US East (N. Virginia)** and the namespace appears.

## Fix

Move the alarm **and** its SNS topic (with the subscription) to us-east-1 in Terraform.

1. Since AWS provider v6, every regional resource has a `region` argument. Add it to the three resources in `alarm.tf`:

   ```hcl
   resource "aws_sns_topic" "billing_alerts" {
     region = "us-east-1"
     name   = "budget-lab-billing-alerts"
   }

   resource "aws_sns_topic_subscription" "billing_email" {
     region    = "us-east-1"
     topic_arn = aws_sns_topic.billing_alerts.arn
     protocol  = "email"
     endpoint  = var.alert_email
   }

   resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
     region = "us-east-1"
     # ... all other arguments unchanged
   }
   ```

2. Run `terraform plan`. All three show `region = "eu-central-1" -> "us-east-1" # forces replacement`: Terraform deletes them in eu-central-1 and creates them in us-east-1. Run `terraform apply`.

3. Confirm the new SNS subscription email. It's a new topic in a new Region, so the earlier confirmation doesn't carry over.

Watch out for the classic approach: a second `provider "aws"` block with `alias = "us_east_1"` and `provider = aws.us_east_1` on the **same** resources. With provider v6, that does **not** move existing resources. The plan shows no changes, because the Region recorded in the state wins. An aliased provider is fine for new resources. To move existing ones with an alias, you also have to give them new names (resource addresses), so that Terraform destroys the old ones and creates new ones.

4. Check the result:

   ```bash
   aws cloudwatch describe-alarms --region us-east-1 \
     --alarm-names budget-lab-estimated-charges \
     --query 'MetricAlarms[0].[StateValue,StateReason]'
   ```

If the new alarm also shows `INSUFFICIENT_DATA` and `list-metrics` in us-east-1 returns nothing, billing alerts aren't enabled yet, or were enabled only recently. Turn on **Receive CloudWatch billing alerts** in Billing preferences and allow a few hours for the first datapoint.

## Detect it earlier in production

- **Treat `INSUFFICIENT_DATA` as a finding, not as "fine".** A daily check like `aws cloudwatch describe-alarms --state-value INSUFFICIENT_DATA` lists alarms that have never had data. An alarm stuck there for more than a day is watching the wrong metric, Region or dimensions.
- **Route alarm state changes through EventBridge.** A rule on `CloudWatch Alarm State Change` events with `"state": {"value": ["INSUFFICIENT_DATA"]}` can notify the team when an important alarm loses its data.
- **Don't depend on a single signal for cost.** Keep the AWS Budget (global) and turn on **AWS Cost Anomaly Detection** (free) next to any billing alarm.

## Prevent it with automation

- Put the billing alarm in a small Terraform module that always sets `region = "us-east-1"`, so nobody can deploy it in the wrong Region by accident.
- Guard the code: a `lifecycle { postcondition { condition = self.region == "us-east-1" ... } }` on the alarm, or a policy-as-code rule in CI (Conftest/OPA, Checkov) that rejects `AWS/Billing` alarms outside us-east-1.
- Run `terraform plan` in CI (like the workflow in this repo) so the Region of every new alarm shows up in the review.

## Exam takeaways

- Billing metrics live only in **us-east-1**, and only after **Receive CloudWatch billing alerts** is enabled. The metric is `AWS/Billing EstimatedCharges` with the dimension `Currency=USD`, optionally split by `ServiceName` or `LinkedAccount`.
- CloudWatch alarms are regional, and the SNS topic in an alarm action has to be in the alarm's Region.
- `INSUFFICIENT_DATA` usually means the metric is missing, in another Region, or has different dimensions. It rarely means "everything is fine".
- AWS Budgets alert on **actual** and **forecasted** cost or usage. Budget actions can also apply an IAM policy or SCP, or stop EC2/RDS instances, when a threshold is crossed.
