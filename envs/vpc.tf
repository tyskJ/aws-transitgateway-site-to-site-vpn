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
# resource "aws_nat_gateway" "name" {
#   depends_on        = [aws_internet_gateway.this]
#   availability_mode = "regional"
#   connectivity_type = "public"
#   vpc_id            = aws_vpc.this["onpremises"].id
#   tags = {
#     Name = "onpremises-regional-nat"
#   }
# }

/************************************************************
RouteTable
************************************************************/
resource "aws_route_table" "this" {
  for_each = local.rtbs

  vpc_id = aws_vpc.this[each.value.vpc_key].id
  tags = {
    Name = each.value.name
  }
}

/************************************************************
RouteTable Association
************************************************************/
resource "aws_route_table_association" "this" {
  for_each = local.rtbs

  route_table_id = aws_route_table.this[each.key].id
  subnet_id      = aws_subnet.this[each.key].id
}

/************************************************************
Route
************************************************************/
resource "aws_route" "onpremises_gateway_public_a_to_igw" {
  route_table_id         = aws_route_table.this["onpremises_gateway_public_a"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route" "onpremises_gateway_public_c_to_igw" {
  route_table_id         = aws_route_table.this["onpremises_gateway_public_c"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route" "aws_client_private_a_to_tgw" {
  route_table_id         = aws_route_table.this["aws_client_private_a"].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}