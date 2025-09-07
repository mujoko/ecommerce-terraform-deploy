output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ecommerce_app.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.ecommerce_app.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.ecommerce_app.public_dns
}

output "application_url" {
  description = "URL to access the e-commerce application"
  value       = "http://${aws_instance.ecommerce_app.public_ip}:${var.app_port}"
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${aws_instance.ecommerce_app.public_ip}"
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ecommerce_sg.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = data.aws_subnet.default.id
}
