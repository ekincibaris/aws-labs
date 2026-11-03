# 07 · New invoices aren't processed

| | |
|---|---|
| **SOA-C03 domain** | Domain 1: Monitoring, Logging, Analysis, Remediation, and Performance Optimization. Task 1.2, skill 1.2.2 (use EventBridge to route events and troubleshoot event bus rules). Also Domain 3, skill 3.2.2 (event-driven automation) |
| **Difficulty** | Medium |
| **Cost** | ≈ €0.00 per hour |
| **Time** | 30–45 minutes |

## What gets deployed

- An S3 bucket for supplier invoices (`events-lab-invoices-…`)
- An EventBridge rule `events-lab-invoice-uploaded` on the default event bus that matches new objects under `incoming/` in that bucket
- A Lambda function `events-lab-invoice-ingest` as the rule's target, which logs every invoice it registers, plus the resource-based policy that lets EventBridge invoke it

## Deploy

```bash
cd breakfix/07-eventbridge-rule-not-firing
terraform init
terraform apply
```

## Reproduce

```bash
BUCKET=$(terraform output -raw bucket_name)
echo "invoice 42, total 129.00 EUR" > /tmp/inv-42.txt
aws s3 cp /tmp/inv-42.txt "s3://$BUCKET/incoming/inv-42.txt"
```

Then look for a log line in the log group `/aws/lambda/events-lab-invoice-ingest`.

## Incident ticket

> **INC-8015 · Priority P3 · Uploaded invoices are never registered**
>
> **Reported by:** Accounts payable
>
> Suppliers' invoices are uploaded to the `incoming/` folder of our invoices bucket. The EventBridge rule `events-lab-invoice-uploaded` is supposed to trigger `events-lab-invoice-ingest` for each new file. Since the bucket was rebuilt last week, nothing happens. The files arrive in S3, but the function shows no invocations and writes no logs. The rule is **Enabled**, and the function works fine when we run it from the console with a test event.

## Allowed tools

- **Console:** EventBridge (the rule's **Monitoring** tab, targets, and the **Sandbox** for testing event patterns), Lambda (Monitor, configuration → permissions), S3 (bucket properties)
- **CLI:** `aws events describe-rule`, `aws events list-targets-by-rule`, `aws events test-event-pattern`, `aws lambda get-policy`, `aws s3api get-bucket-notification-configuration`
- **CloudWatch:** `AWS/Events` metrics per rule (`MatchedEvents`, `TriggeredRules`, `Invocations`, `FailedInvocations`), `AWS/Lambda` metrics, Logs

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- Uploading a file to `incoming/` produces an `invoice registered` log line within a minute.
- Uploading a file to another prefix (for example `archive/`) doesn't trigger the function.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| EventBridge rule for AWS service events | free |
| Lambda, S3, CloudWatch Logs | free tier / fractions of a cent |
| **Total** | **≈ €0.00/h** |

> **Destroy reminder:** run `terraform destroy` when you're done. The bucket is emptied automatically (`force_destroy`).

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
