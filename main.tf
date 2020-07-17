variable "region" {
  type        = string
  description = "Enter Region:"
}
variable "a_key" {
  type        = string
  description = "Enter Access Key:"
}
variable "s_key" {
  type        = string
  description = "Enter Secret Key:"
}
variable "key_name" {
  type        = string
  description = "Enter SSH Key Name:"
}

variable "db_user" {
  type        = string
  description = "Enter DB User:"
}

variable "db_name" {
  type        = string
  description = "Enter DB Name:"
}

variable "db_pass" {
  type        = string
  description = "Enter DB Password:"
}

variable "ami" {
  type        = string
  description = "Enter AMI ID:"
}

variable "bucket" {
  type        = string
  description = "Enter Bucket Name:"
}

provider "aws" {
  region = var.region
}

#Template User Data

data "template_file" "data" {
  template = "${file("install.tpl")}"

  vars = {
    endpoint = trimsuffix("${aws_db_instance.default.endpoint}",":5432")
    a_key    = var.a_key
    s_key    = var.s_key
    db_name  = var.db_name
    db_user  = var.db_user
    db_pass  = var.db_pass
    bucket   = var.bucket
  }
}

# EC2 Instance 

# resource "aws_instance" "web" {
#   ami                    = var.ami
#   instance_type          = "t2.micro"
#   subnet_id              = aws_subnet.subnet-2.id
#   iam_instance_profile   = "EC2-CSYE6225"
#   key_name               = var.key_name
#   vpc_security_group_ids = [aws_security_group.app_sg.id]
#   root_block_device {
#     volume_size = 20
#     volume_type = "gp2"
#   }
#   user_data = "${data.template_file.data.rendered}"

#   tags = {
#     Name = "Demo Instance"
#   }
# }

# Application Security Group 

resource "aws_security_group" "app_sg" {
  name        = "Demo SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.aws_demo.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "WebApp"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Application"
  }
}
# EC2 Profile 


resource "aws_iam_instance_profile" "EC2Profile" {
  name = "EC2-CSYE6225"
  role = "${aws_iam_role.EC2Role.name}"
}


# EC2 Roles Attachements 


resource "aws_iam_role_policy_attachment" "attach-policy" {
  role       = "${aws_iam_role.EC2Role.name}"
  policy_arn = "${aws_iam_policy.policy.arn}"
}
resource "aws_iam_role_policy_attachment" "cloud-watch-policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = "${aws_iam_role.EC2Role.name}"
}


# EC2 policy for S3 

resource "aws_iam_policy" "policy" {
  name   = "WebAppS3"
  policy = <<EOF
{
	"Version"  : "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Action": ["s3:PutObject",
              "s3:GetObject",
              "s3:DeleteObject"],
		"Resource": [
			"arn:aws:s3:::web-vanesa-krutarth",
			"arn:aws:s3:::web-vanesa-krutarth/*"
		]
	}]
}
  EOF

}

# EC2 policy for Code Deploy

resource "aws_iam_role" "EC2Role" {
  name = "EC2-CSYE6225"

  assume_role_policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Sid"      : "",
      "Effect"   : "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    name = "EC2-CSYE6225"
  }
}



# RDS DB Instance 

resource "aws_db_instance" "default" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "11"
  instance_class         = "db.t3.micro"
  name                   = var.db_name
  username               = var.db_user
  password               = var.db_pass
  identifier             = "csye6225-su2020"
  db_subnet_group_name   = "db_group"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

# RDS Security Group

resource "aws_security_group" "db_sg" {
  name        = "allow_db"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.aws_demo.id

  ingress {
    description     = "DB Connection"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database"
  }
}

# DB Subnet Group

resource "aws_db_subnet_group" "db_group" {
  name       = "db_group"
  subnet_ids = [aws_subnet.subnet-2.id, aws_subnet.subnet-3.id]

  tags = {
    Name = "My DB subnet group"
  }
}


# S3 Bucket

resource "aws_s3_bucket" "b" {
  bucket        = var.bucket
  force_destroy = true
  acl           = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    prefix  = "config/"
    enabled = true

    noncurrent_version_transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

  }
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


# Dynamo DB Table

resource "aws_dynamodb_table" "dbTable" {
  name           = "csye6225"
  hash_key       = "id"
  billing_mode   = "PROVISIONED"
  write_capacity = 5
  read_capacity  = 5
  attribute {
    name = "id"
    type = "S"
  }

}


#  Create a VPC

resource "random_id" "server" {
  byte_length = 8
}
resource "aws_vpc" "aws_demo" {
  cidr_block                       = "10.0.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  enable_classiclink_dns_support   = true
  assign_generated_ipv6_cidr_block = false
  tags                             = {
    Name = "aws_demo ${random_id.server.hex}"
    Tag2 = "new tag"
  }
}

# Subnets

resource "aws_subnet" "subnet" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.aws_demo.id
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-subnet-1"
  }
}

resource "aws_subnet" "subnet-2" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.aws_demo.id
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-subnet-2"
  }
}

resource "aws_subnet" "subnet-3" {
  cidr_block              = "10.0.3.0/24"
  vpc_id                  = aws_vpc.aws_demo.id
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-subnet-3"
  }
}

# Internet Gateway

resource "aws_internet_gateway" "main-gateway" {
  vpc_id = aws_vpc.aws_demo.id

  tags = {
    Name = "internet-gateway"
  }
}

# Route Table

resource "aws_route_table" "table-1" {
  vpc_id = aws_vpc.aws_demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-gateway.id
  }

  tags = {
    Name = "table-1"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.table-1.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.table-1.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.subnet-3.id
  route_table_id = aws_route_table.table-1.id
}


# Policy for Circle CI

resource "aws_iam_policy" "policy-circleci" {
  name = "EC2PolicyForCircleCI"
  path = "/"

  policy = jsonencode(
  {
	"Version"  : "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Action": [
			"ec2:AttachVolume",
			"ec2:AuthorizeSecurityGroupIngress",
			"ec2:CopyImage",
			"ec2:CreateImage",
			"ec2:CreateKeypair",
			"ec2:CreateSecurityGroup",
			"ec2:CreateSnapshot",
			"ec2:CreateTags",
			"ec2:CreateVolume",
			"ec2:DeleteKeyPair",
			"ec2:DeleteSecurityGroup",
			"ec2:DeleteSnapshot",
			"ec2:DeleteVolume",
			"ec2:DeregisterImage",
			"ec2:DescribeImageAttribute",
			"ec2:DescribeImages",
			"ec2:DescribeInstances",
			"ec2:DescribeInstanceStatus",
			"ec2:DescribeRegions",
			"ec2:DescribeSecurityGroups",
			"ec2:DescribeSnapshots",
			"ec2:DescribeSubnets",
			"ec2:DescribeTags",
			"ec2:DescribeVolumes",
			"ec2:DetachVolume",
			"ec2:GetPasswordData",
			"ec2:ModifyImageAttribute",
			"ec2:ModifyInstanceAttribute",
			"ec2:ModifySnapshotAttribute",
			"ec2:RegisterImage",
			"ec2:RunInstances",
			"ec2:StopInstances",
			"ec2:TerminateInstances"
		],
		"Resource": "*"
	}]
})

}


resource "aws_iam_user_policy_attachment" "policy-attach" {
  user       = "circle-ci"
  policy_arn = "${aws_iam_policy.policy-circleci.arn}"
}

# Codedeploy S3 Bucket


resource "aws_s3_bucket" "s3" {
  bucket        = "codedeploy-kmvanesa-me"
  force_destroy = true
  acl           = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    prefix  = "config/"
    enabled = true

    noncurrent_version_transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
  tags = {
    Name        = "Code Deploy S3"
    Environment = "Dev"
  }
}


# Code Deploy IAM Policy

resource "aws_iam_policy" "CodeDeploy-EC2-S3" {
  name   = "CodeDeploy-EC2-S3"
  policy = <<EOF
{
	"Version"  : "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Action": ["s3:PutObject",
              "s3:Get*",
              "s3:DeleteObject",
              "s3:List*"],
		"Resource": [
			"arn:aws:s3:::codedeploy-kmvanesa-me",
			"arn:aws:s3:::codedeploy-kmvanesa-me/*",
      "arn:aws:s3:::aws-codedeploy-us-east-1/*"
		]
	}]
}
  EOF

}

resource "aws_iam_role_policy_attachment" "attach-policy-ec2" {
  role       = "${aws_iam_role.EC2Role.name}"
  policy_arn = "${aws_iam_policy.CodeDeploy-EC2-S3.arn}"
}


# Codedeploy Policy for CircleCI

resource "aws_iam_policy" "policy-circleci-s3" {
  name = "CircleCI-Upload-To-S3"
  path = "/"

  policy = jsonencode(
  {
	"Version"  : "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Action": ["s3:PutObject",
              "s3:Get*",
              "s3:DeleteObject"
              ],
		"Resource": [
			"arn:aws:s3:::codedeploy-kmvanesa-me",
			"arn:aws:s3:::codedeploy-kmvanesa-me/*"
		]
	}]
}
  )

}

resource "aws_iam_user_policy_attachment" "policy-attach-s3" {
  user       = "circle-ci"
  policy_arn = "${aws_iam_policy.policy-circleci-s3.arn}"
}

# Codedeploy Policy for CircleCI

resource "aws_iam_policy" "policy-circleci-code-deploy" {
  name = "CircleCI-Code-Deploy"
  path = "/"

  policy = jsonencode(
  {
	"Version"  : "2012-10-17",
	"Statement": [{
			"Effect": "Allow",
			"Action": [
				"codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplication",
				"codedeploy:GetApplicationRevision",
        "codedeploy:GetDeploymentGroup"
			],
			"Resource": [
				"arn:aws:codedeploy:us-east-1:708581696554:application:csye6225-webapp",
        "arn:aws:codedeploy:us-east-1:708581696554:deploymentgroup:csye6225-webapp/csye6225-webapp-deployment"
			]
		},
		{
			"Effect": "Allow",
			"Action": [
				"codedeploy:CreateDeployment",
				"codedeploy:GetDeployment"
			],
			"Resource": [
				"*"
			]
		},
		{
			"Effect": "Allow",
			"Action": [
				"codedeploy:GetDeploymentConfig"
			],
			"Resource": [
				"arn:aws:codedeploy:us-east-1:708581696554:deploymentconfig:CodeDeployDefault.OneAtATime",
				"arn:aws:codedeploy:us-east-1:708581696554:deploymentconfig:CodeDeployDefault.HalfAtATime",
				"arn:aws:codedeploy:us-east-1:708581696554:deploymentconfig:CodeDeployDefault.AllAtOnce"
			]
		}
	]
})

}

resource "aws_iam_user_policy_attachment" "policy-attach-code-deploy" {
  user       = "circle-ci"
  policy_arn = "${aws_iam_policy.policy-circleci-code-deploy.arn}"
}

# Codedeployment Application

resource "aws_codedeploy_app" "csye6225-webapp" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

# Code Deployment Service Role

resource "aws_iam_role" "CodeDeployServiceRole" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Sid"      : "",
      "Effect"   : "Allow",
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
  role       = "${aws_iam_role.CodeDeployServiceRole.name}"
}

# Codedeploy Deployment group

resource "aws_codedeploy_deployment_group" "csye6225-webapp-deployment" {
  app_name              = "${aws_codedeploy_app.csye6225-webapp.name}"
  deployment_group_name = "csye6225-webapp-deployment"
  service_role_arn      = "${aws_iam_role.CodeDeployServiceRole.arn}"
  deployment_style {
    deployment_type = "IN_PLACE"
  }
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  
  autoscaling_groups = [aws_autoscaling_group.autoscale-group.id]

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "Demo Instance"
    }
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.lb-listener.arn]
      }
      target_group {
        name = aws_lb_target_group.lb-target-group.name
      }
    }
  }

}


# EC2 Launch config

resource "aws_launch_configuration" "asg_launch_config" {
  //name_prefix   = "asg_launch_config"
  image_id                    = var.ami
  instance_type               = "t2.micro"
  key_name                    = "aws_prod"
  user_data                   = "${data.template_file.data.rendered}"
  iam_instance_profile        = "EC2-CSYE6225"
  name                        = "asg_launch_config"
  security_groups             = [aws_security_group.app_sg.id]
  associate_public_ip_address = true
  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group

resource "aws_autoscaling_group" "autoscale-group" {
  # availability_zones   = ["us-east-1b","us-east-1c"]
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  default_cooldown     = 60
  launch_configuration = aws_launch_configuration.asg_launch_config.name
  vpc_zone_identifier  = [aws_subnet.subnet-2.id,aws_subnet.subnet-3.id]
  target_group_arns    = [aws_lb_target_group.lb-target-group.arn]
  tag {
    key                 = "Name"
    value               = "Demo Instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "WebServerScaleUpPolicy" {
  name                   = "WebServerScaleUpPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscale-group.name}"
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "90"
  
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscale-group.name}"
  }

  alarm_description = "Scale-up if CPU > 90% for 60 seconds"
  alarm_actions     = ["${aws_autoscaling_policy.WebServerScaleUpPolicy.arn}"]
}

resource "aws_autoscaling_policy" "WebServerScaleDownPolicy" {
  name                   = "WebServerScaleDownPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.autoscale-group.name}"
}


resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscale-group.name}"
  }

  alarm_description = "Scale-up if CPU < 3% for 60 seconds"
  alarm_actions     = ["${aws_autoscaling_policy.WebServerScaleDownPolicy.arn}"]
}




resource "aws_lb" "lb-webapp" {
  name               = "lb-webapp"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.subnet-2.id,aws_subnet.subnet-3.id,aws_subnet.subnet.id]

  enable_deletion_protection = false

  tags = {
    name = "lb-webapp"
  }
}

resource "aws_lb_target_group" "lb-target-group" {
  name     = "lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.aws_demo.id

  stickiness {
    type = "lb_cookie"
    enabled = true
  }
}

resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = "${aws_lb.lb-webapp.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.lb-target-group.arn}"
  }
}





resource "aws_route53_record" "www" {
  zone_id = "Z01839792VYJ6O593DYLZ"
  name    = ""
  type    = "A"

  alias {
    name                   = aws_lb.lb-webapp.dns_name
    zone_id                = aws_lb.lb-webapp.zone_id
    evaluate_target_health = true
  }
}