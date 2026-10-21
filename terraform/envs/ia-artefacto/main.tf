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
  name_prefix           = "infra-cloud-ia"
  artifact_registry_url = "${var.region}-docker.pkg.dev/${var.project_id}/infra-cloud-template"
}

module "network" {
  source = "../../modules/network"

  name_prefix       = local.name_prefix
  region            = var.region
  app_port          = var.app_port
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
