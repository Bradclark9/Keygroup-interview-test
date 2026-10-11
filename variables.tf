variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "europe-west2"
}

variable "name_prefix" {
  description = "Shared name prefix for resources"
  type        = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.20.0.0/14"
}

variable "services_cidr" {
  type    = string
  default = "10.24.0.0/20"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 3
}

variable "preemptible" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "master_authorized_cidrs" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "enable_artifact_registry" {
  description = "Create the Artifact Registry repo (disable for emulators that lack it, e.g. floci-gcp)"
  type        = bool
  default     = true
}

variable "enable_nat" {
  description = "Create Cloud Router + NAT for private nodes (disable for floci-gcp, which lacks routers)"
  type        = bool
  default     = true
}

variable "emulator_endpoint" {
  description = "Base URL of a GCP API emulator (floci-gcp). Empty = real GCP."
  type        = string
  default     = ""
}
