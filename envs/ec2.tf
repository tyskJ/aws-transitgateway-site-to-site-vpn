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

  domain            = each.value.domain
  network_interface = aws_network_interface.this[each.key].id
  tags = {
    Name = each.value.name
  }
}

/************************************************************
EC2 - Client
************************************************************/
resource "aws_instance" "aws_client" {
  ami                         = data.aws_ssm_parameter.amazonlinux_2023.value
  associate_public_ip_address = false
  key_name                    = aws_key_pair.keypair.id
  instance_type               = "t3.large"
  ebs_optimized               = true
  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
    tags = {
      Name = "aws-client-root-volume"
    }
  }
  subnet_id = aws_subnet.this["aws_client_private_a"].id
  vpc_security_group_ids = [
    aws_security_group.this["aws_client_ec2"].id
  ]
  metadata_options {
    http_tokens = "required"
  }
  maintenance_options {
    auto_recovery = "default"
  }
  disable_api_stop        = false
  disable_api_termination = false
  force_destroy           = true
  iam_instance_profile    = aws_iam_instance_profile.this["aws_client_ec2"].name
  tags = {
    Name = "aws-client"
  }
}

/************************************************************
EC2 - Gateway
************************************************************/
resource "aws_instance" "this" {
  for_each = local.instances

  ami           = data.aws_ssm_parameter.amazonlinux_2023.value
  key_name      = aws_key_pair.keypair.id
  instance_type = "c6i.large"
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
  primary_network_interface {
    network_interface_id = aws_network_interface.this[each.value.primary_eni_key].id
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
  tags = {
    Name = each.value.name
  }
}

resource "aws_network_interface_attachment" "this" {
  for_each = local.instances

  instance_id          = aws_instance.this[each.key].id
  network_interface_id = aws_network_interface.this[each.value.secondary_eni_key].id
  device_index         = 1
}