# Solution · 02 Fleet doesn't scale out under load

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The Auto Scaling group has the **`AlarmNotification` process suspended**.

Target tracking works through CloudWatch alarms. The policy created two alarms (`TargetTracking-asg-lab-workers-AlarmHigh-…` and `…-AlarmLow-…`). The high alarm correctly went to `ALARM` because the average CPU (≈ 50 %) is above the target (40 %). While `AlarmNotification` is suspended, though, the group ignores every alarm notification. It never starts a scaling activity, and the desired capacity stays at 1.

Somebody probably suspended the process during a maintenance window ("don't let it scale while we patch") and never resumed it. In this lab, the Terraform code does it.

## Evidence

```bash
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names asg-lab-workers \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Max:MaxSize,Suspended:SuspendedProcesses}'
# Suspended: [{"ProcessName": "AlarmNotification", "SuspensionReason": "User suspended at ..."}]

aws autoscaling describe-scaling-activities --auto-scaling-group-name asg-lab-workers \
  --query 'Activities[].[StartTime,StatusCode,Description]' --output table
# Only the initial launch. Nothing after the alarm fired.

aws cloudwatch describe-alarms --alarm-name-prefix TargetTracking-asg-lab-workers \
  --query 'MetricAlarms[].[AlarmName,StateValue]' --output table
# AlarmHigh in ALARM
```

In the console: Auto Scaling group → **Details** → **Advanced configurations** → **Suspended processes: AlarmNotification**. CloudTrail **Event history** shows the `SuspendProcesses` call, who made it and when.

## Fix

**Terraform (the permanent fix).** In `asg.tf`, delete the `suspended_processes = ["AlarmNotification"]` line and run `terraform apply`. Terraform calls `ResumeProcesses` for you.

**Console or CLI (the quick fix during an incident).**

```bash
aws autoscaling resume-processes --auto-scaling-group-name asg-lab-workers \
  --scaling-processes AlarmNotification
```

In the console: **Details** → **Advanced configurations** → **Edit** → remove `AlarmNotification` from **Suspended processes** → **Update**.

If you only resume it by hand, the next `terraform apply` suspends it again. Always fix the code too.

**What happens next.** For alarms with Auto Scaling actions, CloudWatch keeps invoking the action **every minute while the alarm stays in ALARM**. You don't have to wait for a new state change. Within a minute or two the Activity tab shows *Launching a new EC2 instance*, the desired capacity goes from 1 to 2 and then to 3, and it stops at `max_size`.

## Detect it earlier in production

- **Alert on the suspension itself.** An EventBridge rule on `AWS API Call via CloudTrail` events with `"eventSource": ["autoscaling.amazonaws.com"]` and `"eventName": ["SuspendProcesses"]` can notify the team through SNS. These events need a CloudTrail trail. Add a reminder that fires again if the process is still suspended a few hours later.
- **Alert when scaling isn't helping.** A second CloudWatch alarm on the group's average CPU, with a higher threshold and a longer window (for example > 70 % for 15 minutes), catches every reason scaling can stall: suspended processes, `max_size` reached, failed launches, a lack of capacity.
- **Watch the group metrics.** With `GroupDesiredCapacity` next to `CPUUtilization` on a dashboard, "the alarm fires and the desired capacity stays flat" is obvious at a glance.

## Prevent it with automation

- **Make suspend and resume one unit of work.** If maintenance needs scaling paused, use an SSM Automation runbook that suspends the processes, does the work, and resumes them in a final step that runs even when an earlier step fails.
- **Continuous compliance.** An AWS Config custom rule (Guard or Lambda) on `AWS::AutoScaling::AutoScalingGroup` can flag any group whose `suspendedProcesses` isn't empty. An automatic remediation can then call `ResumeProcesses`.
- **Code review and drift detection.** Policy-as-code in CI can reject `suspended_processes` in Terraform. A scheduled `terraform plan` shows when someone changed the group by hand.

## Exam takeaways

- Suspending **`AlarmNotification`** stops all alarm-driven scaling (target tracking and step scaling). **`ScheduledActions`** stops scheduled scaling. **`Launch`** or **`Terminate`** freeze the group completely. **`HealthCheck`** and **`ReplaceUnhealthy`** stop instances from being replaced.
- Target tracking creates and manages its own alarms. Don't edit or delete them. Scaling out is fast (3 datapoints); scaling in is deliberately slow (15 datapoints).
- Other reasons a group doesn't scale: `max_size` reached, cooldown or instance warmup, launch failures (look in the Activity history: wrong AMI architecture, missing IAM permissions, capacity errors), or a metric that never crosses the threshold.
