terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }

  # State lives in the floci-gcp emulator's own GCS (bucket created by `make floci-start`)
  backend "gcs" {
    bucket                  = "floci-tfstate"
    prefix                  = "gke"
    storage_custom_endpoint = "http://localhost:4588/storage/v1/"
    access_token            = "floci"
  }
}

locals {
  emulated = var.emulator_endpoint != ""
}

provider "google" {
  project = var.project_id
  region  = var.region

  # When emulator_endpoint is set (vars/floci.tfvars) every API goes to floci-gcp;
  # null keeps the provider defaults for real GCP.
  access_token                     = local.emulated ? "floci" : null
  compute_custom_endpoint          = local.emulated ? "${var.emulator_endpoint}/compute/v1/" : null
  container_custom_endpoint        = local.emulated ? "${var.emulator_endpoint}/container/" : null
  iam_custom_endpoint              = local.emulated ? "${var.emulator_endpoint}/" : null
  resource_manager_custom_endpoint = local.emulated ? "${var.emulator_endpoint}/" : null
  service_usage_custom_endpoint    = local.emulated ? "${var.emulator_endpoint}/" : null
  storage_custom_endpoint          = local.emulated ? "${var.emulator_endpoint}/storage/v1/" : null
}
