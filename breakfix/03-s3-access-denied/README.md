# 03 · Report viewer gets Access Denied

| | |
|---|---|
| **SOA-C03 domain** | Domain 4: Security and Compliance. Task 4.2, skill 4.2.2 (troubleshoot encryption at rest with AWS KMS), and Task 4.1, skill 4.1.2 (troubleshoot access with CloudTrail and the IAM policy simulator) |
| **Difficulty** | Medium |
| **Cost** | ≈ €0.01 per hour |
| **Time** | 30–60 minutes |

## What gets deployed

- A private S3 bucket for monthly sales reports, with default encryption and a bucket policy, plus last month's report `reports/2026-10.csv`
- A customer managed KMS key with the alias `alias/s3-lab-reports`
- Two Lambda functions that share the IAM role `s3-lab-reports-app`:
  - `s3-lab-report-exporter` writes this month's report
  - `s3-lab-report-viewer` reads a report and returns its content

## Deploy

```bash
cd breakfix/03-s3-access-denied
terraform init
terraform apply
```

## Reproduce

```bash
aws lambda invoke --function-name s3-lab-report-exporter \
  --cli-binary-format raw-in-base64-out --payload '{}' /tmp/exporter.json && cat /tmp/exporter.json

aws lambda invoke --function-name s3-lab-report-viewer \
  --cli-binary-format raw-in-base64-out --payload '{"key": "reports/2026-10.csv"}' /tmp/viewer.json && cat /tmp/viewer.json
```

You can also use the **Test** tab of each function in the Lambda console.

## Incident ticket

> **INC-4410 · Priority P2 · Report viewer: Access Denied on every report**
>
> **Reported by:** Finance team
>
> The monthly export job (`s3-lab-report-exporter`) runs fine, and this month's CSV appears in the reports bucket. The report viewer (`s3-lab-report-viewer`) fails with **Access Denied** for every report we open, old and new. The developers say the app's role is allowed to `s3:GetObject` on `reports/*`, and the bucket policy only blocks non-HTTPS requests. We need the reports for the board meeting.

## Allowed tools

- **Console:** Lambda (Test, Monitor → logs), S3 (object properties), IAM (roles, **Policy simulator**), KMS (key policy), CloudTrail → **Event history**
- **CLI:** `aws lambda invoke`, `aws s3api head-object`, `aws iam get-role-policy`, `aws iam simulate-principal-policy`, `aws kms get-key-policy`, `aws cloudtrail lookup-events`
- **CloudWatch:** Logs for both functions (Logs Insights works too)

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- The viewer returns the CSV content for `reports/2026-10.csv` and for the report the exporter just wrote.
- The exporter still works.
- You fixed it with least privilege: no `kms:*`, no `s3:*`, no `"Resource": "*"`, and the bucket is still encrypted with the KMS key.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| Customer managed KMS key | $1/month, prorated hourly ≈ $0.0014/h |
| Lambda, S3, CloudWatch Logs | free tier / fractions of a cent |
| **Total** | **≈ €0.01/h** |

`terraform destroy` schedules the KMS key for deletion with a 7-day waiting period. Keys pending deletion aren't charged.

> **Destroy reminder:** run `terraform destroy` when you're done. The bucket is emptied automatically (`force_destroy`).

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
