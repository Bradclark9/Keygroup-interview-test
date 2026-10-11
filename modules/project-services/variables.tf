variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "services" {
  description = "APIs to enable"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "servicenetworking.googleapis.com",
    "storage.googleapis.com",
  ]
}

variable "disable_on_destroy" {
  description = "Disable APIs when the resource is destroyed"
  type        = bool
  default     = false
}
