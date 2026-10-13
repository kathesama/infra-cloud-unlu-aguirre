variable "aws_region" {
  description = "AWS region in which to create the lab resources."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability Zone in which to place the lab instance."
  type        = string
  default     = "us-east-1a"
}

variable "allowed_cidr" {
  description = "Single public IPv4 address in CIDR notation allowed to access the lab instance."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && !strcontains(var.allowed_cidr, ":") && endswith(var.allowed_cidr, "/32")
    error_message = "allowed_cidr must be a valid IPv4 /32 CIDR; IPv6 and world-open CIDRs are not allowed."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the lab host."
  type        = string
  default     = "c7i-flex.large"
}

variable "data_volume_size_gb" {
  description = "Size in GiB of the persistent data volume."
  type        = number
  default     = 10

  validation {
    condition     = var.data_volume_size_gb >= 10 && floor(var.data_volume_size_gb) == var.data_volume_size_gb
    error_message = "data_volume_size_gb must be an integer of at least 10 GiB."
  }
}

variable "repository_url" {
  description = "Git repository cloned onto the lab instance."
  type        = string
  default     = "https://github.com/kathesama/infra-cloud-unlu-aguirre.git"
}

variable "repository_ref" {
  description = "Git branch, tag, or commit checked out on the lab instance."
  type        = string
  default     = "main"
}

variable "app_port" {
  description = "TCP port exposed by the application."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535 && floor(var.app_port) == var.app_port && var.app_port != 11434
    error_message = "app_port must be an integer between 1 and 65535; port 11434 is reserved for loopback Ollama."
  }
}

variable "ollama_image" {
  description = "Pinned Ollama container image used by the lab."
  type        = string
  default     = "ollama/ollama:0.40.3"
}

variable "ollama_model" {
  description = "Ollama model pulled and served by the lab."
  type        = string
  default     = "llama3.2:1b"
}
