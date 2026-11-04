# Hints · 05 Instance missing from Systems Manager

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

The permissions look right and the endpoints exist, so follow the network path the agent takes. Which **hostname** does SSM Agent connect to, and what **IP address** does that name resolve to from inside this VPC?

</details>

<details>
<summary>Hint 2</summary>

`AWSSupport-TroubleshootManagedInstance` checks security groups, network ACLs, routes, endpoint security groups and the instance profile. If it finds nothing, the problem is somewhere it doesn't look.

Open a CloudShell **VPC environment** in the subnet `ssm-lab-private` (use the security group `ssm-lab-batch-sg`) and run:

```bash
getent hosts ssm.eu-central-1.amazonaws.com
```

Are those addresses inside `10.5.0.0/16`? Compare them with the private IPs of the endpoints' network interfaces.

</details>

<details>
<summary>Hint 3</summary>

The agent always connects to the Regional service names such as `ssm.eu-central-1.amazonaws.com`. Inside a VPC, those names resolve to the interface endpoints' private IPs only when the endpoints have **private DNS names enabled**. Without it they resolve to public AWS IP addresses, and this isolated subnet can't reach those. Check that setting on all three endpoints.

</details>
