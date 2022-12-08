# CBR rules
# See https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cbr_rule
# for the syntax and the following link for supported services:
# https://cloud.ibm.com/docs/account?topic=account-context-restrictions-whatis#cbr-adopters
# The rules cover resources from the mentioned tutorial.

# COS access
resource "ibm_cbr_rule" "cbr_rule_cos_vpc" {
  contexts {
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_k8s.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_groups.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_users.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_homezone.id
    }

  }

  description      = "restrict COS access, limit to cluster"
  enforcement_mode = var.cbr_enforcement_mode
  resources {
    attributes {
      name  = "accountId"
      value = data.ibm_iam_account_settings.team_iam_account_settings.account_id
    }
    attributes {
      name     = "serviceInstance"
      operator = "stringEquals"
      value    = data.terraform_remote_state.e2e-resources.outputs.cos.guid
    }
    attributes {
      name     = "serviceName"
      operator = "stringEquals"
      value    = "cloud-object-storage"
    }

  }
}

# Access to the Container Registry and a specific namespace
resource "ibm_cbr_rule" "cbr_rule_registry" {
  contexts {
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_k8s.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_groups.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_users.id
    }

  }

  description      = "restrict access to registry, limit to cluster"
  enforcement_mode = var.cbr_enforcement_mode
  resources {
    attributes {
      name  = "accountId"
      value = data.ibm_iam_account_settings.team_iam_account_settings.account_id
    }
    attributes {
      name     = "resourceType"
      operator = "stringEquals"
      value    = "namespace"
    }
    attributes {
      name     = "resource"
      operator = "stringEquals"
      value    = "e2esec"
    }
    attributes {
      name     = "serviceName"
      operator = "stringEquals"
      value    = "container-registry"
    }

  }
}

# access to Key Protect from
# - IAM
# - Kubernetes
# - COS
# - (App ID, not yet supported)
resource "ibm_cbr_rule" "cbr_rule_kms" {
  contexts {
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_k8s.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_cos.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_groups.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_users.id
    }

  }

  description      = "restrict access to Key Protect"
  enforcement_mode = var.cbr_enforcement_mode
  resources {
    attributes {
      name  = "accountId"
      value = data.ibm_iam_account_settings.team_iam_account_settings.account_id
    }
    attributes {
      name     = "serviceInstance"
      operator = "stringEquals"
      value    = data.terraform_remote_state.e2e-resources.outputs.keyprotect.guid
    }
    attributes {
      name     = "serviceName"
      operator = "stringEquals"
      value    = "kms"
    }


  }
}



# access to Kubernetes Cluster management API from
# - IAM
# - home / bastion zone
resource "ibm_cbr_rule" "cbr_rule_k8s_mgmt" {
  contexts {
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_groups.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_iam_users.id
    }
    attributes {
      name  = "networkZoneId"
      value = ibm_cbr_zone.cbr_zone_homezone.id
    }
  }

  description      = "restrict access to Kubernetes management API"
  enforcement_mode = var.cbr_enforcement_mode
  operations {
        api_types {
            api_type_id = "crn:v1:bluemix:public:containers-kubernetes::::api-type:management"
        }
  }
  resources {
    attributes {
      name  = "accountId"
      value = data.ibm_iam_account_settings.team_iam_account_settings.account_id
    }
    attributes {
      name     = "serviceInstance"
      operator = "stringEquals"
      value    = data.terraform_remote_state.e2e-resources.outputs.cluster.id
    }
    attributes {
      name     = "serviceName"
      operator = "stringEquals"
      value    = "containers-kubernetes"
    }


  }
}