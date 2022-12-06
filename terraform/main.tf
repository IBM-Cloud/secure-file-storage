data "ibm_resource_group" "cloud_development" {
  name = var.resource_group
}

data "ibm_is_vpc" "vpc" {
  name = var.vpcname
}


# Create a service ID for security resources.
# The name is appended by the target resource group to distinguish
# between deployment environments
resource "ibm_iam_service_id" "ServiceID" {
  name        = "${var.basename}-serviceID-${var.resource_group}"
  description = "Service ID for deploying resources"

}

resource "ibm_iam_service_policy" "registry-policy" {
  iam_service_id = ibm_iam_service_id.ServiceID.id
  roles          = ["Reader"]

  resources {
    service = "container-registry"
    region  = var.region
  }
}

# create the App ID instance if required
resource "ibm_resource_instance" "app_id" {
  count = var.existing_resources ? 0 : 1
  name              = "${var.basename}-appid"
  service           = "appid"
  plan              = var.appid_plan
  location          = var.region
  resource_group_id = data.ibm_resource_group.cloud_development.id
  service_endpoints = "private"
  depends_on        = [ibm_iam_authorization_policy.APPIDKMSpolicy]
}

# or look it up
data "ibm_resource_instance" "data_app_id" {
  count = var.existing_resources ? 1 : 0
  name              = "${var.basename}-appid"
  service           = "appid"
  location          = var.region
}

# create the Cloudant instance if required
resource "ibm_resource_instance" "cloudant" {
  count = var.existing_resources ? 0 : 1
  name              = "${var.basename}-cloudant"
  service           = "cloudantnosqldb"
  plan              = var.cloudant_plan
  location          = var.region
  resource_group_id = data.ibm_resource_group.cloud_development.id
  service_endpoints = "private"
  parameters        = {"legacyCredentials": false}
}

# or look it up
data "ibm_resource_instance" "data_cloudant" {
  count = var.existing_resources ? 1 : 0
  name              = "${var.basename}-cloudant"
  service           = "cloudantnosqldb"
  location          = var.region
}


# create KP instance if required
resource "ibm_resource_instance" "keyprotect" {
  count = var.existing_resources ? 0 : 1
  name              = "${var.basename}-kms"
  service           = "kms"
  plan              = var.kp_plan
  location          = var.region
  resource_group_id = data.ibm_resource_group.cloud_development.id
  service_endpoints = "private"
}

# or look it up
data "ibm_resource_instance" "data_keyprotect" {
  count = var.existing_resources ? 1 : 0
  name              = "${var.basename}-kms"
  service           = "kms"
  location          = var.region
}

# create the COS instance if required
resource "ibm_resource_instance" "cos" {
  count = var.existing_resources ? 0 : 1
  name              = "${var.basename}-cos"
  service           = "cloud-object-storage"
  plan              = var.cos_plan
  location          = "global"
  resource_group_id = data.ibm_resource_group.cloud_development.id
}

# or look it up
data "ibm_resource_instance" "data_cos" {
  count = var.existing_resources ? 1 : 0
  name              = "${var.basename}-cos"
  service           = "cloud-object-storage"
}


# create root key
resource "ibm_kp_key" "rootkey" {
  key_protect_id = ibm_resource_instance.keyprotect[0].guid
  key_name       = "${var.basename}-rootkey"
  standard_key   = false
  force_delete   = true
}

resource "ibm_iam_authorization_policy" "COSKMSpolicy" {
  source_service_name         = "cloud-object-storage"
  source_resource_instance_id = ibm_resource_instance.cos[0].guid
  target_service_name         = "kms"
  target_resource_instance_id = ibm_resource_instance.keyprotect[0].guid
  roles                       = ["Reader"]
}

resource "ibm_iam_authorization_policy" "APPIDKMSpolicy" {
  source_service_name         = "appid"
  target_service_name         = "kms"
  target_resource_instance_id = ibm_resource_instance.keyprotect[0].guid
  roles                       = ["Reader"]
}

# create encrypted COS bucket using that root key
resource "ibm_cos_bucket" "cosbucket" {
  bucket_name          = "${var.basename}-bucket-${ibm_resource_instance.cos[0].guid}"
  resource_instance_id = ibm_resource_instance.cos[0].id
  region_location      = var.region
  key_protect          = ibm_kp_key.rootkey.crn
  storage_class        = "standard"
  force_delete         = true
}

# service access key for COS
resource "ibm_resource_key" "RKcos" {
  name                 = "${var.basename}-accKey-cos"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.cos[0].id
  parameters           = { HMAC = true }
}

# service access key for Cloudant with Writer privilege for app usage
resource "ibm_resource_key" "RKcloudant" {
  name                 = "${var.basename}-accKey-cloudant"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.cloudant[0].id
}

# service access key for Cloudant with Manager privilege (to create a database)
resource "ibm_resource_key" "RKcloudantManager" {
  name                 = "${var.basename}-accKey-cloudant-manager"
  role                 = "Manager"
  resource_instance_id = ibm_resource_instance.cloudant[0].id

  # create the database
  provisioner "local-exec" {
    command = "./create-database.sh"
    environment = {
      CLOUDANT_IAM_APIKEY = nonsensitive(ibm_resource_key.RKcloudantManager.credentials.apikey)
      CLOUDANT_URL        = nonsensitive(ibm_resource_key.RKcloudantManager.credentials.url)
      CLOUDANT_DATABASE   = "secure-file-storage-metadata"
    }
  }
}

# service access key for AppID
resource "ibm_resource_key" "RKappid" {
  name                 = "${var.basename}-accKey-appid"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.app_id[0].id
}

# service access key for KP
resource "ibm_resource_key" "RKkp" {
  name                 = "${var.basename}-accKey-kms"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.keyprotect[0].id
}