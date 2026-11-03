# Solution · 03 Report viewer gets Access Denied

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The reports bucket encrypts every object with **SSE-KMS** using the customer managed key `alias/s3-lab-reports`. With SSE-KMS, S3 makes KMS calls on behalf of the caller:

| Operation | KMS call S3 makes for you | Permission the caller needs |
|---|---|---|
| `PutObject` | `GenerateDataKey` (a new data key to encrypt the object) | `kms:GenerateDataKey` |
| `GetObject` | `Decrypt` (unwraps the object's data key) | `kms:Decrypt` |

The role `s3-lab-reports-app` allows `kms:Encrypt` and `kms:GenerateDataKey`, but **not `kms:Decrypt`**. So the exporter can write, and every read fails. S3 reports the KMS denial as `AccessDenied` on `GetObject`.

How each layer looks:

| Layer | Status |
|---|---|
| Bucket policy | Only denies requests without TLS. boto3 always uses HTTPS. ✅ |
| IAM, S3 actions | `s3:GetObject` and `s3:PutObject` on `reports/*`. ✅ |
| KMS key policy | Account-root statement: IAM policies decide who may use the key. ✅ |
| IAM, KMS actions | `kms:Decrypt` is missing. ❌ |

## Evidence

```bash
BUCKET=$(terraform output -raw bucket_name)

# How is the object stored?
aws s3api head-object --bucket "$BUCKET" --key reports/2026-10.csv \
  --query '[ServerSideEncryption,SSEKMSKeyId]'
# ["aws:kms", "arn:aws:kms:eu-central-1:<account>:key/<id>"]

# Ask IAM directly: can the role decrypt with that key?
ROLE_ARN=$(aws iam get-role --role-name s3-lab-reports-app --query Role.Arn --output text)
KEY_ARN=$(aws kms describe-key --key-id alias/s3-lab-reports --query KeyMetadata.Arn --output text)
aws iam simulate-principal-policy --policy-source-arn "$ROLE_ARN" \
  --action-names kms:Decrypt kms:GenerateDataKey --resource-arns "$KEY_ARN" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output table
# kms:Decrypt          implicitDeny
# kms:GenerateDataKey  allowed

# The denied KMS call in CloudTrail (management events are free, kept 90 days, and appear after ~5 minutes)
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=Decrypt \
  --max-results 5 --query 'Events[].CloudTrailEvent' --output text | grep -o '"errorCode":"[^"]*"'
```

## Fix

**Terraform.** In `iam.tf`, give the `UseReportsKey` statement exactly the actions S3 needs. `kms:Encrypt` isn't one of them, so remove it:

```hcl
{
  Sid      = "UseReportsKey"
  Effect   = "Allow"
  Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
  Resource = aws_kms_key.reports.arn
  Condition = {
    StringEquals = { "kms:ViaService" = "s3.eu-central-1.amazonaws.com" }
  }
},
```

The `kms:ViaService` condition is optional hardening. The role can then use the key only through S3, not by calling KMS directly. Run `terraform apply` and invoke the viewer again. It returns the CSV. IAM changes can take a few seconds to take effect.

**Console.** IAM → Roles → `s3-lab-reports-app` → policy `reports-bucket-access` → **Edit** → add `kms:Decrypt` to the KMS statement. Then make the same change in the code, or the next apply reverts it.

**Another valid fix: the key policy.** Add a statement to the key policy that allows the role `kms:Decrypt`. In the same account, either the IAM policy or the key policy is enough, because of the root delegation. Keep authorization in one place, though. For **cross-account** access you need both.

What doesn't fix it: switching the bucket's default encryption to SSE-S3. Existing objects stay encrypted with the KMS key, and you would weaken the control on purpose.

## Detect it earlier in production

- **Alarm on Lambda errors:** `AWS/Lambda Errors` (Sum ≥ 1 over 5 minutes) for `s3-lab-report-viewer`. That tells you something is wrong; the logs tell you what.
- **Watch denied KMS calls.** Send a CloudTrail trail to CloudWatch Logs and create a metric filter `{ ($.eventSource = "kms.amazonaws.com") && ($.errorCode = "AccessDenied") }` with an alarm on it. Denied `Decrypt` calls are logged as management events, so you don't need data events for this.
- **Centralized logging with Logs Insights** across functions: `filter @message like /AccessDenied/ | stats count() by @log`.

## Prevent it with automation

- **A post-deploy round-trip test.** After `terraform apply`, the pipeline invokes the exporter and then the viewer, and fails if the viewer doesn't return the file. This catches the problem before Finance does.
- **Policy tests in CI.** `aws iam simulate-principal-policy` for the actions the app must have (`s3:GetObject`, `s3:PutObject`, `kms:Decrypt`, `kms:GenerateDataKey`) turns "the role can read the reports" into an automated check.
- **A reusable module.** Wrap "app role with access to an SSE-KMS bucket" in one Terraform module that always grants the right pair of KMS actions with `kms:ViaService`, so nobody hand-writes these statements again.

## Exam takeaways

- SSE-KMS: **put needs `kms:GenerateDataKey`, get needs `kms:Decrypt`**. Multipart uploads need both. SSE-S3 needs no KMS permissions at all.
- A principal can use a KMS key only if the **key policy** allows it, either directly or by delegating to IAM through the account-root statement.
- To debug Access Denied, check every layer: SCP → identity policy → resource policy (bucket policy) → KMS key policy → VPC endpoint policy. An explicit deny anywhere wins.
- CloudTrail **Event history** contains management events, including KMS calls, for free. S3 object-level operations are **data events** and need a trail with data events enabled.
