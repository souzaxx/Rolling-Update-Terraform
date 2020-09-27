resource "aws_launch_template" "this" {
  name_prefix   = var.name
  image_id      = data.aws_ami.selected.id
  instance_type = var.instance_type
  network_interfaces {
    security_groups             = [module.instance_sg.this_security_group_id]
    delete_on_termination       = true
    associate_public_ip_address = true
  }

  user_data = base64encode(templatefile("userData.sh", { CFN_STACK = var.name, REGION = "us-east-2" }))
}

resource "aws_cloudformation_stack" "this" {
  name = var.name

  template_body = <<EOF
Resources:
  ASG:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: "${var.name}"
      HealthCheckGracePeriod: 300
      DesiredCapacity: 2
      MaxSize: 2
      MinSize: 1
      VPCZoneIdentifier: ["${join("\",\"", data.aws_subnet_ids.all.ids)}"]
      TargetGroupARNs: ${jsonencode([for tg_arn in module.alb.target_group_arns : tg_arn])}
      Tags: ${jsonencode([for key, value in var.tags : map("Key", key, "PropagateAtLaunch", "true", "Value", value)])}
      HealthCheckType: EC2

      MixedInstancesPolicy:
        InstancesDistribution:
          OnDemandBaseCapacity: 0
          OnDemandPercentageAboveBaseCapacity: 0
          SpotAllocationStrategy: capacity-optimized
        LaunchTemplate:
          LaunchTemplateSpecification:
            LaunchTemplateName: "${aws_launch_template.this.name}"
            Version: "${aws_launch_template.this.latest_version}"
          Overrides: ${jsonencode([for type in var.instance_type_override : map("InstanceType", type)])}

    UpdatePolicy:
    # Ignore differences in group size properties caused by scheduled actions
      AutoScalingScheduledAction:
        IgnoreUnmodifiedGroupSizeProperties: true
      AutoScalingRollingUpdate:
        MinSuccessfulInstancesPercent: 50
        PauseTime: PT10M
        SuspendProcesses:
          - HealthCheck
          - ReplaceUnhealthy
          - AZRebalance
          - AlarmNotification
          - ScheduledActions
        WaitOnResourceSignals: true

    DeletionPolicy: Delete
EOF

  depends_on = [
    module.alb
  ]
}

module "loadbalancer_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "${var.name}_lb_sg"
  description = "Security group for example usage with ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]
  computed_egress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.instance_sg.this_security_group_id
    },
  ]

  number_of_computed_egress_with_source_security_group_id = 1
}

module "instance_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "${var.name}_instances_sg"
  description = "Security group for example usage with EC2 Instances"
  vpc_id      = data.aws_vpc.default.id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.loadbalancer_sg.this_security_group_id
    },
  ]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["https-443-tcp"]

  number_of_computed_ingress_with_source_security_group_id = 1

}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "5.9.0"

  name = var.name

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.default.id
  security_groups = [module.loadbalancer_sg.this_security_group_id]
  subnets         = data.aws_subnet_ids.all.ids

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name_prefix          = "h1"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    },
  ]
}
