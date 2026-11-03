# Hints · 03 Report viewer gets Access Denied

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

Read the **full** error message, in the invoke response or the viewer's CloudWatch logs, not just "Access Denied". Then think about what's different between a write, which works, and a read, which fails, for the same role and the same bucket. Look at how the objects are stored, not only at who may access them.

</details>

<details>
<summary>Hint 2</summary>

`aws s3api head-object` shows that the objects are encrypted with **SSE-KMS** under a customer managed key. With SSE-KMS, S3 calls KMS **on behalf of the caller**, so the caller needs permission on the bucket *and* on the key.

Uploads and downloads use different KMS actions. CloudTrail **Event history**, filtered on event source `kms.amazonaws.com`, shows which call was denied and for whom.

</details>

<details>
<summary>Hint 3</summary>

An upload needs `kms:GenerateDataKey`. A download needs `kms:Decrypt`. The key policy hands authorization over to IAM (the account-root statement), so the role's **IAM policy** decides. Check it with the policy simulator: simulate `kms:Decrypt` for the role `s3-lab-reports-app` against the key's ARN, then fix the policy.

</details>
