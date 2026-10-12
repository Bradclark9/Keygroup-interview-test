locals {
  bucket_name = coalesce(var.bucket_name, "${var.name_prefix}-customer-files")
}

resource "google_storage_bucket" "customer_files" {
  project                     = var.project_id
  name                        = local.bucket_name
  location                    = var.location
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
  }
}

resource "google_storage_bucket_iam_member" "readers" {
  for_each = var.reader_members

  bucket = google_storage_bucket.customer_files.name
  role   = "roles/storage.objectViewer"
  member = each.value
}
