# Security Groups vs NACLs

## The core difference
SGs are attached to ENIs. They are stateful and have only allow rules. If a packet is allowed inbound, the replies to that same connection are automatically allowed back out. NACLs sit on subnets and have allow and deny rules, evaluated in number order (lowest first, first match wins).

## Why ephemeral ports matter
The client's OS picks a random source port from the range 1024–65535, and the reply comes back to that port. A NACL is stateless: it doesn't remember that it allowed the request in, so it needs an explicit outbound rule for the reply.

## How it showed up: ALB health checks
The instance SG must allow inbound on the health-check port from the ALB SG. The private subnet NACL must allow inbound on the health-check port and outbound on 1024–65535.

## Troubleshooting rule
A timeout means the packets were dropped and no reply came back. Check SGs, NACLs and host firewalls.
