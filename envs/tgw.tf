/************************************************************
Transit Gateway
************************************************************/
resource "aws_ec2_transit_gateway" "this" {
  description                        = null
  amazon_side_asn                    = 64512
  dns_support                        = "enable"
  security_group_referencing_support = "enable"
  vpn_ecmp_support                   = "enable"
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  multicast_support                  = "disable"
  auto_accept_shared_attachments     = "disable"
  encryption_support                 = "disable"
  transit_gateway_cidr_blocks        = []
  tags = {
    Name = "tgw"
  }
}

/************************************************************
Transit Gateway Attachment - VPC
************************************************************/
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.this["aws"].id
  subnet_ids = [
    aws_subnet.this["aws_tgw_private_a"].id
  ]
  dns_support                                     = "enable"
  security_group_referencing_support              = "enable"
  ipv6_support                                    = "disable"
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "tgw-attachment-vpc-a"
  }
}

/************************************************************
Transit Gateway RouteTable
************************************************************/
resource "aws_ec2_transit_gateway_route_table" "vpc" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags = {
    Name = "tgw-rtb-for-vpc"
  }
}
resource "aws_ec2_transit_gateway_route_table" "vpn" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags = {
    Name = "tgw-rtb-for-vpn"
  }
}

/************************************************************
Transit Gateway RouteTable Association
************************************************************/
resource "aws_ec2_transit_gateway_route_table_association" "vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc.id
}
resource "aws_ec2_transit_gateway_route_table_association" "vpn_connection" {
  for_each = local.vpncons

  transit_gateway_attachment_id  = aws_vpn_connection.this[each.key].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn.id
}