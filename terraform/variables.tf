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

# variables for the toolchain

#variable "IC_SCHEMATICS_WORKSPACE_ID" {
#  description = "ID of this Schematics workspace, filled automatically, LEAVE EMPTY"
#}

variable "toolchain_registry_namespace" {
  description = "namespace in the Container Registry to store the container image"
}

variable "toolchain_registry_region" {
  description = "region of the Container Registry"
  default = "ibm:yp:us-south"
}

variable "toolchain_image_name" {
  description = "name of the container image"
  default = "secure-file-storage"
}

variable "toolchain_git_repository" {
  description = "repository with app source code"
  default = "https://github.com/IBM-Cloud/secure-file-storage"
}

variable "toolchain_git_branch" {
  description = "branch with app source code"
  default = "master"
}

variable "toolchain_apikey" {
  description = "IBM Cloud API key to build and deploy the app"
  default = ""
  sensitive = true
}