locals {
  public_subnets = {
    a = { az = "eu-central-1a", cidr = "10.8.1.0/24" }
    b = { az = "eu-central-1b", cidr = "10.8.2.0/24" }
  }

  private_subnets = {
    a = { az = "eu-central-1a", cidr = "10.8.11.0/24" }
    b = { az = "eu-central-1b", cidr = "10.8.12.0/24" }
  }
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.8.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "lambda-lab-vpc"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "lambda-lab-public-${each.key}"
    Tier = "public"
  }

  # Lambda releases its VPC network interfaces asynchronously after a change or destroy.
  timeouts {
    delete = "45m"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "lambda-lab-private-${each.key}"
    Tier = "private"
  }

  timeouts {
    delete = "45m"
  }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "lambda-lab-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "lambda-lab-nat-eip"
  }
}

# One NAT gateway for both private subnets keeps the lab cheap.
resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id

  tags = {
    Name = "lambda-lab-nat"
  }

  depends_on = [aws_internet_gateway.lab]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "lambda-lab-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab.id
  }

  tags = {
    Name = "lambda-lab-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
