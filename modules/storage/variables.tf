variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "location" {
  type    = string
  default = "EUROPE-WEST2"
}

variable "bucket_name" {
  description = "Optional explicit bucket name; defaults to name_prefix-customer-files"
  type        = string
  default     = null
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "reader_members" {
  description = "IAM members granted objectViewer on the bucket, keyed by a static name"
  type        = map(string)
  default     = {}
}
