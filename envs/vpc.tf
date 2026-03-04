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
  for_each = local.associations

  route_table_id = aws_route_table.this[each.value.rtb_key].id
  subnet_id      = aws_subnet.this[each.key].id
}

/************************************************************
Route
************************************************************/
resource "aws_route" "onpremises_gateway_public_to_igw" {
  route_table_id         = aws_route_table.this["onpremises_gateway_public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route" "aws_client_private_to_tgw" {
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]

  route_table_id         = aws_route_table.this["aws_client_private"].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
}

/************************************************************
Security Group
************************************************************/
resource "aws_security_group" "this" {
  for_each = local.sgs

  vpc_id      = aws_vpc.this[each.value.vpc_key].id
  name        = each.value.name
  description = each.value.description
  tags = {
    Name = each.value.name
  }
}

/************************************************************
Security Group Rule
************************************************************/
resource "aws_security_group_rule" "aws_cloudshell_ingress_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.vpcs.onpremises.cidr]
  security_group_id = aws_security_group.this["aws_cloudshell"].id
  description       = "From Onpremises Clinet Traffic"
}
resource "aws_security_group_rule" "aws_cloudshell_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this["aws_cloudshell"].id
  description       = "To Unrestricted Traffic"
}
resource "aws_security_group_rule" "onpremises_gateway_ec2_gip_ingress_ike" {
  type              = "ingress"
  from_port         = 500
  to_port           = 500
  protocol          = "17"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this["onpremises_gateway_ec2_gip"].id
  description       = "From TGW IKE Traffic"
}
resource "aws_security_group_rule" "onpremises_gateway_ec2_gip_ingress_nattraversal" {
  type              = "ingress"
  from_port         = 4500
  to_port           = 4500
  protocol          = "17"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this["onpremises_gateway_ec2_gip"].id
  description       = "From TGW NAT Traversal Traffic"
}
resource "aws_security_group_rule" "onpremises_gateway_ec2_gip_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this["onpremises_gateway_ec2_gip"].id
  description       = "To Unrestricted Traffic"
}
resource "aws_security_group_rule" "onpremises_gateway_ec2_pip_ingress_private" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.vpcs.onpremises.cidr]
  security_group_id = aws_security_group.this["onpremises_gateway_ec2_pip"].id
  description       = "From Onpremises Private NW Traffic"
}
resource "aws_security_group_rule" "onpremises_cloudshell_ingress_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.vpcs.aws.cidr]
  security_group_id = aws_security_group.this["onpremises_cloudshell"].id
  description       = "From AWS Client Traffic"
}
resource "aws_security_group_rule" "onpremises_cloudshell_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this["onpremises_cloudshell"].id
  description       = "To Unrestricted Traffic"
}