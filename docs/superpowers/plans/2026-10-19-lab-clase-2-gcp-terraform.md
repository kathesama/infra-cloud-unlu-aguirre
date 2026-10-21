# Lab Clase 2 en GCP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completar y documentar el Lab 1 de la Clase 2 en GCP con estado remoto, servicio patrón, drift, servidor Iris en CPU y cleanup verificable.

**Architecture:** El proyecto GCP existente se administra desde Google Cloud Shell con Terraform y dos estados GCS independientes. `dev` crea la red, Artifact Registry y el servicio patrón; `ia-artefacto` crea otra red, una service account mínima y una VM CPU para `model:v1`. Los planes se guardan y revisan antes de cada apply, y todos los comandos relevantes se registran como transcript y captura.

**Tech Stack:** Google Cloud Shell, gcloud, Terraform >= 1.6, GCS, Compute Engine, Artifact Registry, Cloud Build, IAM, Docker, FastAPI, scikit-learn Iris, DOCX y PDF.

---

## Restricciones de ejecución

- Raíz local: `D:\projects\diplomado\infra-cloud-unlu-aguirre`.
- Proyecto GCP: `project-d9126d04-1cca-424d-8dc`.
- Nombre visible esperado: `unlu-ia-aguirre`.
- Región y zona: `us-central1` y `us-central1-a`.
- No usar comandos Git, crear commits ni abrir pull requests.
- No modificar ni borrar el árbol AWS existente.
- Los `*.tfvars`, planes, estados, credenciales y transcripts sin sanitizar no se agregan a la entrega.
- Antes de un apply facturable, un cambio IAM o una destrucción, revisar el plan y realizar la confirmación operativa requerida en ese momento.
- La ejecución es inline en este mismo chat; no se delega a subagentes.

## Mapa de archivos

**Crear:**

- `terraform/envs/ia-artefacto/backend.tf`: backend GCS con prefijo independiente.
- `terraform/envs/ia-artefacto/main.tf`: red, registry reutilizado, service account, IAM y VM Iris.
- `terraform/envs/ia-artefacto/variables.tf`: entradas del entorno Iris.
- `terraform/envs/ia-artefacto/outputs.tf`: IP, URL, registry y service account.
- `terraform/envs/ia-artefacto/ia.tfvars.example`: ejemplo no sensible.
- `docs/lab-clase-2-gcp.md`: bitácora reproducible y resultados reales.
- `docs/entrega/Lab-Clase-2-Terraform-GCP-Katherine-Aguirre.docx`: informe editable.
- `docs/entrega/Lab-Clase-2-Terraform-GCP-Katherine-Aguirre.pdf`: entrega final.

**Crear sólo en Cloud Shell y mantener fuera de la entrega:**

- `terraform/envs/dev/dev.tfvars`.
- `terraform/envs/ia-artefacto/ia.tfvars`.
- `terraform/envs/dev/*.plan`.
- `terraform/envs/ia-artefacto/*.plan`.
- `evidence/*.log` y el paquete de evidencias sin sanitizar.

**No modificar:**

- `terraform/modules/network/*`.
- `terraform/modules/vm/*`.
- `terraform/modules/artifact-registry/*`.
- `terraform/aws/*`.
- `app/*` y `model/*`, salvo que una prueba demuestre un defecto real.

### Task 1: Crear el entorno local `ia-artefacto`

**Files:**

- Create: `terraform/envs/ia-artefacto/backend.tf`
- Create: `terraform/envs/ia-artefacto/main.tf`
- Create: `terraform/envs/ia-artefacto/variables.tf`
- Create: `terraform/envs/ia-artefacto/outputs.tf`
- Create: `terraform/envs/ia-artefacto/ia.tfvars.example`

- [ ] **Step 1: Crear `backend.tf`**

```hcl
terraform {
  backend "gcs" {
    prefix = "infra-cloud-template/ia-artefacto"
  }
}
```

- [ ] **Step 2: Crear `variables.tf`**

```hcl
variable "project_id" {
  description = "GCP project id. No default on purpose: never hardcode it."
  type        = string
}

variable "region" {
  description = "GCP region. The course uses us-central1 (Iowa) everywhere."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone inside the region."
  type        = string
  default     = "us-central1-a"
}

variable "servicio_patron_image" {
  description = "Iris inference image in Artifact Registry."
  type        = string
}

variable "app_port" {
  description = "Port exposed by the Iris inference server."
  type        = number
  default     = 8081
}

variable "app_source_ranges" {
  description = "Source ranges allowed to reach the demo endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_artifact_registry" {
  description = "False here because dev owns the shared registry."
  type        = bool
  default     = false
}

variable "enable_vm" {
  description = "Create the CPU inference VM and data disk."
  type        = bool
  default     = true
}

variable "spot" {
  description = "Use a low-cost Spot VM for the class demo."
  type        = bool
  default     = true
}
```

- [ ] **Step 3: Crear `main.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name_prefix             = "infra-cloud-ia"
  artifact_registry_url   = "${var.region}-docker.pkg.dev/${var.project_id}/infra-cloud-template"
}

module "network" {
  source = "../../modules/network"

  name_prefix      = local.name_prefix
  region           = var.region
  app_port         = var.app_port
  app_source_ranges = var.app_source_ranges
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"
  count  = var.enable_artifact_registry ? 1 : 0

  project_id    = var.project_id
  region        = var.region
  repository_id = "infra-cloud-template"
}

resource "google_service_account" "ia" {
  account_id   = "ia-artefacto"
  display_name = "Carga de IA (Clase 2)"
}

resource "google_project_iam_member" "ia_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.ia.email}"
}

module "vm" {
  source = "../../modules/vm"
  count  = var.enable_vm ? 1 : 0

  name                  = "${local.name_prefix}-vm"
  zone                  = var.zone
  environment           = "ia-artefacto"
  subnetwork_id         = module.network.subnetwork_id
  container_name        = "ia-artefacto"
  container_image       = var.servicio_patron_image
  app_port              = var.app_port
  disk_size_gb          = 20
  service_account_email = google_service_account.ia.email
  spot                  = var.spot

  depends_on = [google_project_iam_member.ia_registry_reader]
}
```

- [ ] **Step 4: Crear `outputs.tf`**

```hcl
output "vm_external_ip" {
  description = "External IP of the Iris inference VM."
  value       = var.enable_vm ? module.vm[0].external_ip : null
}

output "vm_url" {
  description = "Base URL of the Iris inference server."
  value       = var.enable_vm ? "http://${module.vm[0].external_ip}:${var.app_port}/" : null
}

output "artifact_registry_url" {
  description = "Shared Artifact Registry prefix."
  value       = local.artifact_registry_url
}

output "ia_service_account_email" {
  description = "Dedicated service account attached to the Iris VM."
  value       = google_service_account.ia.email
}
```

- [ ] **Step 5: Crear `ia.tfvars.example`**

```hcl
project_id            = "my-project-id"
region                = "us-central1"
zone                  = "us-central1-a"
servicio_patron_image = "us-central1-docker.pkg.dev/my-project-id/infra-cloud-template/model:v1"
app_port              = 8081

enable_artifact_registry = false
enable_vm                = true
spot                     = true
```

- [ ] **Step 6: Revisar que el nuevo entorno no contenga artefactos generados**

Run from the repository root:

```powershell
Get-ChildItem -Force terraform\envs\ia-artefacto
```

Expected: only the five source files above; no `.terraform`, `*.tfvars`, `*.plan`, `*.tfstate` or inherited lock.

### Task 2: Preparar Cloud Shell y el registro de evidencia

**Files:**

- Create in Cloud Shell: `$HOME/lab-clase2-20261019/`
- Create in Cloud Shell: `$HOME/lab-clase2-20261019/evidence/session.log`

- [ ] **Step 1: Abrir Cloud Shell desde el proyecto correcto**

Expected: the Cloud Shell prompt is visible under project `project-d9126d04-1cca-424d-8dc`. Authentication prompts remain a manual user step; passwords and verification codes are never captured.

- [ ] **Step 2: Definir el contexto y comprobar que el directorio de trabajo no existe**

```bash
export PROJECT_ID="project-d9126d04-1cca-424d-8dc"
export REGION="us-central1"
export ZONE="us-central1-a"
export BUCKET="${PROJECT_ID}-tfstate"
export AR="${REGION}-docker.pkg.dev/${PROJECT_ID}/infra-cloud-template"
export LAB_ROOT="$HOME/lab-clase2-20261019"
printf 'PROJECT_ID=%s\nREGION=%s\nZONE=%s\nBUCKET=%s\nAR=%s\n' "$PROJECT_ID" "$REGION" "$ZONE" "$BUCKET" "$AR"
test ! -e "$LAB_ROOT"
```

Expected: variables printed and the final command exits successfully. If the directory already exists, inspect it and choose a new dated suffix instead of overwriting it.

- [ ] **Step 3: Descargar una copia reproducible del repositorio público sin usar Git**

```bash
mkdir -p "$LAB_ROOT"
curl -fsSL "https://github.com/kathesama/infra-cloud-unlu-aguirre/archive/refs/heads/main.tar.gz" -o /tmp/infra-cloud-unlu-aguirre-main.tar.gz
tar -xzf /tmp/infra-cloud-unlu-aguirre-main.tar.gz -C "$LAB_ROOT" --strip-components=1
cd "$LAB_ROOT"
pwd
find terraform/modules/network terraform/modules/vm -maxdepth 2 -type f | sort
```

Expected: the final listing contains `main.tf`, `variables.tf`, `outputs.tf`, version files and `startup-script.sh.tpl`. Capture this terminal as Entregable 1.1.

- [ ] **Step 4: Incorporar la carpeta local sanitizada `ia-artefacto`**

Prepare locally a ZIP containing only `terraform/envs/ia-artefacto/*.tf` and `ia.tfvars.example`. Immediately before uploading that ZIP to the authenticated Cloud Shell, request the required upload confirmation. After upload:

```bash
unzip -o "$HOME/ia-artefacto-clase2.zip" -d "$LAB_ROOT"
find terraform/envs/ia-artefacto -maxdepth 1 -type f | sort
```

Expected: the five planned source files, with no real tfvars, state, credentials or AWS files in the upload.

- [ ] **Step 5: Iniciar un transcript de terminal**

```bash
mkdir -p "$LAB_ROOT/evidence"
script -q -a "$LAB_ROOT/evidence/session.log"
```

Expected: `Script started`. Keep the scripted shell open during the cloud workflow and run `exit` only after the final verification.

### Task 3: Renombrar y verificar el proyecto GCP

**Files:**

- Append in Cloud Shell: `evidence/session.log`

- [ ] **Step 1: Activar el proyecto por ID inmutable**

```bash
gcloud config set project "$PROJECT_ID"
gcloud config get-value project
```

Expected: `project-d9126d04-1cca-424d-8dc`.

- [ ] **Step 2: Cambiar el nombre visible**

```bash
gcloud projects update "$PROJECT_ID" --name="unlu-ia-aguirre"
```

Expected: update successful. This does not change the project ID.

- [ ] **Step 3: Verificar el resultado y capturarlo**

```bash
gcloud projects describe "$PROJECT_ID" --format='table(projectId,name,lifecycleState)'
```

Expected: project ID unchanged, name `unlu-ia-aguirre`, state `ACTIVE`.

### Task 4: Credenciales, APIs y backend remoto

**Files:**

- Create in GCP: GCS bucket `project-d9126d04-1cca-424d-8dc-tfstate`

- [ ] **Step 1: Comprobar identidad y Terraform**

```bash
gcloud auth list --filter=status:ACTIVE --format='table(account,status)'
terraform version
```

Expected: the intended account is active and Terraform reports a version >= 1.6. The account column must be hidden in the final report.

- [ ] **Step 2: Crear las credenciales de aplicación**

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project "$PROJECT_ID"
```

Expected: ADC configured for the project. The user completes authentication manually; do not automate or capture passwords, verification codes or consent tokens.

- [ ] **Step 3: Habilitar únicamente las APIs requeridas**

```bash
gcloud services enable compute.googleapis.com artifactregistry.googleapis.com storage.googleapis.com cloudbuild.googleapis.com iam.googleapis.com cloudresourcemanager.googleapis.com --project="$PROJECT_ID"
gcloud services list --enabled --project="$PROJECT_ID" --filter='config.name:(compute.googleapis.com OR artifactregistry.googleapis.com OR storage.googleapis.com OR cloudbuild.googleapis.com OR iam.googleapis.com OR cloudresourcemanager.googleapis.com)' --format='table(config.name)'
```

Expected: all six APIs listed as enabled.

- [ ] **Step 4: Crear el bucket remoto sólo si no existe**

```bash
if gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1; then
  printf 'Bucket existente: gs://%s\n' "$BUCKET"
else
  gcloud storage buckets create "gs://$BUCKET" --project="$PROJECT_ID" --location="$REGION" --uniform-bucket-level-access
fi
gcloud storage buckets update "gs://$BUCKET" --versioning
gcloud storage buckets describe "gs://$BUCKET" --format='yaml(name,location,uniformBucketLevelAccess,versioning_enabled)'
```

Expected: bucket in `US-CENTRAL1`, uniform access enabled and versioning true.

### Task 5: Validar y configurar `dev`

**Files:**

- Create in Cloud Shell: `terraform/envs/dev/dev.tfvars`

- [ ] **Step 1: Crear variables reales fuera de la entrega**

```bash
cd "$LAB_ROOT/terraform/envs/dev"
cp dev.tfvars.example dev.tfvars
sed -i 's/my-project-id/project-d9126d04-1cca-424d-8dc/g' dev.tfvars
cat >> dev.tfvars <<'EOF'
servicio_patron_image     = "us-central1-docker.pkg.dev/project-d9126d04-1cca-424d-8dc/infra-cloud-template/app:v1"
app_port                  = 8080
enable_artifact_registry  = true
enable_vm                 = true
enable_gke                = false
spot                      = true
EOF
grep -v '^#' dev.tfvars | sed '/^[[:space:]]*$/d'
```

Expected: project, region, zone, app image and explicit toggles. No credentials.

- [ ] **Step 2: Formatear y validar antes del backend real**

```bash
cd "$LAB_ROOT"
terraform fmt -recursive -check terraform
terraform -chdir=terraform/envs/dev init -backend=false -input=false
terraform -chdir=terraform/envs/dev validate
```

Expected: format check exits 0 and validation reports `Success! The configuration is valid.`

- [ ] **Step 3: Inicializar el backend real sin migrar estado**

```bash
terraform -chdir=terraform/envs/dev init -reconfigure -backend-config="bucket=$BUCKET" -input=false
terraform -chdir=terraform/envs/dev validate
```

Expected: backend GCS configured and validation successful. Never use `-migrate-state` here.

### Task 6: Crear Artifact Registry y publicar el servicio patrón

**Files:**

- Create in Cloud Shell: `terraform/envs/dev/registry.plan`
- Create in GCP: Artifact Registry repository `infra-cloud-template`
- Create in Artifact Registry: `app:v1`

- [ ] **Step 1: Generar y revisar el plan dirigido**

```bash
terraform -chdir=terraform/envs/dev plan -target=module.artifact_registry -var-file=dev.tfvars -out=registry.plan
terraform -chdir=terraform/envs/dev show -no-color registry.plan | tee "$LAB_ROOT/evidence/2-1-registry-plan.log"
```

Expected: `Plan: 1 to add, 0 to change, 0 to destroy` and only the Docker repository.

- [ ] **Step 2: Aplicar el plan dirigido después de la revisión operativa**

```bash
terraform -chdir=terraform/envs/dev apply registry.plan | tee "$LAB_ROOT/evidence/2-1-registry-apply.log"
```

Expected: `Apply complete! Resources: 1 added, 0 changed, 0 destroyed.` The targeting warning is expected.

- [ ] **Step 3: Descubrir la identidad real de Cloud Build y preparar permisos mínimos**

Immediately before these IAM changes, request the required permission-change confirmation. Then run:

```bash
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
BUILD_SA="$(gcloud builds get-default-service-account --project="$PROJECT_ID")"
printf 'Cloud Build service account: %s\nCompute VM service account: %s\n' "$BUILD_SA" "$COMPUTE_SA"
for ROLE in roles/cloudbuild.builds.builder roles/logging.logWriter; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$BUILD_SA" --role="$ROLE" --condition=None
done
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$COMPUTE_SA" --role="roles/artifactregistry.reader" --condition=None
```

Expected: the default Cloud Build identity is discovered rather than assumed, and three successful role bindings are applied. New projects normally return the Compute Engine default service account, but the command remains valid if Google selects the legacy Cloud Build account. The technical service-account names are valid evidence; hide only the human Google account email.

- [ ] **Step 4: Publicar `app:v1`**

```bash
cd "$LAB_ROOT"
gcloud builds submit ./app --project="$PROJECT_ID" --tag "$AR/app:v1" | tee "$LAB_ROOT/evidence/2-1-app-build.log"
gcloud artifacts docker images list "$AR" --include-tags --filter='package~app' --format='table(package,tags,updateTime)'
```

Expected: Cloud Build `SUCCESS` and `app:v1` listed.

### Task 7: Planear, aplicar y verificar `dev`

**Files:**

- Create in Cloud Shell: `terraform/envs/dev/dev.plan`
- Create in GCP: dev VPC, subnet, three firewall rules, VM and data disk

- [ ] **Step 1: Generar el plan completo**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/dev" plan -var-file=dev.tfvars -out=dev.plan
terraform -chdir="$LAB_ROOT/terraform/envs/dev" show -no-color dev.plan | tee "$LAB_ROOT/evidence/2-1-dev-plan.log"
```

Expected after the registry exists: `Plan: 7 to add, 0 to change, 0 to destroy`; no GKE resources.

- [ ] **Step 2: Revisar costo y alcance antes del primer apply de cómputo**

Confirm the plan contains one Spot `e2-small`, one 10 GB data disk, one 20 GB boot disk, one VPC, one subnet and three firewall rules. Present the summary to the user immediately before applying.

- [ ] **Step 3: Aplicar el plan guardado y capturar la salida**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/dev" apply dev.plan | tee "$LAB_ROOT/evidence/2-1-dev-apply.log"
terraform -chdir="$LAB_ROOT/terraform/envs/dev" output
```

Expected: `Apply complete! Resources: 7 added, 0 changed, 0 destroyed` and a non-empty `vm_external_ip`.

- [ ] **Step 4: Validar el servicio patrón con respuestas completas**

```bash
cd "$LAB_ROOT/terraform/envs/dev"
VM_IP="$(terraform output -raw vm_external_ip)"
printf 'VM_IP=%s\n' "$VM_IP"
curl --retry 30 --retry-delay 5 --retry-all-errors -fsS "http://$VM_IP:8080/healthz"
printf '\n'
curl -fsS "http://$VM_IP:8080/"
printf '\n'
curl -fsS "http://$VM_IP:8080/metrics" | grep '^servicio_patron_'
```

Expected: `{"status":"ok"}`, a persistent visit response and Prometheus metrics. Capture the commands and complete responses.

### Task 8: Provocar, detectar y revertir drift

**Files:**

- Create in Cloud Shell: `terraform/envs/dev/drift.plan`

- [ ] **Step 1: Registrar la configuración declarada actualmente**

```bash
gcloud compute firewall-rules describe infra-cloud-dev-allow-app --project="$PROJECT_ID" --format='yaml(name,sourceRanges,allowed)'
```

Expected: source range `0.0.0.0/0` and TCP 8080.

- [ ] **Step 2: Provocar el drift solicitado**

```bash
gcloud compute firewall-rules update infra-cloud-dev-allow-app --project="$PROJECT_ID" --source-ranges=203.0.113.0/24
gcloud compute firewall-rules describe infra-cloud-dev-allow-app --project="$PROJECT_ID" --format='yaml(name,sourceRanges,allowed)'
```

Expected: source range `203.0.113.0/24`. Capture both the command and the changed value.

- [ ] **Step 3: Detectar el drift con Terraform**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/dev" plan -var-file=dev.tfvars -out=drift.plan
terraform -chdir="$LAB_ROOT/terraform/envs/dev" show -no-color drift.plan | tee "$LAB_ROOT/evidence/3-1-drift-plan.log"
```

Expected: `Plan: 0 to add, 1 to change, 0 to destroy` and `source_ranges` returning to `0.0.0.0/0`.

- [ ] **Step 4: Revertir el drift con el plan guardado**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/dev" apply drift.plan | tee "$LAB_ROOT/evidence/3-1-drift-apply.log"
gcloud compute firewall-rules describe infra-cloud-dev-allow-app --project="$PROJECT_ID" --format='yaml(name,sourceRanges,allowed)'
```

Expected: one resource changed and source range restored to `0.0.0.0/0`.

### Task 9: Validar, publicar y desplegar Iris

**Files:**

- Create in Cloud Shell: `terraform/envs/ia-artefacto/ia.tfvars`
- Create in Cloud Shell: `terraform/envs/ia-artefacto/ia.plan`
- Create in Artifact Registry: `model:v1`
- Create in GCP: IA VPC, subnet, firewall rules, service account, IAM membership, VM and disk

- [ ] **Step 1: Crear variables reales de Iris**

```bash
cd "$LAB_ROOT/terraform/envs/ia-artefacto"
cp ia.tfvars.example ia.tfvars
sed -i 's/my-project-id/project-d9126d04-1cca-424d-8dc/g' ia.tfvars
grep -v '^#' ia.tfvars | sed '/^[[:space:]]*$/d'
```

Expected: model image `model:v1`, port 8081, registry false, VM true and Spot true.

- [ ] **Step 2: Formatear y validar el entorno nuevo**

```bash
cd "$LAB_ROOT"
terraform fmt -recursive -check terraform/envs/ia-artefacto
terraform -chdir=terraform/envs/ia-artefacto init -backend=false -input=false
terraform -chdir=terraform/envs/ia-artefacto validate
```

Expected: format check exits 0 and validation is successful.

- [ ] **Step 3: Publicar `model:v1`**

```bash
cd "$LAB_ROOT"
gcloud builds submit ./model --project="$PROJECT_ID" --tag "$AR/model:v1" | tee "$LAB_ROOT/evidence/4-1-model-build.log"
gcloud artifacts docker images list "$AR" --include-tags --filter='package~model' --format='table(package,tags,updateTime)'
```

Expected: Cloud Build `SUCCESS` and `model:v1` listed.

- [ ] **Step 4: Inicializar el backend aislado**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" init -reconfigure -backend-config="bucket=$BUCKET" -input=false
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" validate
```

Expected: GCS backend configured with the `ia-artefacto` prefix. Never accept state migration from `dev`.

- [ ] **Step 5: Generar y revisar el plan de Iris**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" plan -var-file=ia.tfvars -out=ia.plan
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" show -no-color ia.plan | tee "$LAB_ROOT/evidence/4-1-ia-plan.log"
```

Expected: `Plan: 9 to add, 0 to change, 0 to destroy`, no resources named `infra-cloud-dev` and no Artifact Registry repository creation.

- [ ] **Step 6: Aplicar el plan después de revisar el cambio IAM y el costo**

Immediately before applying, confirm the exact IAM grant and resource creation. Then run:

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" apply ia.plan | tee "$LAB_ROOT/evidence/4-1-ia-apply.log"
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" output
```

Expected: `Apply complete! Resources: 9 added, 0 changed, 0 destroyed`, an IP and the dedicated service account output.

- [ ] **Step 7: Validar salud, descripción, predicción y métricas**

```bash
cd "$LAB_ROOT/terraform/envs/ia-artefacto"
IA_IP="$(terraform output -raw vm_external_ip)"
printf 'IA_IP=%s\n' "$IA_IP"
curl --retry 30 --retry-delay 5 --retry-all-errors -fsS "http://$IA_IP:8081/healthz"
printf '\n'
curl -fsS "http://$IA_IP:8081/"
printf '\n'
curl -fsS -X POST "http://$IA_IP:8081/predict" -H 'content-type: application/json' -d '{"features":[5.1,3.5,1.4,0.2]}'
printf '\n'
curl -fsS "http://$IA_IP:8081/metrics" | grep '^model_'
```

Expected: health `ok`, endpoint description, class `setosa` with a confidence between 0 and 1, and `model_predictions_total` >= 1.

### Task 10: Preparar y aplicar el cleanup

**Files:**

- Create in Cloud Shell: `terraform/envs/ia-artefacto/ia-destroy.plan`
- Create in Cloud Shell: `terraform/envs/dev/dev-destroy.plan`

- [ ] **Step 1: Guardar evidencia antes de destruir**

```bash
cd "$LAB_ROOT"
find evidence -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
terraform -chdir=terraform/envs/ia-artefacto output
terraform -chdir=terraform/envs/dev output
```

Expected: all required logs exist and both environments still have readable outputs.

- [ ] **Step 2: Generar los dos planes de destrucción**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" plan -destroy -var-file=ia.tfvars -out=ia-destroy.plan
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" show -no-color ia-destroy.plan | tee "$LAB_ROOT/evidence/5-1-ia-destroy-plan.log"
terraform -chdir="$LAB_ROOT/terraform/envs/dev" plan -destroy -var-file=dev.tfvars -out=dev-destroy.plan
terraform -chdir="$LAB_ROOT/terraform/envs/dev" show -no-color dev-destroy.plan | tee "$LAB_ROOT/evidence/5-1-dev-destroy-plan.log"
```

Expected: IA proposes 9 destroys; dev proposes 8 destroys including the registry created earlier. Neither plan deletes the GCS state bucket.

- [ ] **Step 3: Confirmar la eliminación exacta inmediatamente antes del cleanup**

Present both destroy summaries and explain that the IA VM/disk/network/service account/IAM and the dev VM/disk/network/registry will be removed, while the state bucket remains.

- [ ] **Step 4: Destruir primero Iris y después dev usando los planes revisados**

```bash
terraform -chdir="$LAB_ROOT/terraform/envs/ia-artefacto" apply ia-destroy.plan | tee "$LAB_ROOT/evidence/5-1-ia-destroy-apply.log"
terraform -chdir="$LAB_ROOT/terraform/envs/dev" apply dev-destroy.plan | tee "$LAB_ROOT/evidence/5-1-dev-destroy-apply.log"
```

Expected: IA reports 9 destroyed and dev reports 8 destroyed.

- [ ] **Step 5: Verificar que no quedan recursos costosos**

```bash
gcloud compute instances list --project="$PROJECT_ID"
gcloud compute disks list --project="$PROJECT_ID"
gcloud artifacts repositories list --project="$PROJECT_ID" --location="$REGION"
gcloud storage buckets describe "gs://$BUCKET" --format='yaml(name,location,versioning_enabled)'
```

Expected: no VMs, no persistent disks, no Artifact Registry repository and the versioned state bucket present.

- [ ] **Step 6: Cerrar y empaquetar el transcript**

```bash
exit
cd "$LAB_ROOT"
tar -czf "$HOME/lab-clase2-evidence.tar.gz" evidence terraform/envs/ia-artefacto terraform/envs/dev/dev.tfvars
ls -lh "$HOME/lab-clase2-evidence.tar.gz"
```

Expected: a non-empty archive. Downloading the archive to the local workspace is an inbound transfer and does not require confirmation.

### Task 11: Construir y verificar la entrega

**Files:**

- Create: `docs/lab-clase-2-gcp.md`
- Create: `docs/entrega/Lab-Clase-2-Terraform-GCP-Katherine-Aguirre.docx`
- Create: `docs/entrega/Lab-Clase-2-Terraform-GCP-Katherine-Aguirre.pdf`

- [ ] **Step 1: Copiar y sanitizar evidencias**

Extract the downloaded evidence archive into a temporary local folder. Remove the Google account email, billing account identifiers, auth URLs and tokens from report images and text. Keep the project ID, resource names, plan counts, public demo IPs and service account resource name when technically necessary.

- [ ] **Step 2: Escribir la bitácora técnica**

`docs/lab-clase-2-gcp.md` must record actual commands, outputs, resource counts, errors and resolutions. Do not copy expected results from this plan as if they occurred; replace them with verified runtime evidence.

- [ ] **Step 3: Crear el informe editable y el PDF**

Use this order:

1. Portada y contexto GCP.
2. Entregable 1.1: backend y estructura.
3. Entregable 2.1: apply y servicio patrón.
4. Entregable 3.1: drift y reversión.
5. Entregable 4.1: Iris CPU, código, apply, predicción y justificación.
6. Entregable 5.1: cleanup verificado.
7. Anexo breve con el código de `ia-artefacto`.

Every screenshot must show the complete command and enough output to prove the result. Captions distinguish command evidence, console status and explanatory text.

- [ ] **Step 4: Validar DOCX y PDF**

Compile/export the DOCX to PDF, render every PDF page to images and inspect the contact sheet plus pages containing code and terminal evidence. Acceptance checks:

- no clipped commands or output;
- readable monospace text;
- consistent deliverable numbering 1.1 through 5.1;
- no residual AWS wording presented as the current execution;
- no email, payment data, token or authentication URL;
- active hyperlinks preserved where included;
- PDF and DOCX contain the same final content.

- [ ] **Step 5: Final verification**

Run only the permitted repository checks required for verification:

```powershell
git diff -- docs/superpowers/specs/2026-10-19-lab-clase-2-gcp-terraform-design.md docs/superpowers/plans/2026-10-19-lab-clase-2-gcp-terraform.md terraform/envs/ia-artefacto docs/lab-clase-2-gcp.md
```

Expected: only the intended GCP lab files. Do not run commit, add, branch, pull, push or create a pull request.
