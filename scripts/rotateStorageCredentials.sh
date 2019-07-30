#!/bin/bash

# fail script on error
set -e

source ./scripts/pipeline-HELPER.sh

if [ -z "$TARGET_NAMESPACE" ]; then
  export TARGET_NAMESPACE=default
fi
echo "TARGET_NAMESPACE=$TARGET_NAMESPACE"

# Obtain today's date
printf -v TODAYS_DATE '%(%Y%m%d)T' -1

COS_INSTANCE_ID=$(get_instance_id secure-file-storage-cos)
COS_GUID=$(get_guid secure-file-storage-cos)
echo "COS_INSTANCE_ID=$COS_INSTANCE_ID"
echo "COS_GUID=$COS_GUID"
check_value "$COS_INSTANCE_ID"
check_value "$COS_GUID"


section "Existing metadata"
CURRENT_CREDS=$(kubectl get secret secure-file-storage-credentials --namespace "$TARGET_NAMESPACE" -o json)
CURRENT_CREDS_DATA=$(echo "$CURRENT_CREDS" | jq -r '.data')

COS_ENDPOINT=$(echo "$CURRENT_CREDS_DATA" | jq -r '.cos_endpoint' | base64 --decode)
COS_IBMAUTHENDPOINT=$(echo "$CURRENT_CREDS_DATA" | jq -r '.cos_ibmAuthEndpoint' | base64 --decode)
COS_BUCKET_NAME=$(echo "$CURRENT_CREDS_DATA" | jq -r '.cos_bucket_name' | base64 --decode)

CLOUDANT_DATABASE=$(echo "$CURRENT_CREDS_DATA" | jq -r '.cloudant_database' | base64 --decode)

section "COS credentials"
# Rename the existing COS key
ibmcloud resource service-key-update secure-file-storage-cos-acckey-$COS_GUID \
       -n secure-file-storage-cos-acckey-$COS_GUID-old-$TODAYS_DATE -f

# Create the new key
ibmcloud resource service-key-create secure-file-storage-cos-acckey-$COS_GUID Manager \
    --instance-id "$COS_INSTANCE_ID" \
    -p '{"HMAC": true}'

COS_CREDENTIALS_JSON=$(ibmcloud resource service-key secure-file-storage-cos-acckey-$COS_GUID --output json)

COS_ACCESS_KEY_ID=$(echo "$COS_CREDENTIALS_JSON" | jq -r '.[].credentials.cos_hmac_keys.access_key_id')
COS_SECRET_ACCESS_KEY=$(echo "$COS_CREDENTIALS_JSON" | jq -r '.[].credentials.cos_hmac_keys.secret_access_key')
COS_APIKEY=$(echo "$COS_CREDENTIALS_JSON" | jq -r '.[].credentials.apikey')
COS_RESOURCE_INSTANCE_ID=$COS_INSTANCE_ID

section "Cloudant credentials"
CLOUDANT_INSTANCE_ID=$(get_instance_id secure-file-storage-cloudant)
CLOUDANT_GUID=$(get_guid secure-file-storage-cloudant)
echo "CLOUDANT_INSTANCE_ID=$CLOUDANT_INSTANCE_ID"
echo "CLOUDANT_GUID=$CLOUDANT_GUID"
check_value "$CLOUDANT_INSTANCE_ID"
check_value "$CLOUDANT_GUID"


# Rename the existing Cloudant key
ibmcloud resource service-key-update secure-file-storage-cloudant-acckey-$CLOUDANT_GUID \
       -n secure-file-storage-cloudant-acckey-$CLOUDANT_GUID-old-$TODAYS_DATE -f

# Create the new key
ibmcloud resource service-key-create secure-file-storage-cloudant-acckey-$CLOUDANT_GUID Manager \
    --instance-id "$CLOUDANT_INSTANCE_ID"

CLOUDANT_CREDENTIALS_JSON=$(ibmcloud resource service-key secure-file-storage-cloudant-acckey-$CLOUDANT_GUID --output json)
CLOUDANT_USERNAME=$(echo "$CLOUDANT_CREDENTIALS_JSON" | jq -r '.[].credentials.username')
CLOUDANT_IAM_APIKEY=$(echo "$CLOUDANT_CREDENTIALS_JSON" | jq -r '.[].credentials.apikey')

section "Recreate the secret"
# First, delete the existing secret
kubectl delete secret secure-file-storage-credentials --namespace "$TARGET_NAMESPACE"

# Now, create the secret again, similar to what is in the DEPLOY script
kubectl create secret generic secure-file-storage-credentials \
  --from-literal="cos_endpoint=$COS_ENDPOINT" \
  --from-literal="cos_ibmAuthEndpoint=$COS_IBMAUTHENDPOINT" \
  --from-literal="cos_apiKey=$COS_APIKEY" \
  --from-literal="cos_resourceInstanceId=$COS_RESOURCE_INSTANCE_ID" \
  --from-literal="cos_access_key_id=$COS_ACCESS_KEY_ID" \
  --from-literal="cos_secret_access_key=$COS_SECRET_ACCESS_KEY" \
  --from-literal="cos_bucket_name=$COS_BUCKET_NAME" \
  --from-literal="cloudant_username=$CLOUDANT_USERNAME" \
  --from-literal="cloudant_iam_apikey=$CLOUDANT_IAM_APIKEY" \
  --from-literal="cloudant_database=$CLOUDANT_DATABASE" \
  --namespace "$TARGET_NAMESPACE" || exit 1


section "Restarting the deployed app"
# Restart the deployment to apply the secret
kubectl rollout restart deployment secure-file-storage-deployment -n $TARGET_NAMESPACE

echo "You can delete the old credentials once everything works ok using these commands:"
echo "ibmcloud resource service-key-delete secure-file-storage-cos-acckey-$COS_GUID"
echo "ibmcloud resource service-key-delete secure-file-storage-cloudant-acckey-$CLOUDANT_GUID"