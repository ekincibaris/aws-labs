# 01 · EC2 from the CLI: launch, SSH, clean up

Launch one EC2 instance with the AWS CLI only, log in over SSH, look around, then delete everything and prove nothing is left running.

| | |
|---|---|
| **Region** | eu-central-1 |
| **Cost** | ≈ €0.02 for the session (t3.micro + public IPv4) |
| **Time** | ~45 minutes |

## What gets created

- Key pair `lab1-key` (ed25519). The private key lives in `~/.ssh/`, never in this repo.
- Security group `lab1-ssh`: inbound TCP 22 from my IP only (`/32`).
- Instance `lab1-ec2-cli`: t3.micro, Amazon Linux 2023, default VPC, tagged `Project=aws-labs`.

## Steps

```bash
# Pre-flight: who am I, is there a budget alert?
aws sts get-caller-identity
aws budgets describe-notifications-for-budget --account-id <ID> --budget-name "<name>"

# The default VPC was missing in eu-central-1, so recreate it (free)
aws ec2 create-default-vpc

# Key pair
aws ec2 create-key-pair --key-name lab1-key --key-type ed25519 \
  --query KeyMaterial --output text > ~/.ssh/lab1-key.pem
chmod 400 ~/.ssh/lab1-key.pem

# Security group: SSH from my IP only
aws ec2 create-security-group --group-name lab1-ssh --description "..." --vpc-id "$VPC_ID"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP/32"

# Launch, wait, connect
aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro --key-name lab1-key --security-group-ids "$SG_ID" \
  --credit-specification CpuCredits=standard
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
ssh -i ~/.ssh/lab1-key.pem ec2-user@"$PUBLIC_IP"
```

## Cleanup and leak sweep

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
aws ec2 delete-security-group --group-id "$SG_ID"
aws ec2 delete-key-pair --key-name lab1-key
rm -f ~/.ssh/lab1-key.pem

# Every one of these must come back empty
aws ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId'
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'
aws ec2 describe-addresses
```

## Findings

- The default VPC in eu-central-1 was missing. An unknown VPC `192.0.0.0/16` exists: that range is not RFC 1918 private space. It has no network interfaces, so it costs nothing. To do: find out who created it (CloudTrail).
- The server only knows its private IP (`hostname -I`). The public IP exists only at the internet gateway, which translates it one-to-one.
- t3.micro: 913 MiB RAM, no swap. EC2 doesn't report memory to CloudWatch without the CloudWatch agent.

## In my own words

- What makes a subnet public: TODO
- Why the server doesn't know its public IP: TODO
- Timeout vs connection refused vs permission denied: TODO
