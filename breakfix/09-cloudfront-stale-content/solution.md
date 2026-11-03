# Solution · 09 CloudFront keeps serving the old homepage

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The custom cache policy `cdn-lab-site` has **Minimum TTL = 86,400 seconds (1 day)**. Someone wanted to "maximise the cache hit ratio". The TTL rules, simplified:

| What the origin sends | What CloudFront does |
|---|---|
| `Cache-Control: max-age=N` | caches for N seconds, but never less than Minimum TTL and never more than Maximum TTL |
| `Cache-Control: no-cache`, `no-store` or `private` | Minimum TTL = 0: **doesn't cache**. Minimum TTL > 0: **caches for the Minimum TTL** |
| no caching headers at all | caches for the Default TTL |

The deploy job did the right thing (`no-cache` on `index.html`), but the Minimum TTL overrode it. Every edge location that served v1 keeps it for 24 hours. The origin's `Cache-Control` header is still passed on to browsers, which is why "it works on my machine with a hard refresh" never helps: the stale copy is in CloudFront, not in the browser.

## Evidence

```bash
SITE=$(terraform output -raw site_url)
curl -sI "$SITE" | grep -iE '^(x-cache|age|cache-control|last-modified)'
# x-cache: Hit from cloudfront
# age: 1874
# cache-control: no-cache

BUCKET=$(terraform output -raw bucket_name)
aws s3api head-object --bucket "$BUCKET" --key index.html --query '[CacheControl,LastModified]'
# ["no-cache", "<a few minutes ago>"]   <- the origin really has the new file

POLICY_ID=$(aws cloudfront list-cache-policies --type custom \
  --query "CachePolicyList.Items[?CachePolicy.CachePolicyConfig.Name=='cdn-lab-site'].CachePolicy.Id" --output text)
aws cloudfront get-cache-policy --id "$POLICY_ID" \
  --query 'CachePolicy.CachePolicyConfig.[MinTTL,DefaultTTL,MaxTTL]'
# [86400, 86400, 31536000]
```

## Fix

**Terraform.** In `cloudfront.tf`, set `min_ttl = 0` on the cache policy and run `terraform apply`. You can keep `default_ttl` and `max_ttl`: they still apply to objects that send `max-age`, or no header at all.

Changing the policy doesn't touch copies that are **already** cached under the old rule. Remove them once:

```bash
aws cloudfront create-invalidation --distribution-id "$(terraform output -raw distribution_id)" --paths "/" "/index.html"
```

Viewers request `/`, and CloudFront serves the default root object under that cache key. That's why `/` has to be invalidated as well as `/index.html` (or use `"/*"`). After that, every deploy is visible immediately: `x-cache` shows `Miss from cloudfront` for the homepage, because CloudFront now honours `no-cache`.

**Console.** CloudFront → **Policies** → **Cache** → `cdn-lab-site` → **Edit** → **Minimum TTL** = 0. A cache policy can be shared by several distributions, and the change applies to all of them.

## Detect it earlier in production

- **A synthetic check of the deployed version.** A CloudWatch Synthetics canary loads the homepage through CloudFront every few minutes, compares a version marker (or the `ETag`) with the object in S3, and alarms when they differ for longer than, say, 10 minutes after a deploy.
- **Edge logs.** CloudFront standard or real-time logs (`x-edge-result-type` Hit/Miss/RefreshHit) show whether HTML is served from cache. HTML that is almost always a `Hit` despite `no-cache` is a red flag.
- **Review cache policies** with `aws cloudfront list-cache-policies --type custom`, and flag `MinTTL > 0` on policies that serve HTML.

## Prevent it with automation

- **Versioned file names for static assets** (`app.3f9a1c.js`) with long TTLs and `Cache-Control: max-age=31536000, immutable`. HTML gets a short TTL or `no-cache`, served by a separate cache behavior (for example `*.html`, or the default behavior) whose policy has Minimum TTL 0.
- **Invalidate in the pipeline, as a safety net.** After uploading HTML, run `aws cloudfront create-invalidation ... --paths "/" "/index.html"` and `aws cloudfront wait invalidation-completed`. The first 1,000 paths per month are free.
- **Policy-as-code in CI** that rejects a `min_ttl > 0` on cache policies attached to behaviors serving HTML.

## Exam takeaways

- Origin `Cache-Control`/`Expires` headers are applied **within** the Minimum and Maximum TTL. A **Minimum TTL > 0 overrides `no-cache`, `no-store` and `private`**. The AWS managed `CachingOptimized` policy has a Minimum TTL of 1 second; `CachingDisabled` has 0 everywhere.
- To serve new content now: **invalidate** (paths, wildcards, cost beyond the free tier) or, better, **version** the file names.
- `x-cache` (`Hit`, `Miss`, `RefreshHit`, `Error from cloudfront`) and `age` are the fastest evidence of what the edge is doing.
- Everything in the cache key (query strings, headers, cookies) lowers the hit ratio. Add only what the origin needs.
