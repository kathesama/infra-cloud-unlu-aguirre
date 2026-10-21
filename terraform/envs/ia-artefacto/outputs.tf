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
