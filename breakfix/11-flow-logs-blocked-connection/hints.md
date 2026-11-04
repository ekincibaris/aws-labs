# Hints · 11 Find the blocked connection with VPC Flow Logs

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

Start with the evidence, not the configuration. In CloudWatch **Logs Insights**, query `/vpc/flowlogs-lab` for traffic to port 8080:

```
fields @timestamp, interfaceId, srcAddr, dstAddr, dstPort, action
| filter dstPort = 8080
| sort @timestamp desc
| limit 50
```

Look at the `action`, and then look closely at **which network interface** recorded each line and at the **addresses** involved.

</details>

<details>
<summary>Hint 2</summary>

The `REJECT` records for port 8080 are on inventory-api's network interface, but the source address isn't reporting-01's **private** IP. Whose address is it? Compare it with both the private and the public IPv4 addresses of the two instances in the EC2 console. Then look at the destination address in the matching records on reporting-01's interface.

</details>

<details>
<summary>Hint 3</summary>

The stock report calls inventory-api by its **public** IP address. That traffic leaves the VPC through the internet gateway and comes back in with reporting-01's **public** IP as the source. A security group rule that references another security group only matches traffic from the **private** IP addresses of the interfaces in that group, so the rule doesn't apply and the packet is rejected. Point the report at inventory-api's private address.

</details>
