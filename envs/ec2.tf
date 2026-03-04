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
EC2 - Gateway
************************************************************/
resource "aws_instance" "this" {
  for_each = local.instances

  ami           = data.aws_ami_ids.ubuntu.ids[0]
  key_name      = aws_key_pair.keypair.id
  instance_type = "c6i.large"
  subnet_id     = aws_subnet.this[each.value.subnet_key].id
  vpc_security_group_ids = [
    aws_security_group.this[each.value.sg_key].id
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
      Name = "${each.value.name}-root-volume"
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
  iam_instance_profile    = aws_iam_instance_profile.this[each.value.instanceprofile_key].name
  source_dest_check       = false
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

  domain   = each.value.domain
  instance = aws_instance.this[each.value.instance_key].id
  tags = {
    Name = each.value.name
  }
}

/************************************************************
Secondary ENI
************************************************************/
resource "aws_network_interface_attachment" "this" {
  for_each   = local.instances
  depends_on = [aws_eip.this]

  instance_id          = aws_instance.this[each.key].id
  network_interface_id = aws_network_interface.this[each.value.secondary_eni_key].id
  device_index         = 1
}