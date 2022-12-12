variable "basename" {
  description = "Prefix for named resources"
  default     = "secure-file-storage"
}

variable "region" {
  description = "The region to deploy to, e.g., us-south, eu-de, etc."
  default     = "us-south"
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

variable "ibmcloud_api_key" {}

variable "vpcname" {
  default = "vpc-sec"
}


# deploy the CBR objects? By default false
variable "deploy_cbr" {
  default = false
}