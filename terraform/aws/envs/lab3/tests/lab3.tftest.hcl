mock_provider "aws" {}

override_data {
  target = data.aws_vpc.default
  values = {
    id = "vpc-00000000000000000"
  }
}

override_data {
  target = data.aws_subnets.default_az
  values = {
    ids = ["subnet-00000000000000000"]
  }
}

override_data {
  target = data.aws_subnet.selected
  values = {
    id                = "subnet-00000000000000000"
    availability_zone = "us-east-1a"
  }
}

override_data {
  target = data.aws_ssm_parameter.al2023_ami
  values = {
    value = "ami-00000000000000000"
  }
}

override_data {
  target = module.lab3.data.aws_iam_policy_document.ec2_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }
      ]
    })
  }
}

run "safe_defaults" {
  command = plan

  variables {
    allowed_cidr   = "203.0.113.10/32"
    repository_ref = "main"
  }

  assert {
    condition     = module.lab3.instance_type == "c7i-flex.large"
    error_message = "The lab3 module must use c7i-flex.large by default on AWS Free Plan."
  }

  assert {
    condition     = module.lab3.data_volume_size_gb == 10
    error_message = "The lab3 module must use a 10 GiB data volume by default."
  }

  assert {
    condition     = module.lab3.app_port == 8080
    error_message = "The lab3 module must expose the application on port 8080 by default."
  }

  assert {
    condition     = strcontains(file("${path.module}/../../modules/ec2-stateful/user-data.sh.tftpl"), "wipefs -n --noheadings -O TYPE")
    error_message = "The bootstrap must use wipefs --output (-O), not the offset flag (-o), when checking signatures."
  }
}

run "reject_world_open_ingress" {
  command = plan

  variables {
    allowed_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.allowed_cidr]
}

run "reject_ipv6_ingress" {
  command = plan

  variables {
    allowed_cidr = "2001:db8::/32"
  }

  expect_failures = [var.allowed_cidr]
}

run "reject_broad_ipv4_ingress" {
  command = plan

  variables {
    allowed_cidr = "203.0.113.0/24"
  }

  expect_failures = [var.allowed_cidr]
}

run "reject_fractional_data_volume_size" {
  command = plan

  variables {
    allowed_cidr        = "203.0.113.10/32"
    data_volume_size_gb = 10.5
  }

  expect_failures = [var.data_volume_size_gb]
}

run "reject_out_of_range_app_port" {
  command = plan

  variables {
    allowed_cidr = "203.0.113.10/32"
    app_port     = 70000
  }

  expect_failures = [var.app_port]
}

run "reject_reserved_ollama_app_port" {
  command = plan

  variables {
    allowed_cidr = "203.0.113.10/32"
    app_port     = 11434
  }

  expect_failures = [var.app_port]
}
