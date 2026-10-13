output "instance_id" {
  description = "ID of the Lab 3 EC2 instance."
  value       = module.lab3.instance_id
}

output "public_ip" {
  description = "Public IPv4 address assigned to the Lab 3 EC2 instance."
  value       = module.lab3.public_ip
}

output "app_url" {
  description = "HTTP URL for the application running on the Lab 3 instance."
  value       = "http://${module.lab3.public_ip}:${var.app_port}"
}

output "data_volume_id" {
  description = "ID of the persistent EBS data volume attached to the Lab 3 instance."
  value       = module.lab3.data_volume_id
}

output "security_group_id" {
  description = "ID of the security group attached to the Lab 3 instance."
  value       = module.lab3.security_group_id
}

output "ssm_start_session" {
  description = "AWS CLI command that starts an SSM session on the Lab 3 instance."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.lab3.instance_id}"
}

output "bootstrap_log_command" {
  description = "AWS CLI command that tails the Lab 3 bootstrap log through SSM."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.lab3.instance_id} --document-name AWS-StartInteractiveCommand --parameters 'command=\"sudo tail /var/log/lab3-bootstrap.log\"'"
}
