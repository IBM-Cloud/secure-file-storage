#!/bin/bash
# Retrieve the values to be used in the credentials.env file

if [ -z "$REGION" ]; then
  export REGION=$(ibmcloud target | grep Region | awk '{print $2}')
fi

CLOUDANT_GUID=$(ibmcloud resource service-instance --id secure-file-storage-cloudant | awk '{print $2}')
CLOUDANT_CREDENTIALS=$(ibmcloud resource service-key secure-file-storage-cloudant-acckey-$CLOUDANT_GUID)
CLOUDANT_USERNAME=$(echo "$CLOUDANT_CREDENTIALS" | grep username | awk '{ print $2 }')
CLOUDANT_IAM_APIKEY=$(echo "$CLOUDANT_CREDENTIALS" | sort | grep apikey -m 1 | awk '{ print $2 }')
CLOUDANT_DATABASE=secure-file-storage-metadata

echo "# Cloudant Credentials
cloudant_username=$CLOUDANT_USERNAME
cloudant_iam_apikey=$CLOUDANT_IAM_APIKEY
cloudant_database=$CLOUDANT_DATABASE
"

COS_GUID=$(ibmcloud resource service-instance --id secure-file-storage-cos | awk '{print $2}')
COS_CREDENTIALS=$(ibmcloud resource service-key secure-file-storage-cos-acckey-$COS_GUID)
COS_ACCESS_KEY_ID=$(echo "$COS_CREDENTIALS" | grep access_key_id  | awk '{ print $2 }')
COS_SECRET_ACCESS_KEY=$(echo "$COS_CREDENTIALS" | grep secret_access_key  | awk '{ print $2 }')
COS_APIKEY=$(echo "$COS_CREDENTIALS" | sort | grep "apikey:" -m 1 | awk '{ print $2 }')
COS_RESOURCE_INSTANCE_ID=$(echo "$COS_CREDENTIALS" | grep "resource_instance_id"  | awk '{ print $2 }')
COS_ENDPOINTS_URL=$(echo "$COS_CREDENTIALS" | grep endpoints | awk '{ print $2 }')
COS_ENDPOINTS=$(curl -s $COS_ENDPOINTS_URL)
COS_ENDPOINT=$(echo $COS_ENDPOINTS | jq -r '.["service-endpoints"].regional["'$REGION'"].private["'$REGION'"]')
COS_IBMAUTHENDPOINT=https://$(echo $COS_ENDPOINTS | jq -r '.["identity-endpoints"]["iam-token"]')/identity/token
COS_BUCKET_NAME=secure-file-storage-$COS_GUID

echo "# Cloud Object Storage(cos) Credentials
cos_endpoint=$COS_ENDPOINT
cos_apiKey=$COS_APIKEY
cos_ibmAuthEndpoint=$COS_IBMAUTHENDPOINT
cos_resourceInstanceID=$COS_RESOURCE_INSTANCE_ID
cos_access_key_id=$COS_ACCESS_KEY_ID
cos_secret_access_key=$COS_SECRET_ACCESS_KEY
cos_bucket_name=$COS_BUCKET_NAME
"
