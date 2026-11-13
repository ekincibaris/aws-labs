# 02 · Fleet doesn't scale out under load

- **Lab:** `breakfix/02-asg-not-scaling`
- **Date:** 13 November 2026
- **Time spent:** about 35 minutes, deploy to destroy
- **Hints used:** 0 from `hints.md`. I worked through it with Claude asking me questions. Honest
  note: after a failed first apply, `terraform plan` showed `suspended_processes` as drift, so I
  had seen the answer before I found it with the evidence chain.

## Symptom

Ticket INC-3104: the transcoding fleet `asg-lab-workers` (min 1, max 3) should add servers above
40 % average CPU. CPU sits around 50 % and the scaling alarm is **In alarm**, but there is still
exactly one instance.

What I saw myself:

```
AlarmHigh   ALARM
AlarmLow    OK
Desired 1 · Min 1 · Max 3 · Instances 1
```

## Before the incident: the deploy itself failed

The first `terraform apply` stopped with:

```
waiting for Auto Scaling Group (asg-lab-workers) capacity satisfied:
Failed: Authentication Failure. Launching EC2 instance failed.
```

Terraform created the instance profile and launched the first instance about 12 seconds later.
IAM is eventually consistent, so EC2 couldn't see the new profile yet. I didn't apply again blindly:

| # | What I checked | Tool / command | Result | What it ruled in or out |
|---|---|---|---|---|
| 1 | Full error and timing | `describe-scaling-activities`, `Activities[0]` | Same one-line message; launch tried 1 s after the group was created | Timing fits an IAM propagation race |
| 2 | Does the ASG heal itself | `describe-scaling-activities`, all activities | `Failed` at 17:31:43, then `WaitingForInstanceWarmup` at 17:32:47 | Race confirmed. The retry a minute later worked, so not a permanent IAM or KMS problem |
| 3 | What Terraform wants to do now | `terraform plan` | ASG **tainted** (replace), policy never created, `enabled_metrics` and `suspended_processes` missing on the live group | The provider sets those two attributes only after the capacity wait, which never finished |

Fix: `terraform untaint aws_autoscaling_group.workers`, then `plan` showed `1 to add, 1 to change,
0 to destroy` and I applied. The healthy group was kept instead of being replaced.

## What I checked

My map of the chain: **CPU metric → alarm → scaling policy → ASG receives it → desired capacity
+1 → launch activity → new EC2**. My first version skipped the policy and the desired-capacity
step. I wrote "CloudWatch something" and "I don't know".

| # | What I checked | Tool / command | Result | What it ruled in or out |
|---|---|---|---|---|
| 1 | Is the alarm wired to the policy | `describe-alarms`, `AlarmActions[0]` | Both alarms point to `scalingPolicy:...:policyName/asg-lab-cpu-target-40` | Alarm → policy link is intact |
| 2 | Is the alarm firing (too early the first time) | `describe-alarms` at 18:37, then 18:45 | First `OK` (not enough datapoints yet), then AlarmHigh `ALARM` | Metric and alarm work |
| 3 | Is the group at its maximum | `describe-auto-scaling-groups` with a `{Desired,Min,Max}` query | Desired 1, Max 3 | Ruled out `max_size` |
| 4 | Did the ASG try and fail, or not try at all | `describe-scaling-activities` | Last activity 17:32 UTC, before the policy existed (17:35 UTC). Nothing after, no `Failed` | Ruled out failed launches. The ASG ignores the signal |
| 5 | My guess: empty `TargetGroupARNs` (dead end) | Full `describe-auto-scaling-groups` | `[]` | Normal: these workers take no traffic, and a target group sits after the launch, not between the alarm and the ASG |
| 6 | What on the group blocks alarms | Same output, `SuspendedProcesses` | `AlarmNotification`, "User suspended at 2026-11-13T17:35:30Z" | Root cause. The time matches my own `terraform apply`, so the code did it |

## Root cause

The Auto Scaling group has the `AlarmNotification` process suspended. Target tracking scales
through its CloudWatch alarms, so AlarmHigh fired and called the policy, but the group threw every
notification away. It never changed the desired capacity and never started a scaling activity.
The suspension came from `suspended_processes = ["AlarmNotification"]` in `asg.tf`.

## Fix

I deleted the `suspended_processes` line in `asg.tf`. `terraform plan -out tfplan` showed only
`suspended_processes` going from `["AlarmNotification"]` to empty, and `terraform apply tfplan`
resumed the process. A CLI `resume-processes` would have been undone by the next apply.

Verified:

- Activity history: at 17:52 UTC "a monitor alarm ... AlarmHigh ... in state ALARM triggered policy
  asg-lab-cpu-target-40 changing the desired capacity from 1 to 2", and at 17:54 from 2 to 3
- It stopped at 3 (`max_size`), because every new worker also runs at about 50 % CPU
- `terraform plan`: No changes

Then `terraform destroy` (15 resources). The group query returned `[]` and no instances with the
`Lab` tag were left in pending, running or stopping. I restored `asg.tf` with `git restore` so the
lab stays broken for the next run.

Side finding: the saved `tfplan` showed up as untracked. The root `.gitignore` didn't cover it,
so I added `tfplan` and `*.tfplan` repo-wide (commit `fd98e89`). Plan files can contain secrets.

## How I'd detect it in production

- An EventBridge rule on CloudTrail `SuspendProcesses` calls from `autoscaling.amazonaws.com`,
  sent to SNS, so a suspension never goes unnoticed.
- A second, slower alarm on the group's average CPU (for example above 70 % for 15 minutes).
  It catches every reason scaling stalls: suspended processes, `max_size` reached, failed launches.
- `GroupDesiredCapacity` next to `CPUUtilization` on a dashboard. "Alarm fires, desired stays flat"
  is visible at a glance.
- Prevention: an AWS Config rule that flags any group with non-empty `suspendedProcesses`, and
  maintenance through an SSM Automation runbook that always resumes the processes in its last step.

## What I take from it

- Write the whole chain before troubleshooting. The bug sat in a link I had left out of my map.
- The Activity history tells three causes apart: nothing new and desired = max (max reached),
  `Failed` entries (launch fails), or nothing at all while desired < max (the ASG ignores alarms).
- AWS timestamps are UTC. Budapest is UTC+1 in winter.
- A failed `terraform apply` can leave a half-configured resource. Read the plan, and use
  `untaint` when the resource is actually healthy.
