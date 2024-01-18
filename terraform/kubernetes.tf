# Locate Kubernetes cluster in VPC
data "ibm_container_vpc_cluster" "cluster" {
  name = var.iks_cluster_name
}
# Download the cluster configuration...
data "ibm_container_cluster_config" "mycluster" {
  cluster_name_id = data.ibm_container_vpc_cluster.cluster.name
}

# ... and apply it to configure the Kubernetes provider
provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.mycluster.host
  token                  = data.ibm_container_cluster_config.mycluster.token
  cluster_ca_certificate = data.ibm_container_cluster_config.mycluster.ca_certificate
}


data "kubernetes_namespace" "namespace" {
  count = var.iks_namespace == "default" ? 1 : 0
  metadata {
    name = var.iks_namespace
  }
}

# Kubernetes namespace, needed to bind App ID
resource "kubernetes_namespace" "namespace" {
  count = var.iks_namespace == "default" ? 0 : 1
  metadata {
    name = var.iks_namespace
  }
}

locals {
  kubernetes_namespace = var.iks_namespace == "default" ? data.kubernetes_namespace.namespace.0.metadata.0.name : kubernetes_namespace.namespace.0.metadata.0.name
}

/* resource "kubernetes_config_map_v1_data" "ibm_k8s_controller_config" {
  metadata {
    name      = "ibm-k8s-controller-config"
    namespace = "kube-system"
  }
  data = {
    allow-snippet-annotations = "true"
  }
  force = "true"
}
 */