locals {
  ecs_tasks_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "execution" {
  name               = "ecs-lab-orders-api-execution"
  description        = "Used by ECS to start orders-api tasks"
  assume_role_policy = local.ecs_tasks_trust_policy
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "ecs-lab-orders-api-task"
  description        = "Used by the orders-api application"
  assume_role_policy = local.ecs_tasks_trust_policy
}

resource "aws_iam_role_policy" "read_db_password" {
  name = "read-db-password"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadDbPassword"
      Effect   = "Allow"
      Action   = "ssm:GetParameters"
      Resource = aws_ssm_parameter.db_password.arn
    }]
  })
}
