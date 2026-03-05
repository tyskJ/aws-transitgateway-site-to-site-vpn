output "ssh_gateway_a" {
  value = <<-EOT
    ssh -i ${path.module}/.key/keypair.pem ubuntu@${aws_instance.this["onpremises_gateway_ec2_a"].id} \
    -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --profile admin"
  EOT
}