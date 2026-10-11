variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for the Artifact Registry repository"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for the repository name"
  type        = string
}

variable "repository_id" {
  description = "Repository ID (defaults to name_prefix-containers)"
  type        = string
  default     = null
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Container images for GKE workloads"
}

variable "format" {
  description = "Artifact Registry format"
  type        = string
  default     = "DOCKER"
}

variable "labels" {
  description = "Labels for the repository"
  type        = map(string)
  default     = {}
}
