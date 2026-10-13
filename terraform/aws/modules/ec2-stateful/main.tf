data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_security_group" "this" {
  name_prefix            = "${var.name_prefix}-"
  description            = "Allow application traffic to the stateful EC2 instance"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.this.id
  description       = "Allow application traffic from the approved IPv4 address"
  cidr_ipv4         = var.allowed_cidr
  from_port         = var.app_port
  ip_protocol       = "tcp"
  to_port           = var.app_port

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound IPv4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = var.tags
}

resource "aws_iam_role" "this" {
  name_prefix        = "${var.name_prefix}-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.name_prefix}-"
  role        = aws_iam_role.this.name

  tags = var.tags
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-data"
  })
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    data_volume_id = aws_ebs_volume.data.id
    repository_url = var.repository_url
    repository_ref = var.repository_ref
    app_port       = var.app_port
    ollama_image   = var.ollama_image
    ollama_model   = var.ollama_model
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 16
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = var.tags
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-instance"
  })

  depends_on = [
    aws_iam_role_policy_attachment.ssm_managed_instance_core,
    aws_vpc_security_group_egress_rule.all_ipv4,
  ]
}

resource "aws_volume_attachment" "data" {
  device_name                    = "/dev/sdf"
  instance_id                    = aws_instance.this.id
  volume_id                      = aws_ebs_volume.data.id
  stop_instance_before_detaching = true
}
