# CBR objects are integrated as optional module
module "cbr_objects" {
  count            = var.deploy_cbr ? 1 : 0
  source           = "./cbr"
  vpcname          = var.vpcname
  iks_cluster_name = var.iks_cluster_name
  enforcement_mode = var.enforcement_mode
  cos              = ibm_resource_instance.cos
  keyprotect       = ibm_resource_instance.keyprotect
  homezone_iprange = var.homezone_iprange
}
