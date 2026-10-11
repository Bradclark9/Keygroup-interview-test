locals {
  repository_id = coalesce(var.repository_id, "${var.name_prefix}-containers")
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = local.repository_id
  description   = var.description
  format        = var.format
  labels        = var.labels
}
