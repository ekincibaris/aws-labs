# Solution · 08 Lambda times out since it moved into the VPC

Read this only after you've written your own diagnosis in `notes/`.

## Root cause

The function is attached to the **public** subnets (`lambda-lab-public-a/b`), whose default route points to the **internet gateway**.

- An internet gateway only translates traffic for network interfaces that have a public IPv4 address (or an Elastic IP).
- Lambda's VPC network interfaces (Hyperplane ENIs) **only ever have private IPs**, and you can't give them a public one.
- The function's packets leave towards the internet gateway, which drops them because there is no public address to translate to. The TCP connection attempt to `checkip.amazonaws.com` hangs, and after 10 seconds Lambda ends the invocation: `Task timed out after 10.0 seconds`.

The NAT gateway was there all along, but only the **private** subnets route to it. "Public subnet = internet access" holds for EC2 instances with a public IP. It never holds for Lambda.

## Evidence

```bash
aws lambda get-function-configuration --function-name lambda-lab-partner-sync \
  --query 'VpcConfig.SubnetIds'

# The route table of those subnets: 0.0.0.0/0 -> igw-...
aws ec2 describe-route-tables --filters Name=association.subnet-id,Values=<subnet-id> \
  --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId]' --output table

# The function's ENIs: private IP only, no public association
aws ec2 describe-network-interfaces \
  --filters Name=description,Values='AWS Lambda VPC ENI-lambda-lab-partner-sync*' \
  --query 'NetworkInterfaces[].[SubnetId,PrivateIpAddress,Association.PublicIp]' --output table
```

In CloudWatch: `Duration` sits at ~10,000 ms (the timeout), and `Errors` equals `Invocations`. The log stream ends with `Task timed out after 10.0x seconds`, and the function never printed its `outbound traffic leaves from` line.

## Fix

**Terraform.** In `lambda.tf`, attach the function to the private subnets:

```hcl
vpc_config {
  subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids = [aws_security_group.partner_sync.id]
}
```

Run `terraform apply`. The function's state is `Pending` for a minute while Lambda creates network interfaces in the new subnets. After that, the invoke returns the NAT gateway's Elastic IP.

**Console.** Lambda → **Configuration** → **VPC** → **Edit** → select `lambda-lab-private-a` and `lambda-lab-private-b`, and remove the public subnets.

**CLI.**

```bash
aws lambda update-function-configuration --function-name lambda-lab-partner-sync \
  --vpc-config SubnetIds=<private-a>,<private-b>,SecurityGroupIds=<sg-id>
```

Other options, depending on what the function needs:

- **It doesn't need anything in the VPC:** don't attach it to a VPC at all. Lambda outside a VPC has internet access by default.
- **It only needs AWS services, not the internet:** private subnets with VPC endpoints (gateway endpoints for S3 and DynamoDB are free), with no NAT gateway.

## Detect it earlier in production

- **Alarm on duration close to the timeout.** `AWS/Lambda Duration` (p99 or Maximum) above 80 % of the configured timeout shows hanging calls even before every invocation fails.
- **Alarm on errors**, and a log metric filter on `"Task timed out"`, so timeouts are counted separately from code errors.
- **VPC Flow Logs** on the function's ENIs show outbound packets to public addresses with no responses coming back. That's typical of a routing problem, as opposed to a `REJECT` from a security group or NACL.

## Prevent it with automation

- **Select subnets by tag, not by hand.** Look up the function's subnets with a data source filtered on `Tier = private`, so a Lambda module can't be wired to public subnets.
- **Policy-as-code in CI**, or an AWS Config custom rule, that flags Lambda functions whose subnets have a default route to an internet gateway.
- **Fail fast in code.** An explicit client timeout, for example `urlopen(url, timeout=3)`, turns a silent 10-second hang into a clear error message. Combine it with a smoke-test invoke in the deployment pipeline.

## Exam takeaways

- Lambda in a VPC: ENIs with **private IPs only**. Internet access needs a **NAT gateway** (in a public subnet) with a route from the function's **private** subnets. AWS services can also be reached through **VPC endpoints**.
- The execution role needs `AWSLambdaVPCAccessExecutionRole` (or the equivalent `ec2:CreateNetworkInterface` and related permissions) to attach to a VPC.
- **Public subnet** = a route to an internet gateway. Instances in it also need a public IP or an Elastic IP to use that route.
- **Timeout** usually means packets are silently dropped (routing, security group, NACL). **Connection refused** means something answered and rejected you.
