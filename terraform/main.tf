resource "ibm_resource_group" "cloud_development" {
  name = "${var.basename}-development"
  tags = []
}

resource "ibm_resource_instance" "app_id" {
  name              = "${var.basename}-appid"
  service           = "appid"
  plan              = "graduated-tier"
  location          = var.region
  resource_group_id = ibm_resource_group.cloud_development.id
  service_endpoints = "private"
}

resource "ibm_resource_instance" "cloudant" {
  name              = "${var.basename}-cloudant"
  service           = "cloudantnosqldb"
  plan              = "lite"
  location          = var.region
  resource_group_id = ibm_resource_group.cloud_development.id
  service_endpoints = "private"
}

resource "ibm_resource_instance" "keyprotect" {
  name              = "${var.basename}-kp"
  service           = "kms"
  plan              = "tiered-pricing"
  location          = var.region
  resource_group_id = ibm_resource_group.cloud_development.id
  service_endpoints = "private"
}

resource "ibm_resource_instance" "cos" {
  name              = "${var.basename}-cos"
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  resource_group_id = ibm_resource_group.cloud_development.id
}

# create root key
resource "ibm_kp_key" "rootkey" {
  key_protect_id = ibm_resource_instance.keyprotect.guid
  key_name       = "${var.basename}-rootkey"
  standard_key   = false
  force_delete   = true
}


resource "ibm_iam_authorization_policy" "COSKMSpolicy" {
  source_service_name      = "cloud-object-storage"
  source_resource_group_id = ibm_resource_group.cloud_development.id
  target_service_name      = "kms"
  target_resource_group_id = ibm_resource_group.cloud_development.id
  roles                    = ["Reader"]
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
    command = "curl -X PUT ${ibm_resource_key.RKcloudantManager.credentials.url}/${var.basename}-metadata"
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