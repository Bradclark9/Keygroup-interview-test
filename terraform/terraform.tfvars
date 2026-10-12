# prod environment, running on the floci-gcp emulator (auto-loaded by terraform; used by make up)
project_id  = "keygroup-prod"
region      = "us-central1"
name_prefix = "kg-prod"

# Send every google provider API call to floci-gcp
emulator_endpoint = "http://localhost:4588"

subnet_cidr   = "10.70.0.0/20"
pods_cidr     = "10.80.0.0/14"
services_cidr = "10.84.0.0/20"

machine_type        = "e2-standard-4"
min_node_count      = 1
max_node_count      = 3
preemptible         = false
deletion_protection = true # make down removes the emulator, not via terraform destroy

# Not emulated by floci-gcp
enable_artifact_registry = false
enable_nat               = false

labels = {
  environment = "prod"
  managed_by  = "terraform"
}
