# variable "tags" {
#     type=list(string)
# }
variable "region" {}

variable "iks_cluster_name" {
}

variable "iks_namespace" {
}

variable "resource_group" {
}

# variable "cos_endpoint" {
#   default = "s3.direct.us-south.cloud-object-storage.appdomain.cloud"
# }

# variable "cos_ibmAuthEndpoint" {
#   default = "https://iam.cloud.ibm.com/oidc/token"
# }

variable "basename" {
}

variable "ibmcloud_timeout" {
  description = "Timeout for API operations in seconds."
  default     = 900
}