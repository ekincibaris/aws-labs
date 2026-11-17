When the memory alarm stayed OK despite high memory usage, describe-alarms showed no datapoints arrived while treat_missing_data was notBreaching.
Running list-metrics for mem_used_percent showed the agent sent ImageId, InstanceId, and InstanceType, while the alarm only had InstanceId.
Because CloudWatch identifies a metric by its namespace, name, and complete set of dimensions, the alarm watched a metric that did not exist and notBreaching hid the missing data as OK.
I updated the alarm's dimensions block in monitoring.tf to include all three dimensions, which fixed the issue.
To prevent this, we should define the dimension list once in Terraform for both the agent and the alarm, and set treat_missing_data to missing so silent mismatches show up as INSUFFICIENT_DATA.
