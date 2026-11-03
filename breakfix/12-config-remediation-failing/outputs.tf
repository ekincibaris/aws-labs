output "security_group_id" {
  description = "ID of the bastion security group that Config flags"
  value       = aws_security_group.bastion.id
}

output "config_rule_name" {
  description = "Name of the AWS Config rule"
  value       = aws_config_config_rule.restricted_ssh.name
}

output "remediation_role_name" {
  description = "IAM role that the remediation runbook is told to use"
  value       = aws_iam_role.remediation.name
}
