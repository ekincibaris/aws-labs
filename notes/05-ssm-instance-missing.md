When I deployed the infrastructure, I ran `aws ssm describe-instance-information` and it returned an empty list, so the agent had never registered with SSM.
Then I checked the VPC endpoints' configuration and subnets: everything looked fine with one exception, `PrivateDnsEnabled: False`.
To reach the endpoint, we need private DNS enabled. Otherwise `ssm.eu-central-1.amazonaws.com` resolves to public AWS IPs, and the agent tries to go through the public internet, which our VPC has no route to.
So I set `private_dns_enabled = true` in `endpoints.tf` and ran `terraform apply`. After that, `describe-instance-information` showed `PingStatus: Online`, and `getent hosts ssm.eu-central-1.amazonaws.com` on the instance returned the endpoint's private IP (10.5.1.187).
To prevent this, …
