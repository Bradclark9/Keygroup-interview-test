output "repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Fully qualified repository name"
  value       = google_artifact_registry_repository.this.name
}

output "repository_url" {
  description = "Docker push/pull host path"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
