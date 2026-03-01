/************************************************************
VPC
************************************************************/
resource "aws_vpc" "this" {
  for_each = local.vpcs

  cidr_block           = each.value.cidr
  enable_dns_hostnames = each.value.dns_hostnames
  enable_dns_support   = each.value.dns_support
  tags = {
    Name = each.value.name
  }
}

/************************************************************
Subnet
************************************************************/
resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this[each.value.vpc_key].id
  availability_zone       = "${local.region_name}${each.value.az}"
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.value.map_public
  tags = {
    Name = each.value.name
  }
}

/************************************************************
Internet Gateway
************************************************************/
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this["onpremises"].id
  tags = {
    Name = "onpremises-igw"
  }
}

/************************************************************
NAT Gateway - Regional
************************************************************/
resource "aws_nat_gateway" "name" {
  depends_on        = [aws_internet_gateway.this]
  availability_mode = "regional"
  connectivity_type = "public"
  vpc_id            = aws_vpc.this["onpremises"].id
  tags = {
    Name = "onpremises-regional-nat"
  }
}