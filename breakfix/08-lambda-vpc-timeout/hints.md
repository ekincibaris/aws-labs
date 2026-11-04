# Hints · 08 Lambda times out since it moved into the VPC

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

A **timeout** rather than an error means the function sent packets and waited for an answer that never came. Follow the traffic out of the VPC. Which subnets is the function attached to, and what does each of their route tables say about `0.0.0.0/0`?

</details>

<details>
<summary>Hint 2</summary>

The function's subnets send `0.0.0.0/0` to the **internet gateway**. An internet gateway only works for network interfaces that have a **public IPv4 address**.

Look at the function's network interfaces under EC2 → **Network interfaces**; their description starts with `AWS Lambda VPC ENI`. Do they have a public IP? Could you give them one?

</details>

<details>
<summary>Hint 3</summary>

Lambda's VPC network interfaces only ever get **private** IP addresses, and you can't attach a public IP or an Elastic IP to them. A function in a VPC reaches the internet only from **private subnets whose default route points to a NAT gateway**. The NAT gateway itself sits in a public subnet. Attach the function to the right subnets.

</details>
