terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  profile = "admin"
  region  = "ap-northeast-1"
  default_tags {
    tags = {
      Env                = "prd"
      System             = "aws-transitgateway-site-to-site-vpn"
      ManagedByTerraform = "true"
    }
  }
}