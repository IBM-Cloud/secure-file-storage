# Retrieve the account ID to be used in the CBR objects
data "ibm_iam_account_settings" "team_iam_account_settings" {
}

# Locate Kubernetes cluster in VPC
data "ibm_container_vpc_cluster" "cluster" {
  name = var.iks_cluster_name
}
