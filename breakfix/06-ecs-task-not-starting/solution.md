# Solution · 06 ECS service never reaches Running

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The permission to read the password was attached to the **wrong role**.

- The task definition injects `DB_PASSWORD` through `secrets` → `valueFrom` = the Parameter Store ARN.
- ECS resolves `secrets` **before the container starts**. Fargate does that with the **task execution role** (`ecs-lab-orders-api-execution`).
- The policy `read-db-password` (`ssm:GetParameters` on the parameter) is attached to the **task role** (`ecs-lab-orders-api-task`). That role is only used later, by code inside the running container.
- The execution role only has `AmazonECSTaskExecutionRolePolicy` (ECR pulls and CloudWatch Logs), which doesn't include Parameter Store.

The task fails during initialisation, the container never starts, so the log group stays empty. The service scheduler keeps retrying, with growing intervals between attempts.

## Evidence

```bash
CLUSTER=ecs-lab-cluster
TASK=$(aws ecs list-tasks --cluster $CLUSTER --desired-status STOPPED --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster $CLUSTER --tasks "$TASK" --query 'tasks[0].[stopCode,stoppedReason]'
# "TaskFailedToStart",
# "ResourceInitializationError: unable to pull secrets or registry auth: ... unable to retrieve secrets from ssm:
#  ... AccessDeniedException: User: arn:aws:sts::<account>:assumed-role/ecs-lab-orders-api-execution/<task-id>
#  is not authorized to perform: ssm:GetParameters on resource: arn:aws:ssm:eu-central-1:<account>:parameter/ecs-lab/orders-api/db-password ..."

aws iam list-role-policies --role-name ecs-lab-orders-api-task        # read-db-password  <- here
aws iam list-role-policies --role-name ecs-lab-orders-api-execution   # (none)
```

The service's **Events** tab says *service ecs-lab-orders-api has started 1 tasks* over and over. CloudTrail shows the denied `GetParameters` calls, made by the execution role.

## Fix

**Terraform.** Attach the policy to the execution role. In `iam.tf`:

```hcl
resource "aws_iam_role_policy" "read_db_password" {
  name = "read-db-password"
  role = aws_iam_role.execution.id   # was aws_iam_role.task.id
  # policy unchanged
}
```

Run `terraform apply`. The next task launch succeeds. To skip the scheduler's back-off, force a new deployment:

```bash
aws ecs update-service --cluster ecs-lab-cluster --service ecs-lab-orders-api --force-new-deployment
```

If the application ever reads the parameter itself at runtime (with the SDK), the **task role** needs the permission too. In this lab it doesn't: ECS injects the value.

Parameter Store SecureStrings encrypted with the default key `alias/aws/ssm` need no extra KMS permission. With a **customer managed** KMS key, the execution role also needs `kms:Decrypt` on that key.

**Console.** IAM → Roles → `ecs-lab-orders-api-execution` → **Add permissions** → **Create inline policy** with `ssm:GetParameters` on the parameter ARN. Remove it from the task role. Then make the same change in the code.

## Detect it earlier in production

- **EventBridge on task failures.** A rule with the pattern `{"source": ["aws.ecs"], "detail-type": ["ECS Task State Change"], "detail": {"lastStatus": ["STOPPED"], "stopCode": ["TaskFailedToStart"]}}` sends the `stoppedReason` to SNS or chat within seconds.
- **Running versus desired tasks.** With Container Insights, alarm on `RunningTaskCount` < `DesiredTaskCount` for 5 minutes. Without it, a scheduled check of `describe-services` (`runningCount` versus `desiredCount`) does the same job.
- **The deployment circuit breaker** (`deployment_circuit_breaker { enable = true, rollback = true }`) marks a deployment as FAILED after repeated failed task launches and emits an event you can alert on.

## Prevent it with automation

- **The circuit breaker with rollback** stops a broken revision from replacing a working one. The old tasks keep serving while you investigate.
- **Derive permissions from the task definition.** A small Terraform module that takes the list of secrets and generates both the `secrets` block and the execution role policy makes it impossible to forget one side.
- **Test permissions in CI.** Run `aws iam simulate-principal-policy` with the **execution role** for `ssm:GetParameters` on every parameter in `secrets`, and fail the pipeline if any result isn't `allowed`.

## Exam takeaways

- **Task execution role:** pulls images from ECR, writes to CloudWatch Logs, and fetches `secrets` from Parameter Store or Secrets Manager. **Task role:** the permissions of your application code.
- Common `stoppedReason` values: `ResourceInitializationError` (secrets, registry auth, log configuration, network path to AWS APIs), `CannotPullContainerError` (image doesn't exist, missing ECR permission, no route to the registry), `EssentialContainerExited` (the app itself crashed; check the container logs).
- Fargate tasks need a network path to ECR, CloudWatch Logs and Parameter Store or Secrets Manager: a public IP, a NAT gateway, or VPC endpoints.
