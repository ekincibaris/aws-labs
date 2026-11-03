# Hints · 10 App can't reach its database across VPC peering

Open one hint at a time. Give yourself at least ten minutes with each before opening the next.

<details>
<summary>Hint 1</summary>

A **timeout** means packets are silently dropped somewhere, not refused. A TCP connection needs packets in **both** directions: the SYN from the app server to the database, and the SYN-ACK from the database back to the app server. Check the path for each direction separately.

</details>

<details>
<summary>Hint 2</summary>

Security groups are stateful: if the request is allowed in, the reply is allowed out automatically. **Routing isn't stateful.** Every packet, replies included, is routed by the route table of the subnet it **leaves** from.

Find the database's subnets (RDS → Connectivity & security), then compare the route tables on **both** sides of the peering connection.

</details>

<details>
<summary>Hint 3</summary>

VPC peering needs a route in **both** VPCs. The app subnet's route table sends `10.100.0.0/16` to the peering connection, but the data subnets' route table has no route to `10.10.0.0/16`. The database receives the SYN, but its SYN-ACK has nowhere to go and is dropped. Add the return route.

</details>
