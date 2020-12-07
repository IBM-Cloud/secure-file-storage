data "ibm_resource_group" "cloud_development" {
  name = var.resource_group
}

# Create a service ID for security resources.
# The name is appended by the target resource group to distinguish
# between deployment environments
resource "ibm_iam_service_id" "ServiceID" {
  name        = "${var.basename}-serviceID-${var.resource_group}"
  description = "Service ID for deploying resources"

}

resource "ibm_resource_instance" "app_id" {
  name              = "${var.basename}-appid"
  service           = "appid"
  plan              = "graduated-tier"
  location          = var.region
  resource_group_id = data.ibm_resource_group.cloud_development.id
  service_endpoints = "private"
}

resource "ibm_resource_instance" "cloudant" {
  name              = "${var.basename}-cloudant"
  service           = "cloudantnosqldb"
  plan              = "lite"
  location          = var.region
  resource_group_id = data.ibm_resource_group.cloud_development.id
  service_endpoints = "private"
}

resource "ibm_resource_instance" "keyprotect" {
  name              = "${var.basename}-kms"
  service           = "kms"
  plan              = "tiered-pricing"
  location          = var.region
  resource_group_id = data.ibm_resource_group.cloud_development.id
  service_endpoints = "private"
}

resource "ibm_resource_instance" "cos" {
  name              = "${var.basename}-cos"
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  resource_group_id = data.ibm_resource_group.cloud_development.id
}

# create root key
resource "ibm_kp_key" "rootkey" {
  key_protect_id = ibm_resource_instance.keyprotect.guid
  key_name       = "${var.basename}-rootkey"
  standard_key   = false
  force_delete   = true
}


resource "ibm_iam_authorization_policy" "COSKMSpolicy" {
  source_service_name         = "cloud-object-storage"
  source_resource_instance_id    = ibm_resource_instance.cos.guid
  target_service_name         = "kms"
  target_resource_instance_id = ibm_resource_instance.keyprotect.guid
  roles                       = ["Reader"]
}

# create encrypted COS bucket using that root key
resource "ibm_cos_bucket" "cosbucket" {
  bucket_name          = "${var.basename}-bucket-${ibm_resource_instance.cos.guid}"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = var.region
  key_protect          = ibm_kp_key.rootkey.crn
  storage_class        = "standard"
}

# service access key for COS
resource "ibm_resource_key" "RKcos" {
  name                 = "${var.basename}-accKey-cos"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.cos.id
  parameters           = { HMAC = true }
}

# special null resource to empty the bucket in order to delete it
resource null_resource delete_cos_objects {
  triggers = {
    ACCESS_KEY             = ibm_resource_key.RKcos.credentials["cos_hmac_keys.access_key_id"]
    SECRET_ACCESS_KEY      = ibm_resource_key.RKcos.credentials["cos_hmac_keys.secret_access_key"]
    COS_REGION             = var.region
    COS_BUCKET_NAME        = ibm_cos_bucket.cosbucket.bucket_name
  }
  provisioner "local-exec" {
    when = destroy
    command = "./delete-cos-objects.sh ${self.triggers.COS_REGION} ${self.triggers.ACCESS_KEY} ${self.triggers.SECRET_ACCESS_KEY} ${self.triggers.COS_BUCKET_NAME} || true"
  }
  depends_on = [ibm_resource_key.RKcos,ibm_cos_bucket.cosbucket]
}

# service access key for Cloudant with Writer privilege for app usage
resource "ibm_resource_key" "RKcloudant" {
  name                 = "${var.basename}-accKey-cloudant"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.cloudant.id
}

# service access key for Cloudant with Manager privilege (to create a database)
resource "ibm_resource_key" "RKcloudantManager" {
  name                 = "${var.basename}-accKey-cloudant-manager"
  role                 = "Manager"
  resource_instance_id = ibm_resource_instance.cloudant.id

  # create the database
  provisioner "local-exec" {
    command = "curl -X PUT ${ibm_resource_key.RKcloudantManager.credentials.url}/secure-file-storage-metadata"
  }
}


# service access key for AppID
resource "ibm_resource_key" "RKappid" {
  name                 = "${var.basename}-accKey-appid"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.app_id.id
}

# service access key for KP
resource "ibm_resource_key" "RKkp" {
  name                 = "${var.basename}-accKey-kms"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.keyprotect.id
}