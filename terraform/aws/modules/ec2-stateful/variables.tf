variable "name_prefix" {
  description = "Prefix used to name the EC2 resources."
  type        = string
}

variable "ami_id" {
  description = "AMI ID used to launch the EC2 instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the stateful host."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which to create the security group."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID in which to launch the EC2 instance."
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone for the persistent data volume."
  type        = string
}

variable "allowed_cidr" {
  description = "Single public IPv4 /32 CIDR allowed to reach the application."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && !strcontains(var.allowed_cidr, ":") && endswith(var.allowed_cidr, "/32")
    error_message = "allowed_cidr must be a valid IPv4 /32 CIDR."
  }
}

variable "app_port" {
  description = "TCP port exposed by the application."
  type        = number

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535 && floor(var.app_port) == var.app_port && var.app_port != 11434
    error_message = "app_port must be an integer between 1 and 65535; port 11434 is reserved for loopback Ollama."
  }
}

variable "data_volume_size_gb" {
  description = "Size in GiB of the persistent EBS data volume."
  type        = number

  validation {
    condition     = var.data_volume_size_gb >= 10 && floor(var.data_volume_size_gb) == var.data_volume_size_gb
    error_message = "data_volume_size_gb must be an integer of at least 10 GiB."
  }
}

variable "repository_url" {
  description = "Git repository cloned onto the EC2 instance."
  type        = string
}

variable "repository_ref" {
  description = "Git branch, tag, or commit checked out on the EC2 instance."
  type        = string
}

variable "ollama_image" {
  description = "Pinned Ollama container image used by the instance."
  type        = string
}

variable "ollama_model" {
  description = "Ollama model pulled and served by the instance."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to resources that support tagging."
  type        = map(string)
  default     = {}
}
