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
