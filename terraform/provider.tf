terraform {
  required_version = ">= 0.12"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~>1.14"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

provider "ibm" {
  #ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  ibmcloud_timeout = var.ibmcloud_timeout
}
