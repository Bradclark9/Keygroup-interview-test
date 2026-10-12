variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary region for subnets"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for network resource names"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for GKE pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range for GKE services"
  type        = string
  default     = "10.8.0.0/20"
}

variable "enable_nat" {
  description = "Create Cloud NAT for private node egress"
  type        = bool
  default     = true
}
