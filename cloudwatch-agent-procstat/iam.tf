resource "aws_iam_role" "ec2_agent" {
  name               = "lab-cwagent-ec2-role"
  assume_role_policy = file("${path.module}/trust-policy.json")
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_agent" {
  name = "lab-cwagent-instance-profile"
  role = aws_iam_role.ec2_agent.name
}