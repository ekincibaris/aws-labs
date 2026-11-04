# Role used by the remediation runbook AWS-DisableIncomingSSHOnPort22.
resource "aws_iam_role" "remediation" {
  name        = "config-lab-remediation-role"
  description = "Lets the restricted-ssh remediation revoke world-open SSH rules"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "remediation" {
  name = "revoke-open-ssh"
  role = aws_iam_role.remediation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSecurityGroups"
        Effect   = "Allow"
        Action   = "ec2:DescribeSecurityGroups"
        Resource = "*"
      },
      {
        Sid      = "RevokeIngress"
        Effect   = "Allow"
        Action   = "ec2:RevokeSecurityGroupIngress"
        Resource = "arn:aws:ec2:eu-central-1:${data.aws_caller_identity.current.account_id}:security-group/*"
      },
    ]
  })
}
