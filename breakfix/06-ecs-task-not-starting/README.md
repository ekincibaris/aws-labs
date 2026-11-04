# 06 · ECS service never reaches Running

| | |
|---|---|
| **SOA-C03 domain** | Domain 3: Deployment, Provisioning, and Automation. Task 3.1, skill 3.1.3 (identify and remediate deployment issues, for example permissions issues). Also Domain 4, skill 4.2.4 (securely store secrets) |
| **Difficulty** | Medium |
| **Cost** | ≈ €0.00 per hour while broken, ≈ €0.02 per hour once the task runs |
| **Time** | 30–45 minutes |

## What gets deployed

- A VPC with two public subnets
- An ECS cluster with a Fargate service `ecs-lab-orders-api` (desired count 1, ARM64, 0.25 vCPU / 0.5 GB)
- A task definition that injects the database password from **SSM Parameter Store** (`/ecs-lab/orders-api/db-password`, a SecureString) as the environment variable `DB_PASSWORD`, and sends container logs to CloudWatch Logs
- Two IAM roles for the service: `ecs-lab-orders-api-execution` and `ecs-lab-orders-api-task`

## Deploy

```bash
cd breakfix/06-ecs-task-not-starting
terraform init
terraform apply
```

## Incident ticket

> **INC-7702 · Priority P2 · orders-api won't start since the password moved to Parameter Store**
>
> **Reported by:** Backend team
>
> Yesterday we moved the database password out of the task definition into Parameter Store (`/ecs-lab/orders-api/db-password`) and gave the service an IAM policy that allows reading it. Since then the service `ecs-lab-orders-api` shows **Desired: 1, Running: 0**. Tasks appear for a few seconds and then disappear again. Our log group doesn't contain a single line.

## Allowed tools

- **Console:** ECS (the service's **Events** tab, **Tasks** → filter on *Stopped* → stopped reason), IAM (roles, **Policy simulator**), Systems Manager → Parameter Store, CloudTrail → Event history
- **CLI:** `aws ecs describe-services`, `aws ecs list-tasks --desired-status STOPPED`, `aws ecs describe-tasks`, `aws iam simulate-principal-policy`
- **CloudWatch:** Logs (the log group `/ecs/ecs-lab-orders-api`)

Don't read the `.tf` files until you have written your diagnosis in `notes/`.

## Definition of done

- The service shows **Running: 1**, and the task stays in `RUNNING`.
- The log group `/ecs/ecs-lab-orders-api` contains the container's start-up lines.
- The fix uses least privilege: no `AdministratorAccess`, no `ssm:*`, no `"Resource": "*"` for the parameter.
- The fix is in the Terraform code: `terraform plan` shows no changes.

## Cost and clean-up

| Resource | Price in eu-central-1 |
|---|---|
| Fargate ARM64, 0.25 vCPU | $0.0093/h, only while a task runs |
| Fargate ARM64, 0.5 GB memory | $0.0020/h, only while a task runs |
| Public IPv4 address of the task | $0.005/h, only while a task runs |
| Parameter Store (standard), CloudWatch Logs | free / fractions of a cent |
| **Total** | **≈ $0.016/h ≈ €0.02/h with one running task** |

> **Destroy reminder:** run `terraform destroy` when you're done. Left running with a healthy task, this lab costs about €11 a month.

## When you're stuck

1. [hints.md](hints.md) has three hints, from vague to specific. Open them one at a time.
2. [solution.md](solution.md) has the root cause and the fix. Read it only once you've finished.
3. Write up what you found in your own notes: copy [`notes/TEMPLATE.md`](../../notes/TEMPLATE.md).
