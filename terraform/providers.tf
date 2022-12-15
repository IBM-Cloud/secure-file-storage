terraform {
  required_version = ">= 0.13"
  required_providers {
    ibm = {
      source  = "ibm-cloud/ibm"
      version = ">=1.47.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.11.0"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

provider "ibm" {
  #   ibmcloud_api_key = var.ibmcloud_api_key / Schematics
  region           = var.region
  ibmcloud_timeout = var.ibmcloud_timeout
}
