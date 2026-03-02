/************************************************************
Common
************************************************************/
locals {
  account_id     = data.aws_caller_identity.current.account_id
  region_name    = data.aws_region.current.region
  partition_name = data.aws_partition.current.partition
}

/************************************************************
VPC & Subnets
************************************************************/
locals {
  vpcs = {
    aws = {
      name          = "aws-vpc"
      cidr          = "172.16.0.0/16"
      dns_hostnames = true
      dns_support   = true
    }
    onpremises = {
      name          = "onpremises-vpc"
      cidr          = "192.168.0.0/16"
      dns_hostnames = true
      dns_support   = true
    }
  }
  subnets = {
    aws_client_private_a = {
      vpc_key    = "aws"
      name       = "aws-client-private-subnet-a"
      az         = "a"
      cidr       = "172.16.1.0/24"
      map_public = false
    }
    aws_tgw_private_a = {
      vpc_key    = "aws"
      name       = "aws-tgw-private-subnet-a"
      az         = "a"
      cidr       = "172.16.254.240/28"
      map_public = false
    }
    onpremises_client_private_a = {
      vpc_key    = "onpremises"
      name       = "onpremises-client-private-subnet-a"
      az         = "a"
      cidr       = "192.168.1.0/24"
      map_public = false
    }
    onpremises_gateway_public_a = {
      vpc_key    = "onpremises"
      name       = "onpremises-gateway-public-subnet-a"
      az         = "a"
      cidr       = "192.168.254.240/28"
      map_public = false
    }
    onpremises_gateway_public_c = {
      vpc_key    = "onpremises"
      name       = "onpremises-gateway-public-subnet-c"
      az         = "c"
      cidr       = "192.168.255.240/28"
      map_public = false
    }
  }
}

/************************************************************
RouteTables
************************************************************/
locals {
  rtbs = {
    aws_client_private = {
      vpc_key = "aws"
      name    = "aws-client-private-rtb"
    }
    aws_tgw_private = {
      vpc_key = "aws"
      name    = "aws-tgw-private-rtb"
    }
    onpremises_client_private = {
      vpc_key = "onpremises"
      name    = "onpremises-client-private-rtb"
    }
    onpremises_gateway_public = {
      vpc_key = "onpremises"
      name    = "onpremises-gateway-public-rtb"
    }
  }
  associations = {
    aws_client_private_a = {
      rtb_key = "aws_client_private"
    }
    aws_tgw_private_a = {
      rtb_key = "aws_tgw_private"
    }
    onpremises_client_private_a = {
      rtb_key = "onpremises_client_private"
    }
    onpremises_gateway_public_a = {
      rtb_key = "onpremises_gateway_public"
    }
    onpremises_gateway_public_c = {
      rtb_key = "onpremises_gateway_public"
    }
  }
}

/************************************************************
Security Group
************************************************************/
locals {
  sgs = {
    aws_client_ec2 = {
      vpc_key     = "aws"
      name        = "aws-client-ec2-sg"
      description = "For AWS VPC Client EC2"
    }
    onpremises_gateway_ec2_gip = {
      vpc_key     = "onpremises"
      name        = "onpremises-gateway-ec2-gip-sg"
      description = "For Onpremises VPC Gateway EC2 GIP"
    }
    onpremises_gateway_ec2_pip = {
      vpc_key     = "onpremises"
      name        = "onpremises-gateway-ec2-pip-sg"
      description = "For Onpremises VPC Gateway EC2 PIP"
    }
    onpremises_cloudshell = {
      vpc_key     = "onpremises"
      name        = "onpremises-cloudshell-sg"
      description = "For Onpremises VPC CloudShell"
    }
  }
}

/************************************************************
EC2
************************************************************/
locals {
  instanceprofiles = {
    onpremises_client_ec2 = {
      name = "onpremises-client-ec2"
    }
    onpremises_gateway_ec2_a = {
      name = "onpremises-gateway-ec2-a"
    }
    onpremises_gateway_ec2_c = {
      name = "onpremises-gateway-ec2-c"
    }
  }
  enis = {
    onpremises_gateway_ec2_a_primary = {
      name        = "onpremises-gateway-a-primary-eni"
      description = "gateway a primary eni"
      subnet_key  = "onpremises_gateway_public_a"
      srcdst      = false
      sg_key      = "onpremises_gateway_ec2_gip"
    }
    onpremises_gateway_ec2_a_secondary = {
      name        = "onpremises-gateway-a-secondary-eni"
      description = "gateway a secondary eni"
      subnet_key  = "onpremises_gateway_public_a"
      srcdst      = false
      sg_key      = "onpremises_gateway_ec2_pip"
    }
    onpremises_gateway_ec2_c_primary = {
      name        = "onpremises-gateway-c-primary-eni"
      description = "gateway c primary eni"
      subnet_key  = "onpremises_gateway_public_c"
      srcdst      = false
      sg_key      = "onpremises_gateway_ec2_gip"
    }
    onpremises_gateway_ec2_c_secondary = {
      name        = "onpremises-gateway-c-secondary-eni"
      description = "gateway c secondary eni"
      subnet_key  = "onpremises_gateway_public_c"
      srcdst      = false
      sg_key      = "onpremises_gateway_ec2_pip"
    }
  }
  eips = {
    onpremises_gateway_ec2_a_primary = {
      name   = "onpremises-gateway-ec2-a-primary-eni-eip"
      domain = "vpc"
    }
    onpremises_gateway_ec2_c_primary = {
      name   = "onpremises-gateway-ec2-c-primary-eni-eip"
      domain = "vpc"
    }
  }
}