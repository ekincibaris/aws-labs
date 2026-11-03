# Hints · 00 Budget guardrail

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

**Insufficient data** means the alarm isn't receiving any datapoints. Before you look at the threshold or the period, check that the metric the alarm watches exists at all, in the place where the alarm lives.

</details>

<details>
<summary>Hint 2</summary>

Compare these two commands:

```bash
aws cloudwatch list-metrics --namespace AWS/Billing --region eu-central-1
aws cloudwatch list-metrics --namespace AWS/Billing --region us-east-1
```

Billing data doesn't behave like EC2 or Lambda metrics.

</details>

<details>
<summary>Hint 3</summary>

AWS publishes the `EstimatedCharges` metric in **one Region only**, wherever your resources run. An alarm can only watch metrics in its own Region, and its SNS topic has to be in that Region too. Since AWS provider v6, every regional Terraform resource accepts a `region` argument. Run `terraform plan` before you apply, and check that it really replaces the resources.

</details>
