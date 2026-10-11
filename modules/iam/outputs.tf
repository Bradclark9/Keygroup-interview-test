output "gke_nodes_sa_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_nodes.email
}

output "gke_nodes_sa_name" {
  description = "Fully qualified name of the GKE node service account"
  value       = google_service_account.gke_nodes.name
}

output "file_service_sa_email" {
  description = "Workload Identity SA for the file retrieval service"
  value       = google_service_account.file_service.email
}
