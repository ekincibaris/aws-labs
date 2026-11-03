# Solution · 11 Find the blocked connection with VPC Flow Logs

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The Parameter Store value `/flowlogs-lab/inventory-url` points to inventory-api's **public IP address**: `http://<public-ip>:8080/stock.json`.

1. reporting-01 sends its request to that public IP. Its route table sends traffic for public addresses to the **internet gateway**, so the packets leave the VPC, even though both servers are in it.
2. The internet gateway translates the addresses. When the packet comes back in, its source is reporting-01's **public** IP, and its destination is inventory-api's private IP.
3. inventory-api's security group allows port 8080 from the security group `flowlogs-lab-reporting-sg`. A rule that **references a security group** matches traffic from the **private IP addresses** of the interfaces in that group, never their public or Elastic IPs.
4. No rule matches, the security group drops the SYN, and the flow log records `REJECT`. The report waits until curl gives up: `Connection timed out`.

Both teams were right about their own part: the security group rule is correct, and the service works. The bug was in the address the inventory team published after the redeploy.

## Evidence

Logs Insights on `/vpc/flowlogs-lab`:

```
filter dstPort = 8080
| stats count(*) as records by interfaceId, srcAddr, dstAddr, action
```

| interfaceId | srcAddr | dstAddr | action | |
|---|---|---|---|---|
| eni of reporting-01 | `10.11.1.x` (reporting private) | `3.x.x.x` (inventory **public**) | ACCEPT | leaves reporting-01; its egress allows everything |
| eni of inventory-api | `18.x.x.x` (reporting **public**) | `10.11.2.x` (inventory private) | **REJECT** | dropped by inventory-api's security group |

Then:

```bash
aws ssm get-parameter --name /flowlogs-lab/inventory-url --query Parameter.Value --output text
# http://3.x.x.x:8080/stock.json   <- a public IP

aws ec2 describe-instances --filters Name=tag:Lab,Values=breakfix/11-flow-logs-blocked-connection \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,PublicIpAddress]' --output table
```

The interface that records the `REJECT` is where the packet was dropped. Here that's the **destination's** inbound security group.

## Fix

**Terraform.** In `compute.tf`, publish the private address:

```hcl
value = "http://${aws_instance.inventory.private_ip}:8080/stock.json"
```

Run `terraform apply`. The report reads the parameter on every run, so the next run (within a minute) prints `OK: fetched stock ...`. The flow logs then show `ACCEPT` on both interfaces, with private addresses only.

**Console or CLI** during the incident:

```bash
aws ssm put-parameter --name /flowlogs-lab/inventory-url --overwrite \
  --value "http://<inventory private IP>:8080/stock.json"
```

Make the same change in the code.

What **not** to do: add reporting-01's public IP, or `0.0.0.0/0`, to inventory-api's security group. It works until the next stop or start changes the public IP. It exposes the API to the internet, and every request then pays for data transfer through the internet gateway.

## Detect it earlier in production

- **Alarm on rejected traffic for important ports.** A metric filter on the flow log group, for example `[version, account, eni, src, dst, srcport, dstport="8080", protocol, packets, bytes, start, end, action="REJECT", status]`, with an alarm on its count.
- **Alarm on the application's own signal.** A metric filter on `FAIL:` in the report's logs (send the journal to CloudWatch with the agent), or a custom metric from the job.
- **Saved Logs Insights queries** for "REJECT by destination port" and "traffic to our own public IPs". Internal services talking to each other over public IPs is worth knowing about for both security and cost.

## Prevent it with automation

- **Use names, not IP addresses.** Register services in a Route 53 private hosted zone or in AWS Cloud Map (`inventory.internal`), and let clients resolve them. Private names survive redeploys; public IPs don't.
- **Validate configuration in code.** Add a Terraform `precondition` (or a CI policy check) that rejects internal URLs whose host isn't a private name or an address inside the VPC CIDR. Add a post-deploy smoke test that runs the report once through SSM Run Command.
- **Remove the temptation.** Internal servers don't need public IPs when Session Manager runs through VPC endpoints. Without a public IP there is no public address to copy into a config by mistake.

## Exam takeaways

- Flow log records (default format): `version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status`. `ACCEPT`/`REJECT` comes from **security groups and network ACLs**. The interface tells you **where** the decision was made.
- Flow logs don't capture traffic to the Amazon DNS server, instance metadata, the Amazon Time Sync Service, DHCP, or Windows license activation. Destinations: CloudWatch Logs, S3, or Data Firehose.
- **Security group references match private IPs only.** Traffic to an instance's public IP from inside the VPC goes out through the internet gateway and comes back with a public source address.
- To tell routing problems from filtering problems: filtering shows `REJECT`; routing problems show `ACCEPT` with no replies, or no records at all on the destination.
