resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # IMDSv2: fetch a session token before reading instance metadata
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

    # Data-tier check: can this app server open a TCP connection to MySQL on port 3306?
    if timeout 3 bash -c "</dev/tcp/${aws_db_instance.main.address}/3306"; then
      DB_STATUS="reachable"
    else
      DB_STATUS="NOT reachable"
    fi

    echo "<html><body><h1>Multi-Tier Architecture</h1><p>Served from $(hostname) in $AZ</p><p>MySQL data tier: $DB_STATUS</p></body></html>" > /tmp/index.html
    cd /tmp && python3 -m http.server 80 &
  EOF
  )

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-app-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.app_1.id, aws_subnet.app_2.id]
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Replace instances automatically when the launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-instance"
    propagate_at_launch = true
  }
}
