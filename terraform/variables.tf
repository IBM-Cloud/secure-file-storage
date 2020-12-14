variable "basename" {
  description = "Prefix for named resources, e.g., secure-file-storage"
}

variable "region" {
  description = "The region to deploy to, e.g., us-south, eu-de, etc."
}

variable "iks_cluster_name" {
  description = "Name of the existing Kubernetes cluster to deploy into"
}

variable "iks_namespace" {
  description = "Name of the namespace in the cluster to deploy into. It will be created if not present."
}

variable "resource_group" {
  description = "Name of the existing resource group to deploy into."
}

variable "ibmcloud_timeout" {
  description = "Timeout for API operations in seconds."
  default     = 900
}

variable "appid_plan" {
  description = "Service plan to be used for App ID"
  default = "graduated-tier"
}

variable "cloudant_plan" {
  description = "Service plan to be used for Cloudant"
  default = "lite"
}

variable "cos_plan" {
  description = "Service plan to be used for Cloud Object Storage"
  default = "standard"
}

variable "kp_plan" {
  description = "Service plan to be used for Key Protect"
  default = "tiered-pricing"
}
