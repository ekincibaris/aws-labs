resource "aws_ssm_parameter" "db_password" {
  name        = "/ecs-lab/orders-api/db-password"
  description = "Database password for orders-api (lab value, not a real secret)"
  type        = "SecureString"
  value       = "lab-only-not-a-real-secret"
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/ecs-lab-orders-api"
  retention_in_days = 1
}

resource "aws_ecs_cluster" "lab" {
  name = "ecs-lab-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "ecs-lab-orders-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name      = "orders-api"
    image     = "public.ecr.aws/docker/library/nginx:stable-alpine"
    essential = true

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = aws_ssm_parameter.db_password.arn
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = "eu-central-1"
        awslogs-stream-prefix = "orders-api"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name             = "ecs-lab-orders-api"
  cluster          = aws_ecs_cluster.lab.id
  task_definition  = aws_ecs_task_definition.api.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution_managed,
    aws_iam_role_policy.read_db_password,
  ]
}
