module "project_services" {
  source = "./modules/project-services"

  project_id = var.project_id
}

module "network" {
  source = "./modules/network"

  project_id    = var.project_id
  region        = var.region
  name_prefix   = var.name_prefix
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
  enable_nat    = var.enable_nat

  depends_on = [module.project_services]
}

module "iam" {
  source = "./modules/iam"

  project_id  = var.project_id
  name_prefix = var.name_prefix

  depends_on = [module.project_services]
}

module "artifact_registry" {
  source = "./modules/artifact-registry"
  count  = var.enable_artifact_registry ? 1 : 0

  project_id  = var.project_id
  region      = var.region
  name_prefix = var.name_prefix
  labels      = var.labels

  depends_on = [module.project_services]
}

moved {
  from = module.artifact_registry
  to   = module.artifact_registry[0]
}

module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  name_prefix = var.name_prefix
  location    = upper(var.region)
  labels      = var.labels
  reader_members = {
    file_service = "serviceAccount:${module.iam.file_service_sa_email}"
  }

  depends_on = [module.project_services]
}

module "gke" {
  source = "./modules/gke"

  project_id              = var.project_id
  region                  = var.region
  name_prefix             = var.name_prefix
  network                 = module.network.network_name
  subnetwork              = module.network.subnet_name
  pods_range_name         = module.network.pods_range_name
  services_range_name     = module.network.services_range_name
  node_service_account    = module.iam.gke_nodes_sa_email
  machine_type            = var.machine_type
  min_node_count          = var.min_node_count
  max_node_count          = var.max_node_count
  preemptible             = var.preemptible
  deletion_protection     = var.deletion_protection
  master_authorized_cidrs = var.master_authorized_cidrs
  labels                  = var.labels

  depends_on = [
    module.network,
    module.iam,
  ]
}
