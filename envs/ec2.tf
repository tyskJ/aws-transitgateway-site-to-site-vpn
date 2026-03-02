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
  for_each = local.eips
  depends_on = [ aws_internet_gateway.this ]

  domain            = each.value.domain
  network_interface = aws_network_interface.this[each.key].id
  tags = {
    Name = each.value.name
  }
}