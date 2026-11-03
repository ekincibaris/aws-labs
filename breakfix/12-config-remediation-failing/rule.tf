resource "aws_config_config_rule" "restricted_ssh" {
  name        = "config-lab-restricted-ssh"
  description = "Security groups must not allow SSH (TCP 22) from 0.0.0.0/0."

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  scope {
    compliance_resource_types = ["AWS::EC2::SecurityGroup"]
  }

  depends_on = [aws_config_configuration_recorder_status.lab]
}

# Revoke world-open SSH automatically, a few minutes after Config flags it.
resource "aws_config_remediation_configuration" "restricted_ssh" {
  config_rule_name = aws_config_config_rule.restricted_ssh.name
  resource_type    = "AWS::EC2::SecurityGroup"
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-DisableIncomingSSHOnPort22"

  automatic                  = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation.arn
  }

  parameter {
    name           = "SecurityGroupIds"
    resource_value = "RESOURCE_ID"
  }
}
