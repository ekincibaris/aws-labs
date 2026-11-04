# Solution · 07 New invoices aren't processed

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The invoices bucket doesn't have **Amazon EventBridge notifications** turned on.

S3 publishes `Object Created` (and other) events to the default event bus **only** for buckets where *Send notifications to Amazon EventBridge for all events in this bucket* is enabled. It's off by default and lives in the bucket's notification configuration, so a rebuilt bucket loses it unless the IaC creates it again. In Terraform that's an `aws_s3_bucket_notification` resource with `eventbridge = true`, and this code doesn't have one.

Everything downstream is correct and never receives an event: the pattern, the target, the Lambda permission and the function.

## Evidence

```bash
BUCKET=$(terraform output -raw bucket_name)

aws s3api get-bucket-notification-configuration --bucket "$BUCKET"
# {}   <- no "EventBridgeConfiguration"

aws lambda get-policy --function-name events-lab-invoice-ingest --query Policy --output text
# allows events.amazonaws.com with the rule's ARN as the source  ✅
```

The pattern itself is fine. Save a sample event as `/tmp/sample.json` (replace `BUCKET`):

```json
{
  "version": "0",
  "id": "a1b2c3d4-0000-0000-0000-000000000000",
  "detail-type": "Object Created",
  "source": "aws.s3",
  "account": "123456789012",
  "time": "2026-11-03T10:00:00Z",
  "region": "eu-central-1",
  "resources": ["arn:aws:s3:::BUCKET"],
  "detail": {
    "version": "0",
    "bucket": { "name": "BUCKET" },
    "object": { "key": "incoming/inv-42.txt", "size": 29 },
    "reason": "PutObject"
  }
}
```

```bash
aws events test-event-pattern \
  --event-pattern "$(aws events describe-rule --name events-lab-invoice-uploaded --query EventPattern --output text)" \
  --event file:///tmp/sample.json
# { "Result": true }
```

In CloudWatch, `AWS/Events` → `MatchedEvents` for `RuleName = events-lab-invoice-uploaded` has no datapoints at all, and neither do `Invocations` and `FailedInvocations`.

## Fix

**Terraform.** Add the notification configuration to `s3.tf`:

```hcl
resource "aws_s3_bucket_notification" "invoices" {
  bucket      = aws_s3_bucket.invoices.id
  eventbridge = true
}
```

Run `terraform apply`, upload a file to `incoming/`, and the function logs `invoice registered` within seconds.

**Console.** S3 → bucket → **Properties** → **Event notifications** → **Amazon EventBridge** → **Edit** → **On**.

**CLI.**

```bash
aws s3api put-bucket-notification-configuration --bucket "$BUCKET" \
  --notification-configuration '{"EventBridgeConfiguration": {}}'
```

`put-bucket-notification-configuration` **replaces** the bucket's whole notification configuration. On a bucket that also sends notifications to SNS, SQS or Lambda, include those in the same call.

## Detect it earlier in production

- **A heartbeat alarm on silence.** An alarm on `AWS/Events MatchedEvents` (`RuleName`) with Sum < 1 over 1 hour and `treat_missing_data = "breaching"` fires when the pipeline goes quiet. For pipelines with irregular traffic, combine it with a canary.
- **A canary event.** An EventBridge Scheduler schedule uploads a small test file to `incoming/_canary/` every hour. An alarm on the ingest function's `Invocations` (or a log metric filter) fires if the canary isn't processed.
- **Target failures.** Once events do flow, alarm on `FailedInvocations`, and give the target a **dead-letter queue** so failed events aren't lost.

## Prevent it with automation

- **Keep producer and consumer together.** Create the bucket notification, the rule, the target and the permission in the same Terraform module, so you can't rebuild one without the other.
- **An end-to-end test after every deployment:** upload a test object, wait for the function's log line, and fail the pipeline if it doesn't appear.
- **Continuous compliance.** An AWS Config custom rule can check that buckets tagged as event sources have an `EventBridgeConfiguration` in their notification configuration.

## Exam takeaways

- S3 → EventBridge is an **opt-in per bucket**. Once it's on, every S3 event type goes to the **default bus**, and you filter in the rule. That's more flexible than classic S3 event notifications, which allow one destination per event type and prefix.
- Read the rule metrics in order: `MatchedEvents` (did anything match?), then `Invocations` (did the rule call the target?), then `FailedInvocations` (did that call fail, for example because of permissions?).
- Lambda, SNS and SQS targets need a **resource-based policy** that allows `events.amazonaws.com`. The console adds it for you; IaC has to declare it.
- Test patterns with the **Sandbox** or `aws events test-event-pattern` before you blame the target.
- Older patterns based on `AWS API Call via CloudTrail` for `PutObject` only work with a trail that records S3 **data events**. Native `Object Created` events don't need one.
