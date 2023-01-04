output "credentials_env" {
  sensitive = true
  value     = <<-EOS
  # Cloudant Credentials
  cloudant_url=https://${ibm_resource_instance.cloudant.extensions["endpoints.public"]}
  cloudant_iam_apikey=${ibm_resource_key.RKcloudant.credentials.apikey}
  cloudant_database=secure-file-storage-metadata

  # Cloud Object Storage(cos) Credentials
  cos_endpoint=${ibm_cos_bucket.cosbucket.s3_endpoint_direct}
  cos_apiKey=${ibm_resource_key.RKcos.credentials.apikey}
  cos_ibmAuthEndpoint=https://iam.cloud.ibm.com/identity/token
  cos_resourceInstanceID=${ibm_resource_instance.cos.id}
  cos_access_key_id=${ibm_resource_key.RKcos.credentials["cos_hmac_keys.access_key_id"]}
  cos_secret_access_key=${ibm_resource_key.RKcos.credentials["cos_hmac_keys.secret_access_key"]}
  cos_bucket_name=${ibm_cos_bucket.cosbucket.bucket_name}
  EOS
}
