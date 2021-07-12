# Locate Kubernetes cluster in VPC
data "ibm_container_vpc_cluster" "cluster" {
  name = var.iks_cluster_name
}

# Bind the App ID service to the cluster
resource "ibm_container_bind_service" "bind_appid" {
  cluster_name_id     = data.ibm_container_vpc_cluster.cluster.id
  service_instance_id = ibm_resource_instance.app_id.guid
  resource_group_id   = data.ibm_resource_group.cloud_development.id
  key                 = ibm_resource_key.RKappid.name
  namespace_id        = kubernetes_namespace.namespace.metadata.0.name
}

resource "ibm_container_addons" "addons" {
  cluster = data.ibm_container_vpc_cluster.cluster.name
  addons {
    name    = "alb-oauth-proxy"
    version = "1.0.0"
  }
}

# Download the cluster configuration...
data "ibm_container_cluster_config" "mycluster" {
  cluster_name_id = data.ibm_container_vpc_cluster.cluster.name
}

# ... and apply it to configure the Kubernetes provider
provider "kubernetes" {
  load_config_file       = "false"
  host                   = data.ibm_container_cluster_config.mycluster.host
  token                  = data.ibm_container_cluster_config.mycluster.token
  cluster_ca_certificate = data.ibm_container_cluster_config.mycluster.ca_certificate
}

# Kubernetes namespace, needed to bind App ID
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.iks_namespace
  }
}