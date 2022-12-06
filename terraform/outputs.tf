output "vpc" {
  value = data.ibm_is_vpc.vpc
  sensitive = true
}

output "cluster" {
  value = data.ibm_container_vpc_cluster.cluster
  sensitive = true
}

output "cos" {
  # one of the arguments is non-empty
  value = try(ibm_resource_instance.cos[0],data.ibm_resource_instance.data_cos[0])
  sensitive = true
}

output "appid" {
    # one of the arguments is non-empty
    value = try(ibm_resource_instance.app_id[0],data.ibm_resource_instance.data_app_id[0])
    sensitive = true
}

output "keyprotect" {
  # one of the arguments is non-empty
  value = try(ibm_resource_instance.keyprotect[0],data.ibm_resource_instance.data_keyprotect[0])
  sensitive = true
}
