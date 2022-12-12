# CBR zones
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
    value = data.ibm_is_vpc.vpc.crn
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
      service_instance = data.ibm_container_vpc_cluster.cluster.id
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
      service_instance = var.cos.guid
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