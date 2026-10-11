output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_location" {
  value = module.gke.location
}

output "network_name" {
  value = module.network.network_name
}

output "artifact_registry_url" {
  value = one(module.artifact_registry[*].repository_url)
}

output "gke_nodes_sa_email" {
  value = module.iam.gke_nodes_sa_email
}

output "file_service_sa_email" {
  value = module.iam.file_service_sa_email
}

output "customer_files_bucket" {
  value = module.storage.bucket_name
}
