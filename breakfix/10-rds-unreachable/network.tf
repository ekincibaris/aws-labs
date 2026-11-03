# Two VPCs: the application VPC and a shared data VPC for databases,
# connected with VPC peering (peering.tf).

# --- Application VPC ---------------------------------------------------------

resource "aws_vpc" "app" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "rds-lab-app-vpc"
  }
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "rds-lab-app-subnet"
  }
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "rds-lab-app-igw"
  }
}

# Routes are separate aws_route resources (here and in peering.tf). Never mix
# them with inline route blocks on the same table.
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "rds-lab-app-rt"
  }
}

resource "aws_route" "app_internet" {
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.app.id
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.app.id
}

# --- Data VPC ----------------------------------------------------------------

locals {
  data_subnets = {
    a = { az = "eu-central-1a", cidr = "10.100.1.0/24" }
    b = { az = "eu-central-1b", cidr = "10.100.2.0/24" }
  }
}

resource "aws_vpc" "data" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "rds-lab-data-vpc"
  }
}

resource "aws_subnet" "data" {
  for_each = local.data_subnets

  vpc_id            = aws_vpc.data.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "rds-lab-data-${each.key}"
  }
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.data.id

  tags = {
    Name = "rds-lab-data-rt"
  }
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}
