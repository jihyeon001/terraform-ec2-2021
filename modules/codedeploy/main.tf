# codedeploy application 
resource "aws_codedeploy_app" "app" {
  name = "${var.name}-${var.environment}"
}

# iam role
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.name}-codedeploy-role-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_role.name
}

# codedeploy group
resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name              = "${var.name}-${var.environment}"
  deployment_group_name = "deploy-group-${var.environment}"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  #autoscaling_groups    = var.autoscaling_groups

  auto_rollback_configuration {
    enabled = var.rollback_enabled
    events  = var.rollback_events
  }

  deployment_style {
    deployment_option = var.alb_target_group == null ? "WITHOUT_TRAFFIC_CONTROL" : "WITH_TRAFFIC_CONTROL"
    deployment_type   = var.enable_bluegreen == false ? "IN_PLACE" : "BLUE_GREEN"
  }

  dynamic "blue_green_deployment_config" {
    for_each = var.enable_bluegreen == true ? [1] : []
    content {
      deployment_ready_option {
        action_on_timeout = var.bluegreen_timeout_action
      }

      terminate_blue_instances_on_deployment_success {
        action = var.blue_termination_behavior
      }
      green_fleet_provisioning_option {
        action = var.green_provisioning
      }
    }
  }

  dynamic "load_balancer_info" {
    for_each = var.alb_target_group == null ? [] : [var.alb_target_group]
    content {
      target_group_info {
        name = var.alb_target_group
      }
    }
  }

  dynamic "trigger_configuration" {
    for_each = var.trigger_target_arn == null ? [] : [var.trigger_target_arn]
    content {
      trigger_events     = var.trigger_events
      trigger_name       = "${var.app_name}-${var.environment}"
      trigger_target_arn = var.trigger_target_arn
    }
  }

  dynamic "ec2_tag_filter" {
    for_each = var.ec2_tag_filter == null ? {} : var.ec2_tag_filter
    content {
      key   = ec2_tag_filter.key
      type  = "KEY_AND_VALUE"
      value = ec2_tag_filter.value
    }
  }

}
