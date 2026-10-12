resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE node service account (${var.name_prefix})"
}

resource "google_service_account" "file_service" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-file-svc"
  display_name = "File retrieval workload identity SA (${var.name_prefix})"
}

locals {
  node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset(local.node_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Allow the Kubernetes SA in namespace keygroup to impersonate this GSA
resource "google_service_account_iam_member" "file_service_wi" {
  service_account_id = google_service_account.file_service.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[keygroup/file-service]"
}
