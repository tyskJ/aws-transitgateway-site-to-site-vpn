/************************************************************
IAM Role - EC2
************************************************************/
data "aws_iam_policy_document" "ec2_assume_role" {
  version = "2012-10-17"
  statement {
    sid    = "trustpolicy"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "ec2_role" {
  name               = "iam-role-for-all-ec2"
  description        = "For EC2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags = {
    Name = "iam-role-for-all-ec2"
  }
}
resource "aws_iam_role_policy_attachment" "ec2_role_aws_managed_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:${local.partition_name}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}