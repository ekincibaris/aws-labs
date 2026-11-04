locals {
  subnets = {
    reporting = { az = "eu-central-1a", cidr = "10.11.1.0/24" }
    inventory = { az = "eu-central-1b", cidr = "10.11.2.0/24" }
  }
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.11.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "flowlogs-lab-vpc"
  }
}

resource "aws_subnet" "lab" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "flowlogs-lab-${each.key}"
  }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "flowlogs-lab-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "flowlogs-lab-public-rt"
  }
}

resource "aws_route_table_association" "lab" {
  for_each = aws_subnet.lab

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
