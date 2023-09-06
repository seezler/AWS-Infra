resource "aws_vpc" "main"{
    cidr_block = "192.168.0.0/24"
    instance_tenancy = "default"

    tags = {
        Name = "main"
    }
}

resource "aws_internet_gateway" "gw"{
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "gw"
    }

}

resource "aws_subnet" "public-subnets" {
  count = 2
  vpc_id     = aws_vpc.main.id
  availability_zone = element(var.public-az, count.index)
  cidr_block = element(var.public_subnet_cidr, count.index)
  map_public_ip_on_launch = true


  tags = {
    Name = element(var.public_subnet_names, count.index)
  }
}

resource "aws_route_table" "public-rt" {
  count = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = element(var.route-table_names, count.index)
  }
}

resource "aws_route_table_association" "public" {
  count = 2
  subnet_id      = element(aws_subnet.public-subnets.*.id, count.index)
  route_table_id = element(aws_route_table.public-rt.*.id, count.index)
}

resource "aws_subnet" "private-subnets" {
  count = 2
  vpc_id     = aws_vpc.main.id
  availability_zone = element(var.private-az, count.index)
  cidr_block = element(var.private_subnet_cidr, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = element(var.private_subnet_names, count.index)
  }
}

resource "aws_eip" "lb" {
  count = 2
  
  domain      = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count = 2
  allocation_id = element(aws_eip.lb.*.id, count.index)
  subnet_id     = element(aws_subnet.public-subnets.*.id, count.index)
  tags = {
    Name = element(var.private_nats, count.index)
  }
   depends_on = [aws_internet_gateway.gw]
}


resource "aws_route_table" "private-rt" {
  count =2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat.*.id,count.index)
  }
  tags = {
    Name = element(var.private-route-table_names, count.index)
  }
}

resource "aws_route_table_association" "private" {
  count = 2
  
  subnet_id      = element(aws_subnet.private-subnets.*.id, count.index)
  route_table_id = element(aws_route_table.private-rt.*.id, count.index)
}

resource "aws_security_group" "sg1" {
  name        = "sg1"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "non tls traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "tls traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "admin traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["80.193.62.172/32"]
  }
 
egress {
  description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
} 

tags = {
  Name = "my-security-group"
}
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "main-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg1.id]
  subnets            = [for subnet in aws_subnet.public-subnets : subnet.id]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

# Setting target groups
resource "aws_lb_target_group" "main" {
  name     = "tf-main-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# # Target group attachment to an instance
# resource "aws_lb_target_group_attachment" "main" {
#   count = 2
#   target_group_arn = aws_lb_target_group.main.arn
#   target_id        = element(aws_instance.public-instances.*.id, count.index)
#   port             = 80
# }


resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.cert.arn
  
  default_action {
    type            = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
# Launch Template
resource "aws_launch_template" "Azeeztemplate" {
  name = "Azeeztemplate"
  image_id = "ami-028eb925545f314d6"
  instance_initiated_shutdown_behavior = "terminate"
  instance_market_options {
    market_type = "spot"
  }
  user_data = filebase64("install.sh")
  instance_type = "t2.micro"
  monitoring {
    enabled = true
  }
  vpc_security_group_ids = [aws_security_group.sg1.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "public-instances"
    }
  }

  #user_data = filebase64("${path.module}/install.sh")
}
# Auto Scaling group
resource "aws_autoscaling_group" "ASG1" {

  vpc_zone_identifier = aws_subnet.public-subnets.*.id
  desired_capacity   = 2
  max_size           = 2
  min_size           = 1

  launch_template {
    id      = aws_launch_template.Azeeztemplate.id
    version = "$Latest"
  }
}