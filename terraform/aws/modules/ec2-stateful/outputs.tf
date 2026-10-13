output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IPv4 address assigned to the EC2 instance."
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "ID of the security group attached to the EC2 instance."
  value       = aws_security_group.this.id
}

output "data_volume_id" {
  description = "ID of the persistent EBS data volume."
  value       = aws_ebs_volume.data.id
}

output "instance_type" {
  description = "EC2 instance type configured for the stateful host."
  value       = aws_instance.this.instance_type
}

output "data_volume_size_gb" {
  description = "Configured size in GiB of the persistent data volume."
  value       = aws_ebs_volume.data.size
}

output "app_port" {
  description = "TCP port exposed by the application security-group rule."
  value       = var.app_port
}
