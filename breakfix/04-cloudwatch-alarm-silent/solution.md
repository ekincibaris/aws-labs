# Solution · 04 Memory alarm stays green

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The alarm watches **a metric that doesn't exist**.

- The CloudWatch agent's configuration has `append_dimensions` set to `ImageId`, `InstanceId` and `InstanceType`. The agent publishes `CWAgent / mem_used_percent` with exactly those **three** dimensions.
- The alarm asks for `CWAgent / mem_used_percent` with **one** dimension: `InstanceId`.
- CloudWatch identifies a metric by namespace, name **and the complete set of dimensions**. `{InstanceId}` and `{ImageId, InstanceId, InstanceType}` are two different metrics, and only the second one has data.

Normally an alarm without data shows `INSUFFICIENT_DATA`, which is at least suspicious. This alarm has `treat_missing_data = "notBreaching"`, so CloudWatch treats every missing datapoint as "fine" and the alarm stays **OK**. The second setting hid the first mistake.

## Evidence

```bash
aws cloudwatch describe-alarms --alarm-names alarm-lab-orders-cache-memory-high \
  --query 'MetricAlarms[0].{State:StateValue,Dims:Dimensions,Missing:TreatMissingData,Reason:StateReason}'
# Dims: [InstanceId], Missing: notBreaching, Reason mentions "no datapoints were received"

aws cloudwatch list-metrics --namespace CWAgent --metric-name mem_used_percent
# One metric, with three dimensions: ImageId, InstanceId, InstanceType
```

On the instance: `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json` shows `append_dimensions`. `free -m` confirms that memory use really is high.

## Fix

**Terraform.** Make the alarm match the metric the agent publishes. In `monitoring.tf`:

```hcl
dimensions = {
  InstanceId   = aws_instance.cache.id
  ImageId      = aws_instance.cache.ami
  InstanceType = aws_instance.cache.instance_type
}

treat_missing_data = "missing"   # no data shows up as INSUFFICIENT_DATA
```

Run `terraform apply`. Within about 3 minutes (3 datapoints of 60 seconds each) the alarm goes to **ALARM**.

Changing `treat_missing_data` isn't needed for the alarm to fire, but it stops the next mistake like this one from hiding. For an important alarm, `missing` (show `INSUFFICIENT_DATA`) or even `breaching` is safer than `notBreaching`.

**Alternative: change what the agent publishes.** Either remove `ImageId` and `InstanceType` from `append_dimensions`, or keep them and add a roll-up:

```json
"metrics": {
  "aggregation_dimensions": [["InstanceId"]],
  ...
}
```

With `aggregation_dimensions`, the agent also publishes `mem_used_percent` with only `InstanceId`. That's one extra custom metric ($0.30/month). Either way, reload the agent afterwards with `sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`. Keep in mind that every instance replacement changes the `InstanceId` dimension, which is why fleets usually alarm on `AutoScalingGroupName` instead.

## Detect it earlier in production

- **Treat "no data" as a signal.** Use `treat_missing_data = "missing"` or `"breaching"` on alarms that matter, and report alarms that stay in `INSUFFICIENT_DATA` for more than a day (`aws cloudwatch describe-alarms --state-value INSUFFICIENT_DATA`).
- **Check alarms against real metrics.** A scheduled job, such as a Lambda function or an SSM Automation runbook, can read every alarm's namespace, metric name and dimensions and run `list-metrics` with exactly those values. An alarm whose metric has no match is broken.
- **Build dashboards from the published metric**, not from the alarm. A dashboard that shows `mem_used_percent` next to the alarm makes the mismatch obvious.

## Prevent it with automation

- **Manage the agent config and the alarm together.** Keep the agent configuration in SSM Parameter Store (`AmazonCloudWatch-*`) and push it to the fleet with the `AmazonCloudWatch-ManageAgent` SSM document. Generate the alarms in the same Terraform module from the same list of dimensions, so the two can't drift apart.
- **Post-deploy check.** After an apply, the pipeline waits for the first datapoint (`aws cloudwatch get-metric-statistics` with the alarm's exact dimensions) and fails if nothing arrives within 10 minutes.
- **Policy-as-code** can reject `treat_missing_data = "notBreaching"` on alarms tagged as critical.

## Exam takeaways

- Metric identity = **namespace + metric name + all dimensions**. A partial match returns nothing.
- The CloudWatch agent collects memory and disk metrics, which EC2 doesn't provide by default. `append_dimensions` adds EC2 dimensions; `aggregation_dimensions` publishes roll-ups. The instance needs `CloudWatchAgentServerPolicy`.
- `TreatMissingData`: `missing` (default, `INSUFFICIENT_DATA`), `notBreaching` (counts as OK), `breaching` (counts as ALARM), `ignore` (keeps the current state).
- `datapoints_to_alarm` together with `evaluation_periods` gives "M out of N" alarms, which help against noisy metrics.
