
variable "ibmcloud_api_key" {}
variable "tags" {}
variable "region" {}

variable "basename" {
  default = "cloud"
}

variable "iks_namespace" {
  default = "prod"
}

variable "iks_machine_type" {
  default = "bx2.4x16"
}

variable "iks_worker_count" {
  default = 1
}

variable "iks_version" {
  default = "1.17.11"
}

variable "iks_wait_till" {
  default = "OneWorkerNodeReady"
}

variable "ibmcloud_timeout" {
  description = "Timeout for API operations in seconds."
  default     = 900
}

variable "cos_endpoint" {
  default = "s3.direct.us-south.cloud-object-storage.appdomain.cloud"
}

variable "cos_ibmAuthEndpoint" {
  default = "https://iam.cloud.ibm.com/oidc/token"
}

variable "cidr_blocks" {
  default=["10.40.10.0/24", "10.40.11.0/24", "10.40.12.0/24"]
}

variable "imageURI" {
  default = "us.icr.io/henrik/secure-file-storage:latest"
}

variable "docker-server" {
  default = "us.icr.io"
}

variable "docker-email" {
  default = "example@example.com"
}

variable "imageURIpath" {
  default = "/henrik/secure-file-storage:latest"
}
