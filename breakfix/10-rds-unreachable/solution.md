# Solution · 10 App can't reach its database across VPC peering

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The **return route is missing** in the data VPC.

| Direction | Route table | Route to the other VPC |
|---|---|---|
| App server → database | `rds-lab-app-rt` | `10.100.0.0/16 → pcx-…` ✅ |
| Database → app server | `rds-lab-data-rt` | none ❌ (only `local`) |

1. The app server sends a SYN to the database (`10.100.x.x:5432`). The app route table forwards it over the peering connection.
2. The database security group allows `10.10.0.0/16` on 5432, so the SYN reaches the database.
3. The database answers with a SYN-ACK to `10.10.1.x`. The data subnets' route table only knows `10.100.0.0/16 → local`, so the packet is dropped.
4. The app never gets an answer. `check-db` times out, and so does the real app.

VPC peering is just a link. It doesn't add routes for you, and it needs a route **in each VPC's route tables**, for every subnet that has to communicate. Security groups are stateful; routing isn't.

## Evidence

```bash
aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$(terraform output -raw peering_connection_id)" \
  --query 'VpcPeeringConnections[0].[Status.Code,RequesterVpcInfo.CidrBlock,AccepterVpcInfo.CidrBlock]'
# ["active", "10.10.0.0/16", "10.100.0.0/16"]

aws ec2 describe-route-tables --filters Name=tag:Lab,Values=breakfix/10-rds-unreachable \
  --query 'RouteTables[].{Table:Tags[?Key==`Name`]|[0].Value,Routes:Routes[].[DestinationCidrBlock,GatewayId||VpcPeeringConnectionId]}'
# rds-lab-app-rt:  10.10.0.0/16 local, 0.0.0.0/0 igw-..., 10.100.0.0/16 pcx-...
# rds-lab-data-rt: 10.100.0.0/16 local                <- no route back to 10.10.0.0/16
```

If you turned on VPC Flow Logs for the database's network interface, you'd see `ACCEPT` records for traffic from `10.10.1.x` to port 5432, and for the replies leaving the interface. Yet the app never receives an answer. Nothing is rejected; the replies just have no route. That's the signature of a routing problem rather than a security group or NACL problem, which would show up as `REJECT`.

## Fix

**Terraform.** Add the return route to `peering.tf`:

```hcl
resource "aws_route" "data_to_app" {
  route_table_id            = aws_route_table.data.id
  destination_cidr_block    = aws_vpc.app.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_data.id
}
```

Run `terraform apply`. The next `check-db` succeeds straight away, and so does the timer one minute later.

A Terraform pitfall worth remembering: use **either** inline `route` blocks in `aws_route_table` **or** separate `aws_route` resources for a table, never both. Inline routes are treated as the complete list, so every apply would delete the routes the separate resources created. This lab uses `aws_route` resources everywhere.

**Console.** VPC → **Route tables** → `rds-lab-data-rt` → **Routes** → **Edit routes** → **Add route**: destination `10.10.0.0/16`, target **Peering connection** → `rds-lab-app-to-data`.

**CLI.**

```bash
aws ec2 create-route --route-table-id <rds-lab-data-rt id> \
  --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id "$(terraform output -raw peering_connection_id)"
```

Add the route in the code too, or the next apply removes it.

## Detect it earlier in production

- **An application health check that counts.** The `check-db` timer is a start: push its result as a custom metric, or send its output to CloudWatch Logs with a metric filter on `FAIL`, and alarm on it.
- **Reachability Analyzer as a network test.** Save paths for the critical flows (app server → database on 5432, and the reverse, from the database's network interface or subnet back to the app server), re-run them after every network change, and alarm on a *not reachable* result. AWS Network Access Analyzer can check whole sets of paths.
- **VPC Flow Logs on database subnets** with the `tcp-flags` field: lots of SYNs from a client and no established connections is a typical sign of an asymmetric route.

## Prevent it with automation

- **Treat peering as one unit.** A Terraform module that creates the peering connection **and** the routes in both VPCs (for every route table that needs it) takes the forget-one-side mistake away.
- **Post-change connectivity tests in the pipeline:** after `terraform apply`, run the saved Reachability Analyzer paths, or an SSM Run Command on the app server that executes `check-db`, and fail the pipeline on errors.
- **For more than a couple of VPCs,** use a transit gateway with centrally managed route tables instead of a mesh of peering connections.

## Exam takeaways

- VPC peering: **routes in both VPCs**, no overlapping CIDRs, **no transitive routing** (A↔B and B↔C doesn't give you A↔C), and no edge-to-edge routing through the peer's IGW, NAT gateway or VPN.
- Security groups are stateful and can reference security groups in a **peered VPC in the same Region**. Network ACLs and route tables are stateless and need both directions.
- **Timeout** = dropped (routing, security group, NACL). **Refused** = the host answered, but nothing listens on that port.
- An RDS endpoint that isn't publicly accessible resolves to its **private** IP everywhere, which is why the app connects to `10.100.x.x` across the peering connection.
