resource "aws_vpc" "hub" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "hub-vpc" }
}

resource "aws_vpc" "app" {
  cidr_block = "10.1.0.0/16"
  tags = { Name = "app-vpc" }
}

# IGW (Hub VPC)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.hub.id
}

# Public subnet (Hub)
resource "aws_subnet" "hub_public" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = { Name = "hub-public-subnet" }
}

# NAT Gateway용 EIP
resource "aws_eip" "nat_eip" {
  vpc = true
}

# NAT Gateway (App VPC)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.hub_public.id
}

# Private Subnet (App)
resource "aws_subnet" "app_private" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-northeast-2a"
  tags = { Name = "app-private-subnet" }
}

# DB Subnet (App)
resource "aws_subnet" "app_db" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-northeast-2a"
  tags = { Name = "app-db-subnet" }
}
