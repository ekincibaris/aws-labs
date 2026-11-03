# Hints · 02 Fleet doesn't scale out under load

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

An alarm in the **ALARM** state is only half the story. Follow the signal from the alarm to the Auto Scaling group. What does the alarm try to do when it fires, and does the group record anything in its **Activity** history?

</details>

<details>
<summary>Hint 2</summary>

The policy is attached and its alarm is firing. The group isn't at its maximum size, and there are no failed launches in its Activity history, because it never even tries. Something configured **on the Auto Scaling group itself** makes it ignore the alarm.

Open the group's **Details** tab and scroll down to **Advanced configurations**.

</details>

<details>
<summary>Hint 3</summary>

You can suspend individual Auto Scaling processes: `Launch`, `Terminate`, `HealthCheck`, `ReplaceUnhealthy`, `AZRebalance`, `AlarmNotification`, `ScheduledActions`, `AddToLoadBalancer` and `InstanceRefresh`. One of them stops the group from acting on CloudWatch alarms, so neither target tracking nor step scaling can work. Resume it, and make the change in the code too.

</details>
