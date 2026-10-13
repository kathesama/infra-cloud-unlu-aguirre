# Lab 3 on AWS: Terraform design

Date: 2026-10-12
Status: approved

## Objective

Adapt the course template for the Lab 3 workload on AWS without removing or
rewriting the original GCP material. The AWS implementation must demonstrate
that the compute instance and Docker container are disposable while the
application and model data survive on an independent EBS volume.

## Scope

The first AWS increment covers only the infrastructure required by Lab 3:

- one EC2 instance running Amazon Linux 2023;
- one independent 10 GiB `gp3` EBS volume;
- one security group for the lab service;
- one minimal IAM role and instance profile for AWS Systems Manager access;
- idempotent bootstrap that installs Docker and mounts the EBS volume;
- deployment of the existing pattern service from `app/`;
- persistence checks across container and EC2 replacement;
- a CPU-only Ollama workload using `llama3.2:1b` as the student artifact.

ECR, EKS, CI/CD, remote Terraform state, custom VPCs, load balancers and DNS
are outside this increment. They can be introduced by later classes without
expanding the Lab 3 resource footprint.

## Repository layout

The GCP Terraform tree remains unchanged. AWS code is added alongside it:

```text
terraform/
├── envs/                     # original GCP environments
├── modules/                  # original GCP modules
└── aws/
    ├── modules/
    │   └── ec2-stateful/
    │       ├── main.tf
    │       ├── variables.tf
    │       ├── outputs.tf
    │       ├── versions.tf
    │       └── user-data.sh.tftpl
    └── envs/
        └── lab3/
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            ├── versions.tf
            └── lab3.tfvars.example
```

This parallel layout makes the cloud-provider boundary explicit and avoids
breaking the paths used by the original course guides and Makefile.

## Existing AWS resources

Terraform will reuse the account's current default VPC and a default subnet in
`us-east-1a`. They are discovered with AWS data sources or supplied as input;
Terraform will not create another VPC, subnet, route table, internet gateway,
NAT gateway or budget.

All resources created for the lab receive at least these tags:

```text
Project   = unlu-ia-aguirre
Lab       = lab3-servicio-patron
ManagedBy = terraform
```

## Managed resources

The `ec2-stateful` module owns the following AWS resources:

1. An EC2 security group with no public SSH rule. The application port is
   allowed only from a CIDR supplied by the student.
2. An IAM role, managed-policy attachment and instance profile granting only
   `AmazonSSMManagedInstanceCore` so the instance can be accessed through
   Session Manager without storing SSH keys in the repository.
3. An EC2 instance based on the current Amazon Linux 2023 AMI obtained from
   the public SSM parameter. The instance receives a public IPv4 address in
   the existing default subnet.
4. A 10 GiB `gp3` EBS volume created in the same Availability Zone as the
   subnet.
5. A separate EBS volume attachment. The data disk is not an inline EC2 block
   device, so replacing the instance does not imply replacing the volume.

The initial instance type is configurable. The default is `c7i-flex.large`
because it is x86_64, provides 2 vCPU and 4 GiB of memory, and is eligible for
the account's Free plan. Only one instance is kept running at a time.

## Bootstrap and disk safety

The startup script must be idempotent and fail fast. It will:

1. install and enable Docker;
2. wait for the attached data device;
3. identify the EBS device by its volume ID/NVMe serial instead of assuming
   that a requested name such as `/dev/sdf` is the final Linux device name;
4. inspect the device for an existing filesystem;
5. create an `ext4` filesystem only when no filesystem signature exists;
6. mount the volume at `/mnt/lab3-data` by UUID through `/etc/fstab`;
7. create separate persistent directories for the pattern service and Ollama;
8. clone the public student repository at an explicit Git ref and build the
   pattern-service image from `app/`;
9. start the pattern-service container with
   `/mnt/lab3-data/app:/data` mounted into the container;
10. start Ollama with `/mnt/lab3-data/ollama:/root/.ollama` mounted into the
   container and listen only on the instance unless a later step explicitly
   exposes a proxy endpoint.

The script must never format a device that already has a filesystem. This is
the key safeguard when the same EBS volume is attached to a replacement EC2
instance.

## Application and model behavior

The existing `app/` image remains the pattern service and exposes:

- `GET /` for the persistent visit counter;
- `GET /healthz` for health checks;
- `GET /metrics` for Prometheus-format metrics;
- `POST /items` and `GET /items` for additional persisted state.

The student workload is Ollama with `llama3.2:1b`, running CPU-only. Its model
files are downloaded directly to the EBS-backed Ollama directory in AWS; the
model is not downloaded to the student's laptop and is not committed to Git.

The application source comes from the public repository
`https://github.com/kathesama/infra-cloud-unlu-aguirre`. The Git ref is a
Terraform input so a deployment can be pinned and reproduced instead of
silently building whatever happens to be at the head of `main`.

Ollama is not a replacement for the template's `model/` example. The original
Iris/scikit-learn example remains unchanged so the course baseline stays
recognizable.

## Persistence demonstration

The evidence sequence is:

1. create the infrastructure and wait for both health checks;
2. generate state in the pattern service and download the Ollama model;
3. remove and recreate the containers while keeping the EBS mount;
4. verify that the counter, items and Ollama model remain;
5. replace only the EC2 instance while preserving the EBS resource;
6. let the new instance mount the existing filesystem without formatting it;
7. verify the same application state and model are available;
8. record CPU inference latency and discuss the CPU/GPU trade-off.

Replacing the EC2 instance must be done through a Terraform plan that shows
the instance changing while the EBS volume remains unchanged.

## Terraform workflow

Local development uses this sequence from `terraform/aws/envs/lab3`:

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -var-file=lab3.tfvars
```

The example variable file contains placeholders only. The real
`lab3.tfvars`, Terraform state, plan files and any credentials remain
untracked.

`terraform apply` is a separate operational step because it creates billable
AWS resources. The saved plan must be reviewed before applying it. Cleanup is
also explicit: capture the required evidence first, then destroy the EC2
instance, EBS volume, security group and IAM resources managed by this stack.

## Security decisions

- No AWS access keys, passwords, private keys or account identifiers are
  committed.
- Session Manager is preferred over public SSH.
- Port `8080` is restricted to a caller-supplied CIDR instead of
  `0.0.0.0/0`.
- Ollama port `11434` is not publicly exposed by default.
- The instance role contains only the Systems Manager managed policy for this
  increment.
- The default security group is not modified.
- Resource names and tags make cleanup and cost attribution straightforward.

## Validation and acceptance criteria

Before any AWS apply:

- Terraform formatting passes;
- `terraform init` completes for the AWS environment;
- `terraform validate` succeeds;
- the plan creates no VPC, subnet, route, NAT gateway, load balancer, ECR or
  EKS resources;
- the plan contains only the expected EC2, EBS, security-group and SSM access
  resources;
- no secret or generated state file is tracked.

The Lab 3 implementation is accepted when the HTTP endpoints respond, state
survives both container and EC2 replacement, the Ollama model survives on the
same EBS volume, CPU latency is measured, and the required evidence is saved
before cleanup.

## Future AWS increments

Later classes may add AWS modules beside this one:

- ECR instead of Artifact Registry;
- GitHub Actions OIDC to an AWS IAM role;
- EKS instead of GKE;
- S3 plus DynamoDB locking for shared Terraform state;
- CloudWatch and/or the template's Prometheus/Grafana stack.

Those additions are intentionally deferred so this lab remains small,
auditable and aligned with its persistence objective.
