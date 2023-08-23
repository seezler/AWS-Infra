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

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/28"
  map_public_ip_on_launch = true

  tags = {
    Name = "public1"
  }
}

resource "aws_route_table" "public1-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public1-rt"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public1-rt.id
}

resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.16/28"
  map_public_ip_on_launch = false

  tags = {
    Name = "private1"
  }
}

resource "aws_eip" "lb" {
  
  domain      = "vpc"
}

resource "aws_nat_gateway" "nat1" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "nat"
  }
   depends_on = [aws_internet_gateway.gw]
}


resource "aws_route_table" "private1-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat1.id
  }
  tags = {
    Name = "private1-rt"
  }
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1-rt.id
}

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.32/28"
  map_public_ip_on_launch = true

  tags = {
    Name = "public2"
  }
}

resource "aws_route_table" "public2-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public2-rt"
  }
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public2-rt.id
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
    cidr_blocks = ["2.217.109.100/32"]
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
# Define an AWS EC2 instance resource named "public"
resource "aws_instance" "public-instance1" {
  ami           = "ami-0a47852af5dfa6b0f" # Specify the ID of the Amazon Machine Image (AMI) you want to use
  instance_type = "t2.micro"             # Specify the instance type (e.g., t2.micro, t2.small)
  subnet_id     = "aws_subnet_public1"
  # Specify the key pair for SSH access
  key_name      = "boslearning"          # Replace with the name of your SSH key pair

  # Define tags for the instance (optional but recommended)
  tags = {
    Name = "public-instance1"
  }
}



