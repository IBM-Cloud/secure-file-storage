# configure the enforcement mode for CBR
variable "cbr_enforcement_mode" {
  default = "report"
}

# define a homezone or bastion zone
# change the setting in tfvars
variable "homezone_iprange" {
  default = "0.0.0.0-255.255.255.255"
}

variable "iks_cluster_name" {
  description = "Name of the existing Kubernetes cluster to deploy into"
  default     = "secure-file-storage-cluster"
}

# Variables to hold information about resource instances
variable "cos" {
}

variable "keyprotect" {
}