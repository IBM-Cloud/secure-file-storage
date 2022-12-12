
module "cbr_objects" {
  count             = var.deploy_cbr ? 1 : 0
  source            = "./cbr"
  basename          = var.basename
  region            = var.region
  vpcname = var.vpcname
  iks_cluster_name = var.iks_cluster_name
  cos = ibm_resource_instance.cos
  keyprotect = ibm_resource_instance.keyprotect
}