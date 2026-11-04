data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# Instances launched by the Auto Scaling group don't inherit the provider's
# default_tags, so they are passed on explicitly.
data "aws_default_tags" "current" {}

resource "aws_launch_template" "worker" {
  name_prefix   = "asg-lab-worker-"
  image_id      = data.aws_ssm_parameter.al2023.insecure_value
  instance_type = "t4g.micro"
  user_data     = filebase64("${path.module}/user-data.sh")

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.worker.id]
  }

  metadata_options {
    http_tokens = "required"
  }

  # One-minute EC2 metrics, so target tracking reacts within a few minutes.
  monitoring {
    enabled = true
  }

  # Keeps the CPU unthrottled under sustained load. See the cost note in README.md.
  credit_specification {
    cpu_credits = "unlimited"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(data.aws_default_tags.current.tags, { Name = "asg-lab-worker" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(data.aws_default_tags.current.tags, { Name = "asg-lab-worker" })
  }
}

resource "aws_autoscaling_group" "workers" {
  name                      = "asg-lab-workers"
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  vpc_zone_identifier       = [for subnet in aws_subnet.public : subnet.id]
  health_check_type         = "EC2"
  health_check_grace_period = 60
  default_instance_warmup   = 60

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
  ]

  suspended_processes = ["AlarmNotification"]

  launch_template {
    id      = aws_launch_template.worker.id
    version = aws_launch_template.worker.latest_version
  }

  dynamic "tag" {
    for_each = data.aws_default_tags.current.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  lifecycle {
    # The scaling policy owns the desired capacity once the group is running.
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "asg-lab-cpu-target-40"
  autoscaling_group_name = aws_autoscaling_group.workers.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 40
  }
}
