data "ibm_iam_account_settings" "team_iam_account_settings" {
}



# ZONES
#
# See https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cbr_zone
# The zones relate to general areas and services defined as part of the 
# IBM Cloud solution tutorial "Apply end to end security to a cloud application". 
# https://cloud.ibm.com/docs/solution-tutorials?topic=solution-tutorials-cloud-e2e-security


# Zone with the home network or for a bastion host
resource "ibm_cbr_zone" "cbr_zone_homezone" {
  account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
  addresses {
    type  = "ipRange"
    value = var.homezone_iprange
  }
  description = "Zone for typical home network"
  name        = "cbr_zone_homenetwork"
}

# Zone for the VPC that hosts the Kubernetes cluster
resource "ibm_cbr_zone" "cbr_zone_vpc" {
  account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
  addresses {
    type  = "vpc"
    value = data.terraform_remote_state.e2e-resources.outputs.vpc.crn
  }
  description = "Zone with VPC of Kubernetes cluster"
  name        = "cbr_zone_vpc"
}

# Zone with the Kubernetes cluster
resource "ibm_cbr_zone" "cbr_zone_k8s" {
  account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
  addresses {
    type = "serviceRef"
    ref {
      account_id       = data.ibm_iam_account_settings.team_iam_account_settings.account_id
      service_instance = data.terraform_remote_state.e2e-resources.outputs.cluster.id
      service_name     = "containers-kubernetes"
    }
  }
  description = "Zone with the Kubernetes cluster"
  name        = "cbr_zone_k8s"
}

# Zone with the COS service
resource "ibm_cbr_zone" "cbr_zone_cos" {
  account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
  addresses {
    type = "serviceRef"
    ref {
      account_id       = data.ibm_iam_account_settings.team_iam_account_settings.account_id
      service_instance = data.terraform_remote_state.e2e-resources.outputs.cos.guid
      service_name     = "cloud-object-storage"
    }
  }
  description = "Zone with COS"
  name        = "cbr_zone_cos"
}

# Key Protect service zone
# not yet supported as zone
/* resource "ibm_cbr_zone" "cbr_zone_kms" {
  account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
  addresses {
    type = "serviceRef"
    ref {
      account_id       = data.ibm_iam_account_settings.team_iam_account_settings.account_id
      service_instance = data.terraform_remote_state.e2e-resources.outputs.keyprotect.guid
      service_name     = "kms"
      location = data.terraform_remote_state.e2e-resources.outputs.keyprotect.location
    }
  }
  description = "Zone with Key Protect"
  name        = "cbr_zone_kms"
} */

# Service zone for IAM group management
resource "ibm_cbr_zone" "cbr_zone_iam_groups" {
  account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
  addresses {
    type = "serviceRef"
    ref {
      account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
      service_name = "iam-groups"
    }
  }
  description = "Zone for IAM groups"
  name        = "cbr_zone_iam_groups"
}

# Service zone for IAM user management
resource "ibm_cbr_zone" "cbr_zone_iam_users" {
  account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
  addresses {
    type = "serviceRef"
    ref {
      account_id = data.ibm_iam_account_settings.team_iam_account_settings.account_id
      service_name = "user-management"
    }
  }
  description = "Zone for IAM user management"
  name        = "cbr_zone_users"
}

# RULES
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
