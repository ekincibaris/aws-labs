# Solution · 01 Shop returns 502 Bad Gateway

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The target group forwards to **port 80**, but the shop service listens on **port 8080**.

1. The web servers' security group allows all traffic from the load balancer, so the connection reaches the instance. Nothing listens on port 80, so the kernel answers with a **TCP RST** (connection refused).
2. Health checks use `traffic-port`, which is 80 too, so they fail and both targets become **unhealthy** (`Target.FailedHealthChecks`).
3. When all targets are unhealthy, the ALB **fails open** and keeps sending requests to them. Every request gets a TCP RST, and the load balancer returns **502 Bad Gateway**.

The app was fine all along. The infrastructure pointed at the wrong port.

## Evidence

```bash
TG=$(terraform output -raw target_group_arn)

aws elbv2 describe-target-health --target-group-arn "$TG" \
  --query 'TargetHealthDescriptions[].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]' \
  --output table
# Both targets: port 80, unhealthy, Target.FailedHealthChecks
```

On a web server, through Session Manager:

```bash
sudo ss -tlnp                         # python3 listens on 0.0.0.0:8080, nothing on :80
curl -sS localhost:80/health          # Connection refused
curl -sS localhost:8080/health        # ok
```

In CloudWatch, `AWS/ApplicationELB`: `HTTPCode_ELB_502_Count` rises with every request. `TargetConnectionErrorCount` (connections the load balancer couldn't establish with a target) rises at the same rate. `HTTPCode_Target_5XX_Count` stays at zero, because the app never received a request.

## Fix

**Terraform (the permanent fix).** In `alb.tf`, set the target group's `port = 8080` and run `terraform apply`. A target group's port can't change in place. The target group has `name_prefix` and `create_before_destroy`, so Terraform creates the new target group first, moves the listener and the registrations to it, then deletes the old one. After 30–60 seconds both targets are healthy.

**Console or CLI (the quick fix during an incident).** You can't edit a target group's port, but you can register the same instances again on another port:

```bash
aws elbv2 register-targets   --target-group-arn "$TG" --targets Id=i-aaaa,Port=8080 Id=i-bbbb,Port=8080
aws elbv2 deregister-targets --target-group-arn "$TG" --targets Id=i-aaaa,Port=80   Id=i-bbbb,Port=80
```

In the console: target group → **Targets** → **Register targets** → select both instances → port **8080** → **Include as pending below** → **Register pending targets**. Then deregister the two port-80 entries.

If you used the quick fix, still change the code and run `terraform apply`. Otherwise the next apply puts the port-80 registrations back.

## Detect it earlier in production

- **Alarm on target health:** `UnHealthyHostCount` ≥ 1 (Maximum, 2 of 2 minutes) per target group, or `HealthyHostCount` < 1. This fires before customers notice, even while the ALB fails open.
- **Alarm on the load balancer's own errors:** `HTTPCode_ELB_5XX_Count` and `TargetConnectionErrorCount` > 0. Comparing them with `HTTPCode_Target_5XX_Count` tells you straight away whether the load balancer or the app produced the errors.
- **ALB access logs** (to S3) show `elb_status_code` 502 with `target_status_code` `-`: the target never sent an HTTP response.
- **An outside-in check:** a CloudWatch Synthetics canary or a Route 53 health check against the public URL.

## Prevent it with automation

- **One source of truth for the port.** Define the application port once, for example `locals { app_port = 8080 }`, and use it for both the user data (via `templatefile`) and the target group. A mismatch like this can't be written any more.
- **Post-deployment smoke test in the pipeline.** After `terraform apply`, run `aws elbv2 wait target-in-service --target-group-arn ...` followed by `curl --fail` against the load balancer, and fail the pipeline if either doesn't succeed.
- **Deployments that roll back on health.** Auto Scaling instance refresh, CodeDeploy and the ECS deployment circuit breaker can all stop or roll back a rollout when new targets don't become healthy.

## Exam takeaways

- **502**: the target refused the connection, reset it, or sent a malformed response. **503**: no registered targets. **504**: no connection within 10 seconds, or no response within the idle timeout (often a security group or NACL that drops traffic).
- When every target is unhealthy, an ALB **fails open** and routes to all of them.
- Health check reason codes point to the cause: `Target.FailedHealthChecks` (connection refused or bad response), `Target.Timeout`, `Target.ResponseCodeMismatch`, `Target.NotRegistered`.
- The instance security group must allow the load balancer's security group on both the **traffic port** and the **health check port**.
