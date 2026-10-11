output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.this.id
}

output "endpoint" {
  description = "Cluster API endpoint"
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "Cluster CA certificate (base64)"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "Cluster location (region)"
  value       = google_container_cluster.this.location
}

output "node_pool_name" {
  description = "Primary node pool name"
  value       = google_container_node_pool.primary.name
}
