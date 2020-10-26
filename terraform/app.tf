# template for container registry secrets
data "template_file" "docker_config_script" {
  template = file("${path.module}/docker_config.json")
  vars = {
    docker-username = "iamapikey"
    docker-password = var.ibmcloud_api_key
    docker-server   = var.docker-server
    docker-email    = var.docker-email
    auth            = base64encode("iamapikey:${var.ibmcloud_api_key}")
  }
}

# Create secrets to access IBM Container Registry to pull container image
resource "kubernetes_secret" "registry_secrets" {
  metadata {
    name      = "${var.basename}-docker-registry"
    namespace = var.iks_namespace
  }

  data = {
    ".dockerconfigjson" = data.template_file.docker_config_script.rendered
  }

  type = "kubernetes.io/dockerconfigjson"
}


# Kubernetes service for secure-file-storage app
resource "kubernetes_service" "sfs_service" {
  metadata {
    name      = "secure-file-storage-service"
    namespace = var.iks_namespace
  }
  spec {
    selector = {
      app = "secure-file-storage"
    }
    port {
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# Deployment definition based on the Docker container build
resource "kubernetes_deployment" "sfs_deployment" {
  metadata {
    name      = "secure-file-storage-deployment"
    namespace = var.iks_namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "secure-file-storage"
      }
    }
    template {
      metadata {
        labels = {
          app = "secure-file-storage"
        }
      }
      spec {
        image_pull_secrets {
          name = "sfstest-docker-registry"
        }
        container {
          name              = "secure-file-storage-container"
          image             = "${var.docker-server}${var.imageURIpath}"
          image_pull_policy = "Always"
          port {
            container_port = 8081
          }
          env_from {
            secret_ref {
              name = "sfstest-credentials"
            }
          }
        }
      }
    }
  }
}

# Ingress definition referencing App ID
resource "kubernetes_ingress" "sfs_ingress" {
  metadata {
    name      = "ingress-for-secure-file-storage"
    namespace = var.iks_namespace
    annotations = {
      "ingress.bluemix.net/appid-auth"           = "bindSecret=binding-sfstest-appid namespace=prod requestType=web serviceName=secure-file-storage-service"
      "ingress.bluemix.net/client-max-body-size" = "50m"
    }
  }

  spec {
    rule {
      host = "secure-file-storage.${ibm_container_vpc_cluster.cluster.ingress_hostname}"
      http {
        path {
          backend {
            service_name = "secure-file-storage-service"
            service_port = 8081
          }

          path = "/"
        }
      }
    }

    tls {
      hosts       = ["secure-file-storage.${ibm_container_vpc_cluster.cluster.ingress_hostname}"]
      secret_name = ibm_container_vpc_cluster.cluster.ingress_secret
    }
  }
}