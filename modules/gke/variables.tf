variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for the regional GKE cluster"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for cluster and node pool names"
  type        = string
}

variable "network" {
  description = "VPC network name or self link"
  type        = string
}

variable "subnetwork" {
  description = "Subnet name or self link"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
}

variable "node_service_account" {
  description = "Email of the node service account"
  type        = string
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "kubernetes_version" {
  description = "Optional exact Kubernetes version (empty = channel default)"
  type        = string
  default     = null
}

variable "enable_private_nodes" {
  description = "Use private nodes (no public IPs)"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Make the control plane endpoint private-only"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for the private control plane (/28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to reach the public control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion"
  type        = bool
  default     = true
}

variable "node_count" {
  description = "Initial / fixed node count per zone (used when autoscaling is off)"
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable node pool autoscaling"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum nodes per zone when autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum nodes per zone when autoscaling"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "preemptible" {
  description = "Use preemptible / Spot VMs"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels applied to the cluster and nodes"
  type        = map(string)
  default     = {}
}
