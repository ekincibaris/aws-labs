# Hints · 04 Memory alarm stays green

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

An alarm in **OK** doesn't prove that the alarm works. Open the alarm and look at its graph: does it have any datapoints? Then go and find the memory metric the agent actually publishes, and compare the two.

</details>

<details>
<summary>Hint 2</summary>

In CloudWatch → **All metrics** → `CWAgent`, `mem_used_percent` shows up under a group of **several** dimensions. A CloudWatch metric is identified by its namespace, its name and **every** dimension. An alarm only gets data when it specifies exactly the same set.

Compare that set with the alarm's `Dimensions` (`aws cloudwatch describe-alarms`). Then look up what the alarm's `TreatMissingData` setting does when there is no data.

</details>

<details>
<summary>Hint 3</summary>

The agent configuration uses `append_dimensions` to add `ImageId`, `InstanceId` and `InstanceType` to every metric. The alarm only specifies `InstanceId`, so it watches a metric that doesn't exist. `treat_missing_data = "notBreaching"` turns "no data" into a green OK. Make the alarm's dimensions match what the agent publishes, or change what the agent publishes.

</details>
