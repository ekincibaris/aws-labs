# Hints · 09 CloudFront keeps serving the old homepage

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

First prove where the old page comes from. Request it with `curl -sI "$SITE"` and read the response headers. One header tells you whether CloudFront answered from its cache, and another tells you how long that copy has been sitting there.

</details>

<details>
<summary>Hint 2</summary>

`x-cache: Hit from cloudfront` and a growing `age`, while the same response carries `cache-control: no-cache` from the origin. So CloudFront kept the object even though the origin told it not to.

Open the behavior's **cache policy**. It has three TTL settings. Which one can override what the origin says?

</details>

<details>
<summary>Hint 3</summary>

CloudFront honours `Cache-Control: no-cache`, `no-store` and `private` only when the cache policy's **Minimum TTL is 0**. With a Minimum TTL above 0, it caches every object for at least that long, whatever the origin says. Fix the policy. Then invalidate once to remove the copies that are already cached under the old rule.

</details>
