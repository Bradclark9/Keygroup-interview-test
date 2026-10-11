output "network_id" {
  description = "VPC network self link / ID"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "GKE subnet ID"
  value       = google_compute_subnetwork.gke.id
}

output "subnet_name" {
  description = "GKE subnet name"
  value       = google_compute_subnetwork.gke.name
}

output "pods_range_name" {
  description = "Secondary range name for pods"
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary range name for services"
  value       = "services"
}
