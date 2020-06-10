provider "aws" {
  region = "us-east-1"
}

# variable "vpc_count" {
#     type        = number
#     description = "Enter number of VPC"
#   }

# variable "name" {
#   type = string
#    description = "Enter name of VPC"
# }


resource "random_id" "server" {
  byte_length = 8
}

# # Create a VPC
resource "aws_vpc" "aws_demo" {
  # count                            = var.vpc_count
  # Name                             = var.name
  cidr_block                       = "10.0.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  enable_classiclink_dns_support   = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = "aws_demo ${random_id.server.hex}"
    Tag2 = "new tag"
  }
}

resource "aws_subnet" "subnet" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = "${aws_vpc.aws_demo.id}"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-subnet-1"
  }
}
resource "aws_subnet" "subnet-2" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = "${aws_vpc.aws_demo.id}"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-subnet-2"
  }
}

resource "aws_subnet" "subnet-3" {
  cidr_block              = "10.0.3.0/24"
  vpc_id                  = "${aws_vpc.aws_demo.id}"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-subnet-3"
  }
}



resource "aws_internet_gateway" "main-gateway" {
  vpc_id = "${aws_vpc.aws_demo.id}"

  tags = {
    Name = "internet-gateway"
  }
}


resource "aws_route_table" "table-1" {
  vpc_id = "${aws_vpc.aws_demo.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main-gateway.id}"
  }

  tags = {
    Name = "table-1"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.subnet.id}"
  route_table_id = "${aws_route_table.table-1.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.subnet-2.id}"
  route_table_id = "${aws_route_table.table-1.id}"
}

resource "aws_route_table_association" "c" {
  subnet_id      = "${aws_subnet.subnet-3.id}"
  route_table_id = "${aws_route_table.table-1.id}"
}


