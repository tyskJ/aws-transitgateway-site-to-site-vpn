data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_ami_ids" "ubuntu" {
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-*-24.04-amd64-server-*"]
  }
  sort_ascending = false # 降順（日次が最新のものから）
}