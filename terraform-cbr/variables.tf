variable "ibmcloud_api_key" {}

variable "basename" {
  description = "Prefix for named resources"
  default     = "secure-file-storage"
}

variable "region" {
  description = "The region to deploy to, e.g., us-south, eu-de, etc."
  default     = "us-south"
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