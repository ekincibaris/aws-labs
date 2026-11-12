# 01 · Shop returns 502 Bad Gateway

- **Lab:** `breakfix/01-alb-502-bad-gateway`
- **Date:** 12 November 2026
- **Time spent:** about 35 minutes, deploy to destroy
- **Hints used:** 0 from `hints.md`. I worked through it with Claude asking me questions, not giving answers.

## Symptom

Ticket: every page of the shop shows 502 Bad Gateway since a release that only changed
infrastructure. The developers say `systemctl status shop` is green on both servers.

What I saw myself:

```
$ curl -i http://alb-lab-alb-....eu-central-1.elb.amazonaws.com
HTTP/1.1 502 Bad Gateway
Server: awselb/2.0
```

`Server: awselb/2.0` means the load balancer wrote the 502 itself, not the app.

## What I checked

| # | What I checked | Tool / command | Result | What it ruled in or out |
|---|---|---|---|---|
| 1 | Who produced the error | `curl -i` on the shop URL | 502, `Server: awselb/2.0` | The ALB generated it. The app never answered |
| 2 | What the ALB thinks of its targets | `aws elbv2 describe-target-health` | Both targets `unhealthy`, `Target.FailedHealthChecks`, registered on port **80** | Targets exist (so not a 503). Health checks fail on port 80 |
| 3 | My first guess: SG or NACL blocking (dead end) | Reasoning about the symptom | A SG or NACL drops packets, which gives `Target.Timeout` and 504. I had `FailedHealthChecks` and 502 | Ruled out the network. Something was refusing fast, not dropping |
| 4 | The health check from inside the instance | Session Manager, `curl -sS -i localhost:80/health` | `Failed to connect ... after 0 ms` | Not SG, NACL or ALB, because localhost skips all of them |
| 5 | My second guess: host firewall (dead end) | Reasoning | AL2023 has no host firewall by default, and a firewall would drop, not refuse | Ruled out. An instant refusal means nothing listens on the port |
| 6 | What actually listens | `sudo ss -tlnp` | `python3` on `0.0.0.0:8080`, nothing on 80 | Found it: the app is on 8080 |
| 7 | Is the app itself fine | `curl localhost:8080/health` | `ok` | The app was healthy the whole time |

## Root cause

The shop listens on port 8080, but the target group sends traffic and health checks to port 80.
Nothing listens on 80, so the instance refuses every connection, the health checks fail and both
targets go unhealthy. With all targets unhealthy the ALB fails open and keeps sending requests
to them, and every refused connection comes back to the customer as a 502.

## Fix

I changed the target group in `alb.tf` from `port = 80` to `port = 8080`. I fixed the
infrastructure, not the app: the release only changed infrastructure, and the app runs as a
non-root user, so it can't bind port 80 anyway.

**Mistake I made first:** I changed the listener's `port = 80` instead of the target group's.
`terraform plan` showed `aws_lb_listener.http` going `80 -> 8080`, and I stopped before applying.
That change would have moved the customer-facing port, which the ALB security group doesn't
allow, and left the real bug in place. It would have turned a 502 into a full outage.

The correct plan was `3 to add, 1 to change, 3 to destroy`. A target group's port can't change
in place, so Terraform replaced it. `create_before_destroy` built the new one first, the listener
switched to it in place, and the two instances were registered again.

Verified:

- `describe-target-health`: both targets `healthy` on 8080
- Four `curl` requests: "Orders shop" served by both instance IDs
- `terraform plan`: No changes

Then `terraform destroy`. Load balancer gone (`[]`), both instances `terminated`.

## How I'd detect it in production

- An alarm on `UnHealthyHostCount` ≥ 1 or `HealthyHostCount` < 1 for the target group. It fires
  when targets go unhealthy, even while the ALB fails open and hides it.
- An alarm on `HTTPCode_ELB_5XX_Count`. Comparing it with `HTTPCode_Target_5XX_Count` shows
  straight away whether the load balancer or the app produced the errors.
- A smoke test after every deploy: wait for the targets to be healthy, then `curl --fail` the
  public URL, and fail the pipeline if it doesn't work.
- Prevention: define the app port once (for example `locals { app_port = 8080 }`) and use it for
  both the user data and the target group, so the two can't drift apart.

## What I take from it

- Read the response headers first. They tell you which layer answered.
- 502 = refused or bad answer. 503 = no targets. 504 = no answer in time (often SG/NACL).
- `curl localhost` on the instance removes the whole network from the question in one step.
- Always read the `terraform plan` before typing `yes`. Today it saved me from an outage.
