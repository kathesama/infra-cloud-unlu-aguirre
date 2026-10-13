provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "unlu-ia-aguirre"
      Lab       = "lab3-servicio-patron"
      ManagedBy = "terraform"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_az" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) == 1
      error_message = "Expected exactly one default subnet in availability zone ${var.availability_zone} for the default VPC."
    }
  }
}

data "aws_subnet" "selected" {
  id = sort(data.aws_subnets.default_az.ids)[0]
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "lab3" {
  source = "../../modules/ec2-stateful"

  name_prefix         = "unlu-lab3"
  ami_id              = data.aws_ssm_parameter.al2023_ami.value
  instance_type       = var.instance_type
  vpc_id              = data.aws_vpc.default.id
  subnet_id           = data.aws_subnet.selected.id
  availability_zone   = data.aws_subnet.selected.availability_zone
  allowed_cidr        = var.allowed_cidr
  app_port            = var.app_port
  data_volume_size_gb = var.data_volume_size_gb
  repository_url      = var.repository_url
  repository_ref      = var.repository_ref
  ollama_image        = var.ollama_image
  ollama_model        = var.ollama_model

  tags = {
    Environment = "lab3"
    Owner       = "kathesama"
  }
}
