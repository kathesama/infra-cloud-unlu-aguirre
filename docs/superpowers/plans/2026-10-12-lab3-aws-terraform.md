# Lab 3 AWS Terraform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe, testable AWS Terraform stack that reuses the existing default network and runs the pattern service plus CPU-only Ollama on EC2 with state on an independent EBS volume.

**Architecture:** Keep the original GCP tree intact and add a parallel `terraform/aws` tree. A reusable `ec2-stateful` module owns EC2, EBS, a dedicated security group and the minimal SSM IAM profile; a `lab3` root discovers the existing default VPC/subnet and current Amazon Linux 2023 AMI. Bootstrap identifies the EBS disk by volume ID, formats only an unformatted device, mounts it by UUID, builds the public student repository at an explicit Git ref, and persists both application state and Ollama models on EBS.

**Tech Stack:** Terraform 1.16.5, HashiCorp AWS provider 6.68.0, Amazon EC2/EBS/IAM/SSM, Amazon Linux 2023, Docker, FastAPI pattern service, Ollama 0.40.3, `llama3.2:1b`.

---

Repository rule: do not create commits or pull requests. Each task ends with a validation checkpoint instead of a commit.

## File map

- `terraform/aws/modules/ec2-stateful/versions.tf`: Terraform and AWS provider constraints for the reusable module.
- `terraform/aws/modules/ec2-stateful/variables.tf`: typed module inputs and safety validations.
- `terraform/aws/modules/ec2-stateful/main.tf`: security group, SSM IAM profile, EBS, EC2 and volume attachment.
- `terraform/aws/modules/ec2-stateful/outputs.tf`: identifiers and known configuration needed by the root and tests.
- `terraform/aws/modules/ec2-stateful/user-data.sh.tftpl`: idempotent Docker, EBS, application and Ollama bootstrap.
- `terraform/aws/envs/lab3/versions.tf`: root Terraform and provider lock constraints.
- `terraform/aws/envs/lab3/variables.tf`: region, AZ, CIDR, sizing and pinned-source inputs.
- `terraform/aws/envs/lab3/main.tf`: existing-network discovery and module composition.
- `terraform/aws/envs/lab3/outputs.tf`: operator-facing URLs, IDs and SSM commands.
- `terraform/aws/envs/lab3/lab3.tfvars.example`: safe, non-secret example values.
- `terraform/aws/envs/lab3/tests/lab3.tftest.hcl`: mocked plan tests for defaults and public-exposure rejection.
- `Makefile`: include AWS Terraform roots and expose an AWS test target.
- `README.md`: link the AWS Lab 3 adaptation without altering the GCP course map.
- `docs/lab-03-aws.md`: exact validate, plan, apply, persistence-evidence and cleanup runbook.

### Task 1: Create the AWS root contract and a failing Terraform test

**Files:**

- Create: `terraform/aws/envs/lab3/versions.tf`
- Create: `terraform/aws/envs/lab3/variables.tf`
- Create: `terraform/aws/envs/lab3/tests/lab3.tftest.hcl`

- [ ] **Step 1: Pin Terraform and the AWS provider in the root**

Create `terraform/aws/envs/lab3/versions.tf`:

```hcl
terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.68.0"
    }
  }
}
```

- [ ] **Step 2: Define root inputs with a public-exposure guard**

Create `terraform/aws/envs/lab3/variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region used for Lab 3."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability Zone containing the reused default subnet and EBS volume."
  type        = string
  default     = "us-east-1a"
}

variable "allowed_cidr" {
  description = "Single public IPv4 address allowed to reach the pattern service, in /32 form."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && !strcontains(var.allowed_cidr, ":") && endswith(var.allowed_cidr, "/32")
    error_message = "allowed_cidr must be one IPv4 address in /32 form; 0.0.0.0/0 is not allowed."
  }
}

variable "instance_type" {
  description = "Free-plan-eligible x86 instance used for the CPU lab."
  type        = string
  default     = "c7i-flex.large"
}

variable "data_volume_size_gb" {
  description = "Size of the independent gp3 data volume."
  type        = number
  default     = 10

  validation {
    condition     = var.data_volume_size_gb >= 10
    error_message = "data_volume_size_gb must be at least 10 GiB."
  }
}

variable "repository_url" {
  description = "Public Git repository containing app/."
  type        = string
  default     = "https://github.com/kathesama/infra-cloud-unlu-aguirre.git"
}

variable "repository_ref" {
  description = "Explicit Git branch, tag or commit fetched by the instance."
  type        = string
  default     = "main"
}

variable "app_port" {
  description = "Public TCP port of the pattern service."
  type        = number
  default     = 8080
}

variable "ollama_image" {
  description = "Pinned Ollama container image."
  type        = string
  default     = "ollama/ollama:0.40.3"
}

variable "ollama_model" {
  description = "Small CPU-friendly generative model downloaded to EBS."
  type        = string
  default     = "llama3.2:1b"
}
```

- [ ] **Step 3: Write the mocked plan contract before the root/module exist**

Create `terraform/aws/envs/lab3/tests/lab3.tftest.hcl`:

```hcl
mock_provider "aws" {}

override_data {
  target = data.aws_vpc.default
  values = { id = "vpc-0123456789abcdef0" }
}

override_data {
  target = data.aws_subnets.default_az
  values = { ids = ["subnet-0123456789abcdef0"] }
}

override_data {
  target = data.aws_subnet.selected
  values = {
    id                = "subnet-0123456789abcdef0"
    availability_zone = "us-east-1a"
  }
}

override_data {
  target = data.aws_ssm_parameter.al2023_ami
  values = { value = "ami-0123456789abcdef0" }
}

run "safe_defaults" {
  command = plan

  variables {
    allowed_cidr   = "203.0.113.10/32"
    repository_ref = "main"
  }

  assert {
    condition     = module.lab3.instance_type == "c7i-flex.large"
    error_message = "The default instance must remain c7i-flex.large for the CPU lab on AWS Free Plan."
  }

  assert {
    condition     = module.lab3.data_volume_size_gb == 10
    error_message = "The independent EBS volume must default to 10 GiB."
  }

  assert {
    condition     = module.lab3.app_port == 8080
    error_message = "The pattern service must remain on port 8080."
  }
}

run "reject_world_open_ingress" {
  command = plan

  variables {
    allowed_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.allowed_cidr]
}
```

- [ ] **Step 4: Run the test and confirm it fails for the missing root composition**

Run from `terraform/aws/envs/lab3`:

```bash
terraform init -backend=false -input=false
terraform test
```

Expected: FAIL because `data.aws_vpc.default`, the other data sources and `module.lab3` are not defined yet. This is the intentional red test.

### Task 2: Implement the reusable stateful EC2 module

**Files:**

- Create: `terraform/aws/modules/ec2-stateful/versions.tf`
- Create: `terraform/aws/modules/ec2-stateful/variables.tf`
- Create: `terraform/aws/modules/ec2-stateful/main.tf`
- Create: `terraform/aws/modules/ec2-stateful/outputs.tf`

- [ ] **Step 1: Add module provider constraints**

Create `terraform/aws/modules/ec2-stateful/versions.tf`:

```hcl
terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.68.0"
    }
  }
}
```

- [ ] **Step 2: Define the module interface**

Create `terraform/aws/modules/ec2-stateful/variables.tf`:

```hcl
variable "name_prefix" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "availability_zone" { type = string }
variable "allowed_cidr" { type = string }
variable "app_port" { type = number }
variable "data_volume_size_gb" { type = number }
variable "repository_url" { type = string }
variable "repository_ref" { type = string }
variable "ollama_image" { type = string }
variable "ollama_model" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
```

- [ ] **Step 3: Implement only the Lab 3 resources**

Create `terraform/aws/modules/ec2-stateful/main.tf`:

```hcl
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_security_group" "this" {
  name_prefix            = "${var.name_prefix}-"
  description            = "Lab 3 pattern service; managed by Terraform"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.this.id
  description       = "Pattern service from the student's current public IP"
  cidr_ipv4         = var.allowed_cidr
  from_port         = var.app_port
  to_port           = var.app_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Package, source, image and model downloads"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_iam_role" "ssm" {
  name_prefix        = "${var.name_prefix}-ssm-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.name_prefix}-"
  role        = aws_iam_role.ssm.name
  tags        = var.tags
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-data" })
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
    app_port        = var.app_port
    ollama_image    = var.ollama_image
    ollama_model    = var.ollama_model
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = 16
    volume_type           = "gp3"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ec2" })
}

resource "aws_volume_attachment" "data" {
  device_name                    = "/dev/sdf"
  instance_id                    = aws_instance.this.id
  volume_id                      = aws_ebs_volume.data.id
  stop_instance_before_detaching = true
}
```

- [ ] **Step 4: Expose the stable operator/test contract**

Create `terraform/aws/modules/ec2-stateful/outputs.tf`:

```hcl
output "instance_id" { value = aws_instance.this.id }
output "public_ip" { value = aws_instance.this.public_ip }
output "security_group_id" { value = aws_security_group.this.id }
output "data_volume_id" { value = aws_ebs_volume.data.id }
output "instance_type" { value = aws_instance.this.instance_type }
output "data_volume_size_gb" { value = aws_ebs_volume.data.size }
output "app_port" { value = var.app_port }
```

- [ ] **Step 5: Validate the module syntax**

Run:

```bash
cd terraform/aws/modules/ec2-stateful
terraform init -backend=false -input=false
terraform validate
```

Expected: `Success! The configuration is valid.`

### Task 3: Implement safe, idempotent EC2 bootstrap

**Files:**

- Create: `terraform/aws/modules/ec2-stateful/user-data.sh.tftpl`

- [ ] **Step 1: Add disk discovery, format guard and persistent mounts**

Create `terraform/aws/modules/ec2-stateful/user-data.sh.tftpl`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

exec > >(tee /var/log/lab3-bootstrap.log | logger -t lab3-user-data -s 2>/dev/console) 2>&1

DATA_VOLUME_ID="${data_volume_id}"
REPOSITORY_URL="${repository_url}"
REPOSITORY_REF="${repository_ref}"
APP_PORT="${app_port}"
OLLAMA_IMAGE="${ollama_image}"
OLLAMA_MODEL="${ollama_model}"
MOUNT_POINT="/mnt/lab3-data"
SOURCE_DIR="/opt/infra-cloud-unlu-aguirre"

dnf install -y docker git curl nvme-cli e2fsprogs
systemctl enable --now docker
systemctl enable --now amazon-ssm-agent

find_data_device() {
  local serial
  serial="$${DATA_VOLUME_ID//-/}"
  lsblk -ndo PATH,SERIAL | awk -v expected="$serial" '$2 == expected { print $1; exit }'
}

DATA_DEVICE=""
for _ in $(seq 1 120); do
  DATA_DEVICE="$(find_data_device || true)"
  if [[ -n "$DATA_DEVICE" && -b "$DATA_DEVICE" ]]; then
    break
  fi
  sleep 5
done

if [[ -z "$DATA_DEVICE" || ! -b "$DATA_DEVICE" ]]; then
  echo "EBS volume $DATA_VOLUME_ID was not attached after 10 minutes" >&2
  exit 1
fi

FILESYSTEM_TYPE="$(blkid -s TYPE -o value "$DATA_DEVICE" || true)"
if [[ -z "$FILESYSTEM_TYPE" ]]; then
  mkfs.ext4 -F "$DATA_DEVICE"
elif [[ "$FILESYSTEM_TYPE" != "ext4" ]]; then
  echo "Refusing to mount unexpected filesystem type: $FILESYSTEM_TYPE" >&2
  exit 1
fi

install -d -m 0755 "$MOUNT_POINT"
DATA_UUID="$(blkid -s UUID -o value "$DATA_DEVICE")"
if ! grep -q "^UUID=$DATA_UUID " /etc/fstab; then
  printf 'UUID=%s %s ext4 defaults,nofail 0 2\n' "$DATA_UUID" "$MOUNT_POINT" >> /etc/fstab
fi
mountpoint -q "$MOUNT_POINT" || mount "$MOUNT_POINT"

install -d -m 0755 "$MOUNT_POINT/app" "$MOUNT_POINT/ollama"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  install -d -m 0755 "$SOURCE_DIR"
  git -C "$SOURCE_DIR" init
  git -C "$SOURCE_DIR" remote add origin "$REPOSITORY_URL"
fi
git -C "$SOURCE_DIR" fetch --depth 1 origin "$REPOSITORY_REF"
git -C "$SOURCE_DIR" checkout --force FETCH_HEAD

docker build -t app:lab3 "$SOURCE_DIR/app"
docker rm -f servicio-patron 2>/dev/null || true
docker run -d \
  --name servicio-patron \
  --restart unless-stopped \
  -p "$APP_PORT:8080" \
  -e DATA_DIR=/data \
  -e PORT=8080 \
  -v "$MOUNT_POINT/app:/data" \
  app:lab3

for _ in $(seq 1 60); do
  curl -fsS "http://127.0.0.1:$APP_PORT/healthz" && break
  sleep 2
done
curl -fsS "http://127.0.0.1:$APP_PORT/healthz"

docker pull "$OLLAMA_IMAGE"
docker rm -f ollama 2>/dev/null || true
docker run -d \
  --name ollama \
  --restart unless-stopped \
  -p 127.0.0.1:11434:11434 \
  -v "$MOUNT_POINT/ollama:/root/.ollama" \
  "$OLLAMA_IMAGE"

for _ in $(seq 1 60); do
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null && break
  sleep 2
done
curl -fsS http://127.0.0.1:11434/api/tags >/dev/null
docker exec ollama ollama pull "$OLLAMA_MODEL"

touch "$MOUNT_POINT/bootstrap-complete"
echo "Lab 3 bootstrap completed"
```

- [ ] **Step 2: Parse the rendered shell without running it**

After Task 4 composes the root, run:

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq -r '.planned_values.root_module.child_modules[0].resources[] | select(.type == "aws_instance") | .values.user_data' > /tmp/lab3-user-data.sh
bash -n /tmp/lab3-user-data.sh
```

Expected: `bash -n` exits 0 and produces no output. Do not execute the rendered script locally.

### Task 4: Compose the Lab 3 AWS environment

**Files:**

- Create: `terraform/aws/envs/lab3/main.tf`
- Create: `terraform/aws/envs/lab3/outputs.tf`
- Create: `terraform/aws/envs/lab3/lab3.tfvars.example`

- [ ] **Step 1: Discover existing resources and call the module**

Create `terraform/aws/envs/lab3/main.tf`:

```hcl
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
}

data "aws_subnet" "selected" {
  id = sort(data.aws_subnets.default_az.ids)[0]
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "lab3" {
  source = "../../modules/ec2-stateful"

  name_prefix        = "unlu-lab3"
  ami_id             = data.aws_ssm_parameter.al2023_ami.value
  instance_type      = var.instance_type
  vpc_id             = data.aws_vpc.default.id
  subnet_id          = data.aws_subnet.selected.id
  availability_zone  = data.aws_subnet.selected.availability_zone
  allowed_cidr       = var.allowed_cidr
  app_port           = var.app_port
  data_volume_size_gb = var.data_volume_size_gb
  repository_url     = var.repository_url
  repository_ref     = var.repository_ref
  ollama_image       = var.ollama_image
  ollama_model       = var.ollama_model

  tags = {
    Environment = "lab3"
    Owner       = "kathesama"
  }
}
```

- [ ] **Step 2: Add operator-facing outputs**

Create `terraform/aws/envs/lab3/outputs.tf`:

```hcl
output "instance_id" {
  description = "EC2 instance managed by the Lab 3 stack."
  value       = module.lab3.instance_id
}

output "public_ip" {
  description = "Public IPv4 address of the current EC2 instance."
  value       = module.lab3.public_ip
}

output "app_url" {
  description = "Pattern-service URL after bootstrap completes."
  value       = "http://${module.lab3.public_ip}:${module.lab3.app_port}"
}

output "data_volume_id" {
  description = "Independent EBS volume that must survive EC2 replacement."
  value       = module.lab3.data_volume_id
}

output "security_group_id" {
  value = module.lab3.security_group_id
}

output "ssm_start_session" {
  value = "aws ssm start-session --target ${module.lab3.instance_id} --region ${var.aws_region}"
}

output "bootstrap_log_command" {
  value = "aws ssm start-session --target ${module.lab3.instance_id} --region ${var.aws_region} --document-name AWS-StartInteractiveCommand --parameters command='sudo tail -n 200 /var/log/lab3-bootstrap.log'"
}
```

- [ ] **Step 3: Add a non-secret example variable file**

Create `terraform/aws/envs/lab3/lab3.tfvars.example`:

```hcl
aws_region          = "us-east-1"
availability_zone   = "us-east-1a"
allowed_cidr        = "203.0.113.10/32"
instance_type       = "c7i-flex.large"
data_volume_size_gb = 10
repository_ref      = "main"
```

The documentation must state that `203.0.113.10/32` is the RFC 5737 documentation range and must not be used for a live apply.

- [ ] **Step 4: Run the mocked tests again**

Run:

```bash
cd terraform/aws/envs/lab3
terraform fmt -recursive
terraform test
```

Expected: `Success! 7 passed, 0 failed.`

### Task 5: Integrate AWS validation into the template without breaking GCP

**Files:**

- Modify: `Makefile`
- Modify: `README.md`
- Create: `docs/lab-03-aws.md`

- [ ] **Step 1: Extend the Makefile roots and add an AWS test target**

Change the existing `TF_ROOTS` line to:

```make
TF_ROOTS      := envs/dev envs/prod modules/network modules/vm modules/artifact-registry modules/gke \
                 aws/modules/ec2-stateful aws/envs/lab3
```

Add `tf-test-aws` to `.PHONY`, then add:

```make
tf-test-aws: ## mocked Terraform tests for the AWS Lab 3 stack
	cd terraform/aws/envs/lab3 && $(TF) init -backend=false -input=false >/dev/null && $(TF) test
```

- [ ] **Step 2: Add an AWS adaptation section to the README**

Insert after the course map:

```markdown
## Adaptación personal a AWS

Este repositorio conserva intactos los ejemplos de GCP de la cátedra y suma
una implementación paralela para AWS. El Lab 3 usa EC2 + un volumen EBS
independiente, acceso por Session Manager y el servicio patrón en Docker.

La guía operativa está en [docs/lab-03-aws.md](docs/lab-03-aws.md). El código
Terraform vive bajo `terraform/aws/`; no crea otra VPC ni modifica el security
group por defecto.
```

- [ ] **Step 3: Write the complete operator runbook**

Create `docs/lab-03-aws.md` with these exact sections and commands:

```markdown
# Lab 3 en AWS: EC2, EBS y una carga de IA stateful

## Qué reutiliza y qué crea

Reutiliza la VPC por defecto y una subred existente en `us-east-1a`. Crea una
EC2, un EBS `gp3` de 10 GiB, un security group dedicado y el perfil IAM mínimo
para Session Manager. No crea VPC, NAT Gateway, ECR ni EKS.

## Validación sin crear recursos

```bash
cd terraform/aws/envs/lab3
terraform init -backend=false -input=false
terraform fmt -check -recursive
terraform validate
terraform test
```

## Plan real en AWS

```bash
export TF_VAR_allowed_cidr="$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')/32"
export TF_VAR_repository_ref="$(curl -fsSL https://api.github.com/repos/kathesama/infra-cloud-unlu-aguirre/commits/main | jq -r .sha)"
terraform plan -out=tfplan
terraform show tfplan
```

Revisar el plan completo antes de aplicar. `terraform plan` no crea recursos;
`terraform apply tfplan` sí crea recursos facturables y se ejecuta únicamente
después de la aprobación explícita.

## Verificación después del apply

```bash
terraform output
curl "$(terraform output -raw app_url)/healthz"
curl "$(terraform output -raw app_url)/"
curl "$(terraform output -raw app_url)/metrics" | grep '^servicio_patron_hits_total'
```

Para revisar el bootstrap:

```bash
aws ssm start-session --target "$(terraform output -raw instance_id)" --region us-east-1
sudo tail -n 200 /var/log/lab3-bootstrap.log
```

## Prueba de persistencia del contenedor

Dentro de la sesión SSM:

```bash
curl http://127.0.0.1:8080/
curl -sS -X POST http://127.0.0.1:8080/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"aws-ebs","value":"persiste"}'
sudo docker rm -f servicio-patron
sudo docker run -d --name servicio-patron --restart unless-stopped \
  -p 8080:8080 -e DATA_DIR=/data -e PORT=8080 \
  -v /mnt/lab3-data/app:/data app:lab3
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/items
sudo docker exec ollama ollama list
```

## Prueba de persistencia de la EC2

Guardar primero el ID del volumen:

```bash
terraform output -raw data_volume_id
```

Reemplazar solamente la instancia y su attachment:

```bash
terraform plan -replace=module.lab3.aws_instance.this -out=replace-ec2.plan
terraform show replace-ec2.plan
```

El plan debe reemplazar EC2 y el attachment, mientras el EBS queda sin cambios.
Aplicar ese plan solamente después de revisar la evidencia anterior.

## Medición de Ollama en CPU

Dentro de la nueva EC2:

```bash
/usr/bin/time -f 'elapsed=%e cpu=%P max_rss_kb=%M' \
  sudo docker exec ollama ollama run llama3.2:1b \
  'Explicá en dos oraciones por qué el estado debe vivir fuera del contenedor.'
sudo docker stats --no-stream ollama
sudo docker exec ollama ollama list
```

## Limpieza

Después de guardar toda la evidencia:

```bash
terraform plan -destroy -out=destroy.plan
terraform show destroy.plan
terraform apply destroy.plan
```

La destrucción elimina también el EBS. Confirmar que la entrega ya contiene
las pruebas de persistencia antes de aplicar `destroy.plan`.
```

- [ ] **Step 4: Verify documentation links and targets**

Run from the repository root:

```bash
rg -n "lab-03-aws|tf-test-aws|aws/envs/lab3" README.md Makefile docs/lab-03-aws.md
```

Expected: the README link, Makefile target and AWS paths all appear.

### Task 6: Run repository-level offline verification

**Files:**

- Verify only; no file changes expected.

- [ ] **Step 1: Obtain a portable Terraform binary in AWS CloudShell**

CloudShell currently has neither Terraform nor OpenTofu. Install a user-local,
checksum-verified binary without changing system packages:

```bash
TF_VERSION=1.16.5
mkdir -p "$HOME/bin" "$HOME/tmp/terraform-$TF_VERSION"
cd "$HOME/tmp/terraform-$TF_VERSION"
curl -fsSLO "https://releases.hashicorp.com/terraform/$TF_VERSION/terraform_${TF_VERSION}_linux_amd64.zip"
curl -fsSLO "https://releases.hashicorp.com/terraform/$TF_VERSION/terraform_${TF_VERSION}_SHA256SUMS"
grep "terraform_${TF_VERSION}_linux_amd64.zip" "terraform_${TF_VERSION}_SHA256SUMS" | sha256sum -c -
unzip -o "terraform_${TF_VERSION}_linux_amd64.zip" -d "$HOME/bin"
export PATH="$HOME/bin:$PATH"
terraform version
```

Expected: checksum `OK` and `Terraform v1.16.5`.

- [ ] **Step 2: Format and validate only the AWS roots first**

Run:

```bash
terraform -chdir=terraform/aws fmt -check -recursive
terraform -chdir=terraform/aws/modules/ec2-stateful init -backend=false -input=false
terraform -chdir=terraform/aws/modules/ec2-stateful validate
terraform -chdir=terraform/aws/envs/lab3 init -backend=false -input=false
terraform -chdir=terraform/aws/envs/lab3 validate
terraform -chdir=terraform/aws/envs/lab3 test
```

Expected: both validations succeed and the test summary reports `7 passed, 0 failed`.

- [ ] **Step 3: Confirm the original GCP files remain unchanged by the AWS work**

Run the repository's allowed verification commands:

```bash
git status --short
git diff -- terraform/envs terraform/modules
```

Expected: the status lists only the planned AWS/docs/Makefile changes, and the
diff for the original GCP directories is empty.

### Task 7: Produce and audit a real AWS plan without applying it

**Files:**

- Generated and ignored: `terraform/aws/envs/lab3/tfplan`
- No tracked file changes expected.

- [ ] **Step 1: Derive the caller CIDR and immutable repository ref**

Run in authenticated AWS CloudShell from `terraform/aws/envs/lab3`:

```bash
export TF_VAR_allowed_cidr="$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')/32"
export TF_VAR_repository_ref="$(curl -fsSL https://api.github.com/repos/kathesama/infra-cloud-unlu-aguirre/commits/main | jq -r .sha)"
printf 'allowed_cidr=%s\nrepository_ref=%s\n' "$TF_VAR_allowed_cidr" "$TF_VAR_repository_ref"
```

Expected: one `/32` CIDR and one 40-character Git commit SHA.

- [ ] **Step 2: Create a saved plan**

Run:

```bash
terraform plan -out=tfplan
```

Expected: a create-only plan for the Lab 3 stack. No AWS resource is created.

- [ ] **Step 3: Audit the resource-type inventory**

Run:

```bash
terraform show -json tfplan | jq -r '
  [.resource_changes[]
   | select(.change.actions != ["no-op"])
   | .type]
  | sort
  | group_by(.)
  | map({type: .[0], count: length})'
```

Expected managed types only:

```text
aws_ebs_volume
aws_iam_instance_profile
aws_iam_role
aws_iam_role_policy_attachment
aws_instance
aws_security_group
aws_volume_attachment
aws_vpc_security_group_egress_rule
aws_vpc_security_group_ingress_rule
```

There must be no `aws_vpc`, `aws_subnet`, `aws_nat_gateway`, `aws_ecr_repository`,
`aws_eks_cluster` or load-balancer resource.

- [ ] **Step 4: Stop at the financial/resource-creation gate**

Do not run `terraform apply`. Report the exact plan summary, instance type,
EBS size, CIDR and expected managed-resource list to the user and request
approval for the billable AWS apply.

## Self-review record

- Spec coverage: every approved section maps to Tasks 1-7; later-course ECR,
  EKS, CI/CD and remote state remain explicitly out of scope.
- Safety: the plan reuses the default VPC/subnet, never modifies the default
  security group, rejects world-open ingress, uses SSM instead of SSH and
  formats only a volume with no filesystem signature.
- Persistence: EBS and its attachment are separate from EC2, so an EC2
  replacement plan can preserve the EBS resource.
- Reproducibility: Terraform/provider/Ollama are pinned; the live plan resolves
  `main` to a commit SHA.
- Placeholder scan: example-only RFC 5737 address is explicitly documented and
  blocked from live use by the runbook's derived `/32`; no code step contains
  an unresolved implementation placeholder.
- Type consistency: root inputs match module inputs and module outputs match
  the tests and operator outputs.
