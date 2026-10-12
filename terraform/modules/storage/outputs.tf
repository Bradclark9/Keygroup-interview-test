output "bucket_name" {
  value = google_storage_bucket.customer_files.name
}

output "bucket_url" {
  value = google_storage_bucket.customer_files.url
}
