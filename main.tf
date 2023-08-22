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
        Name = "main"
    }

}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/28"
  map_public_ip_on_launch = true

  tags = {
    Name = "Main"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.16/28"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet2"
  }
}