# 09 · CloudFront keeps serving the old homepage

| | |
|---|---|
| **SOA-C03 domain** | Domain 5: Networking and Content Delivery. Task 5.3, skill 5.3.3 (identify and remediate CloudFront caching issues). Also Domain 2, skill 2.1.2 (caching with CloudFront) |
| **Difficulty** | Medium |
| **Cost** | ≈ €0.00 per hour (CloudFront free tier) |
| **Time** | 30–45 minutes, plus 5–15 minutes each for the distribution to deploy and to be deleted |

## What gets deployed

- A private S3 bucket with the shop's homepage (`index.html`, version **v1**)
- A CloudFront distribution in front of it, using origin access control (OAC), HTTPS redirect and a custom cache policy `cdn-lab-site`

## Deploy

```bash
cd breakfix/09-cloudfront-stale-content
terraform init
terraform apply
terraform output site_url
```

## Reproduce

1. Open the site once, so that an edge location caches it:

   ```bash
   SITE=$(terraform output -raw site_url)
   curl -s "$SITE" | grep version
   ```

2. "Deploy" version 2 the way the marketing pipeline does:

   ```bash
   BUCKET=$(terraform output -raw bucket_name)
   printf '<!doctype html><html><body><h1>Winter sale</h1><p>Homepage version: <strong>v2</strong></p></body></html>' \
     | aws s3 cp - "s3://$BUCKET/index.html" --content-type "text/html; charset=utf-8" --cache-control no-cache
   ```

3. Load the site again: `curl -s "$SITE" | grep version`

## Incident ticket

> **INC-9431 · Priority P2 · Homepage still shows last week's campaign**
>
> **Reported by:** Marketing
>
> We published the new homepage (v2) half an hour ago, and we checked that the file in the S3 bucket is the new one. Our deploy job sets `Cache-Control: no-cache` on `index.html` precisely so that CloudFront always fetches the latest version. Still, every customer sees v1, on every device and browser. We can invalidate by hand, but this is the third time this month. Why does CloudFront ignore our cache headers?

## Allowed tools

- **Console:** CloudFront (distribution → **Behaviors**, Policies → **Cache**, **Invalidations**), S3 (object metadata)
- **CLI:** `curl -sI` against the site, `aws cloudfront get-distribution-config`, `aws cloudfront get-cache-policy`, `aws s3api head-object`, `aws cloudfront create-invalidation`
- **CloudWatch:** CloudFront metrics are in **us-east-1**: `Requests`, `BytesDownloaded`, and `CacheHitRate` if you turn on additional metrics (paid)

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- After your fix, publish a **v3** with the same `aws s3 cp` command (change the text). It shows up through CloudFront immediately, **without** an invalidation.
- `curl -sI "$SITE"` no longer shows `x-cache: Hit from cloudfront` for the homepage.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price |
|---|---|
| CloudFront | always-free tier: 1 TB of data transfer, 10 million requests and 1,000 invalidation paths per month |
| S3 | fractions of a cent |
| **Total** | **≈ €0.00/h** |

> **Destroy reminder:** run `terraform destroy` when you're done. Terraform first disables the distribution and then deletes it, which takes 5–15 minutes. Let it finish.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
