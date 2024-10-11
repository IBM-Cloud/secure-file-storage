# CBR objects are integrated as optional module
module "cbr_objects" {
  count                        = var.deploy_cbr ? 1 : 0
  source                       = "./cbr"
  iks_cluster_name             = var.iks_cluster_name
  cbr_enforcement_mode         = var.cbr_enforcement_mode
  cos                          = ibm_resource_instance.cos
  keyprotect                   = ibm_resource_instance.keyprotect
  cbr_homezone_iprange         = var.cbr_homezone_iprange
  toolchain_registry_namespace = var.toolchain_registry_namespace
}
