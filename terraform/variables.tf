variable "basename" {
  description = "Prefix for named resources"
  default     = "secure-file-storage"
}

variable "region" {
  description = "The region to deploy to, e.g., us-south, eu-de, etc."
  default     = "us-south"
}

variable "vpcname" {
  description = "Name of the existing VPC with the Kubernetes cluster"
}

variable "iks_cluster_name" {
  description = "Name of the existing Kubernetes cluster to deploy into"
  default     = "secure-file-storage-cluster"
}

variable "iks_namespace" {
  description = "Name of the namespace in the cluster to deploy into. It will be created if not present."
  default     = "default"
}

variable "resource_group" {
  description = "Name of the existing resource group to deploy into."
  default     = "default"
}

variable "ibmcloud_timeout" {
  description = "Timeout for API operations in seconds."
  default     = 900
}

variable "appid_plan" {
  description = "Service plan to be used for App ID"
  default     = "graduated-tier"
}

variable "cloudant_plan" {
  description = "Service plan to be used for Cloudant"
  default     = "lite"
}

variable "cos_plan" {
  description = "Service plan to be used for Cloud Object Storage"
  default     = "standard"
}

variable "kp_plan" {
  description = "Service plan to be used for Key Protect"
  default     = "tiered-pricing"
}

# ----------------------------------------
# Variables for context-based restrictions
# ----------------------------------------

# deploy the CBR objects? By default false
variable "deploy_cbr" {
  default = false
}

# configure the enforcement mode for CBR
variable "cbr_enforcement_mode" {
  default = "report"
}

# define a homezone or bastion zone
# change the setting in tfvars
variable "homezone_iprange" {
  default = "0.0.0.0-255.255.255.255"
}