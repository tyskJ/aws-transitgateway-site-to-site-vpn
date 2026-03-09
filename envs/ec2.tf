/************************************************************
KeyPair
************************************************************/
resource "tls_private_key" "ssh_keygen" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "keypair_pem" {
  filename        = "${path.module}/.key/keypair.pem"
  content         = tls_private_key.ssh_keygen.private_key_pem
  file_permission = "0600"
}

resource "aws_key_pair" "keypair" {
  key_name   = "common-keypair"
  public_key = tls_private_key.ssh_keygen.public_key_openssh
  tags = {
    Name = "common-keypair"
  }
}

/************************************************************
Instance Profile
************************************************************/
resource "aws_iam_instance_profile" "this" {
  for_each = local.instanceprofiles

  name = each.value.name
  role = aws_iam_role.ec2_role.name
}

/************************************************************
Elastice Network Interface
************************************************************/
resource "aws_network_interface" "this" {
  for_each = local.enis

  subnet_id   = aws_subnet.this[each.value.subnet_key].id
  description = each.value.description
  security_groups = [
    aws_security_group.this[each.value.sg_key].id
  ]
  source_dest_check = each.value.srcdst
  tags = {
    Name = each.value.name
  }
}

/************************************************************
Elastice IP
************************************************************/
resource "aws_eip" "this" {
  for_each   = local.eips
  depends_on = [aws_internet_gateway.this]

  domain = each.value.domain
  tags = {
    Name = each.value.name
  }
}

/************************************************************
EC2 - Gateway
************************************************************/
resource "aws_instance" "gateway_a" {
  ami           = data.aws_ami_ids.ubuntu.ids[0]
  key_name      = aws_key_pair.keypair.id
  instance_type = "c6i.large"
  subnet_id     = aws_subnet.this["${local.instances.onpremises_gateway_ec2_a.subnet_key}"].id
  vpc_security_group_ids = [
    aws_security_group.this["${local.instances.onpremises_gateway_ec2_a.sg_key}"].id
  ]
  ebs_optimized = true
  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
    tags = {
      Name = "${local.instances.onpremises_gateway_ec2_a.name}-root-volume"
    }
  }
  metadata_options {
    http_tokens = "required"
  }
  maintenance_options {
    auto_recovery = "default"
  }
  disable_api_stop        = false
  disable_api_termination = false
  force_destroy           = true
  iam_instance_profile    = aws_iam_instance_profile.this["${local.instances.onpremises_gateway_ec2_a.instanceprofile_key}"].name
  source_dest_check       = false
  user_data_base64 = base64gzip(
    templatefile("${path.module}/config/setup.sh", {
      nw_conf = file("${path.module}/config/99-vpn.conf")
      xfrm_conf = templatefile("${path.module}/config/xfrm-ifaces.service", {
        cgwside_tunnel1_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel1_cgw_inside_address
        cgwside_tunnel2_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel2_cgw_inside_address
      })
      cgw_gip             = aws_eip.this["onpremises_gateway_ec2_a"].public_ip
      awsside_tunnel1_gip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel1_address
      awsside_tunnel2_gip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel2_address
      tunnel1_psk         = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel1_preshared_key
      tunnel2_psk         = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel2_preshared_key
      charon_conf         = file("${path.module}/config/add-charon.conf")
      ens6_conf = templatefile("${path.module}/config/20-ens6.network", {
        onpremises_client_private_a_subnet_cidr           = local.subnets.onpremises_client_private_a.cidr
        onpremises_gateway_private_subnet_vpc_router_ip = cidrhost(local.subnets.onpremises_gateway_public_a.cidr, 1)
        aws_vpc_cidr                                      = local.vpcs.aws.cidr
      })
      rtbrule_conf = templatefile("${path.module}/config/tgw-ecmp.service", {
        aws_vpc_cidr = local.vpcs.aws.cidr
      })
      frr_conf = templatefile("${path.module}/config/frr_onpremises_gateway_ec2_a.conf", {
        cgw_asn                  = 65000
        cgw_gip                  = aws_eip.this["onpremises_gateway_ec2_a"].public_ip
        cgwside_tunnel1_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel1_cgw_inside_address
        cgwside_tunnel2_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel2_cgw_inside_address
        aws_tgw_asn              = 64512
        awsside_tunnel1_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel1_vgw_inside_address
        awsside_tunnel2_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_a"].tunnel2_vgw_inside_address
        onpremises_nw_cidr       = local.vpcs.onpremises.cidr
      })
      snat_conf = templatefile("${path.module}/config/snat_sources.conf", {
        aws_client_private_a_subnet_cidr        = local.subnets.aws_client_private_a.cidr
        onpremises_client_private_a_subnet_cidr = local.subnets.onpremises_client_private_a.cidr
      })
      ipset_conf = file("${path.module}/config/nat-ens5-ipset.service")
    })
  )
  tags = {
    Name = local.instances.onpremises_gateway_ec2_a.name
  }
  # userdataを変更すると再起動が走るため抑止
  # 代わりに、user_data_replace_on_change は効かなくなる
  lifecycle {
    ignore_changes = [
      user_data_base64
    ]
  }
}

resource "aws_instance" "gateway_c" {
  ami           = data.aws_ami_ids.ubuntu.ids[0]
  key_name      = aws_key_pair.keypair.id
  instance_type = "c6i.large"
  subnet_id     = aws_subnet.this["${local.instances.onpremises_gateway_ec2_c.subnet_key}"].id
  vpc_security_group_ids = [
    aws_security_group.this["${local.instances.onpremises_gateway_ec2_c.sg_key}"].id
  ]
  ebs_optimized = true
  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
    tags = {
      Name = "${local.instances.onpremises_gateway_ec2_c.name}-root-volume"
    }
  }
  metadata_options {
    http_tokens = "required"
  }
  maintenance_options {
    auto_recovery = "default"
  }
  disable_api_stop        = false
  disable_api_termination = false
  force_destroy           = true
  iam_instance_profile    = aws_iam_instance_profile.this["${local.instances.onpremises_gateway_ec2_c.instanceprofile_key}"].name
  source_dest_check       = false
  user_data_base64 = base64gzip(
    templatefile("${path.module}/config/setup.sh", {
      nw_conf = file("${path.module}/config/99-vpn.conf")
      xfrm_conf = templatefile("${path.module}/config/xfrm-ifaces.service", {
        cgwside_tunnel1_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel1_cgw_inside_address
        cgwside_tunnel2_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel2_cgw_inside_address
      })
      cgw_gip             = aws_eip.this["onpremises_gateway_ec2_c"].public_ip
      awsside_tunnel1_gip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel1_address
      awsside_tunnel2_gip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel2_address
      tunnel1_psk         = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel1_preshared_key
      tunnel2_psk         = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel2_preshared_key
      charon_conf         = file("${path.module}/config/add-charon.conf")
      ens6_conf = templatefile("${path.module}/config/20-ens6.network", {
        onpremises_client_private_a_subnet_cidr           = local.subnets.onpremises_client_private_a.cidr
        onpremises_gateway_private_subnet_vpc_router_ip = cidrhost(local.subnets.onpremises_gateway_public_c.cidr, 1)
        aws_vpc_cidr                                      = local.vpcs.aws.cidr
      })
      rtbrule_conf = templatefile("${path.module}/config/tgw-ecmp.service", {
        aws_vpc_cidr = local.vpcs.aws.cidr
      })
      frr_conf = templatefile("${path.module}/config/frr_onpremises_gateway_ec2_c.conf", {
        cgw_asn                  = 65000
        cgw_gip                  = aws_eip.this["onpremises_gateway_ec2_c"].public_ip
        cgwside_tunnel1_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel1_cgw_inside_address
        cgwside_tunnel2_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel2_cgw_inside_address
        aws_tgw_asn              = 64512
        awsside_tunnel1_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel1_vgw_inside_address
        awsside_tunnel2_insideip = aws_vpn_connection.this["onpremises_gateway_ec2_c"].tunnel2_vgw_inside_address
        onpremises_nw_cidr       = local.vpcs.onpremises.cidr
      })
      snat_conf = templatefile("${path.module}/config/snat_sources.conf", {
        aws_client_private_a_subnet_cidr        = local.subnets.aws_client_private_a.cidr
        onpremises_client_private_a_subnet_cidr = local.subnets.onpremises_client_private_a.cidr
      })
      ipset_conf = file("${path.module}/config/nat-ens5-ipset.service")
    })
  )
  tags = {
    Name = local.instances.onpremises_gateway_ec2_c.name
  }
  # userdataを変更すると再起動が走るため抑止
  # 代わりに、user_data_replace_on_change は効かなくなる
  lifecycle {
    ignore_changes = [
      user_data_base64
    ]
  }
}

/************************************************************
Elastice IP Association
************************************************************/
resource "aws_eip_association" "gateway_a" {
  instance_id   = aws_instance.gateway_a.id
  allocation_id = aws_eip.this["onpremises_gateway_ec2_a"].allocation_id
}

resource "aws_eip_association" "gateway_c" {
  instance_id   = aws_instance.gateway_c.id
  allocation_id = aws_eip.this["onpremises_gateway_ec2_c"].allocation_id
}

/************************************************************
Secondary ENI
************************************************************/
resource "aws_network_interface_attachment" "gateway_a" {
  depends_on = [aws_eip_association.gateway_a]

  instance_id          = aws_instance.gateway_a.id
  network_interface_id = aws_network_interface.this["${local.instances.onpremises_gateway_ec2_a.secondary_eni_key}"].id
  device_index         = 1
}

resource "aws_network_interface_attachment" "gateway_c" {
  depends_on = [aws_eip_association.gateway_c]

  instance_id          = aws_instance.gateway_c.id
  network_interface_id = aws_network_interface.this["${local.instances.onpremises_gateway_ec2_c.secondary_eni_key}"].id
  device_index         = 1
}