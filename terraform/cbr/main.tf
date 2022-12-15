# Retrieve the account ID to be used in the CBR objects
data "ibm_iam_account_settings" "team_iam_account_settings" {
}

# retrieve the VPC information
data "ibm_is_vpc" "vpc" {
  name = var.vpcname
}

# Locate Kubernetes cluster in VPC
data "ibm_container_vpc_cluster" "cluster" {
  name = var.iks_cluster_name
}
