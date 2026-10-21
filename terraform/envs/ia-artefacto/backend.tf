terraform {
  backend "gcs" {
    prefix = "infra-cloud-template/ia-artefacto"
  }
}
