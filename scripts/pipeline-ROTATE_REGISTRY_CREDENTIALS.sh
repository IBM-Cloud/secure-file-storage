#!/bin/bash
# fail script on error
set -e

source ./scripts/pipeline-HELPER.sh

# This script can be used to replace the image pull secret used in this IBM Cloud solution tutorial:
# https://github.com/IBM-Cloud/secure-file-storage
# A similar strategy can be applied to other secrets storing API keys


section "Getting existing metadata"
# Obtain today's date
printf -v TODAYS_DATE '%(%Y%m%d)T' -1

if [ -z "$TARGET_NAMESPACE" ]; then
  export TARGET_NAMESPACE=default
fi
echo "TARGET_NAMESPACE=$TARGET_NAMESPACE"

TARGET_USER=$(ibmcloud target --output json | jq -r '.user.user_email')
check_value "$TARGET_USER"
echo "TARGET_USER=$TARGET_USER"

if [ -z "$REGISTRY_URL" ]; then
    echo "Need to set REGISTRY_URL to container registry URI."
    exit 1;
fi
echo "REGISTRY_URL=$REGISTRY_URL"
IMAGE_PULL_SECRET="secure-file-storage-docker-registry"

SERVICE_ID_NAME="secure-file-storage-serviceID-$TARGET_USER"
#SERVICE_ID_UUID=$(ibmcloud iam service-id $SERVICE_ID_NAME --uuid)
SERVICE_KEYNAME="secure-file-storage-serviceID-API-key"

section "Updating keys and secret"
# Rename existing key;
ibmcloud iam service-api-key-update $SERVICE_KEYNAME $SERVICE_ID_NAME -n ${SERVICE_KEYNAME}-old-${TODAYS_DATE} --force

# Create new key
API_KEY_OUT=$(ibmcloud iam service-api-key-create $SERVICE_KEYNAME $SERVICE_ID_NAME  --output json --force)
API_KEY_VALUE=$(echo "$API_KEY_OUT" | jq -r '.apiKey')

# Apply new key and replace it in the existing image pull secret
kubectl --namespace $TARGET_NAMESPACE create secret docker-registry $IMAGE_PULL_SECRET \
        --docker-server=$REGISTRY_URL \
        --docker-username=iamapikey \
        --docker-password=$API_KEY_VALUE \
        --docker-email="${TARGET_USER}" \
        --dry-run -o yaml \
        | kubectl apply -f -

section "Closing remarks"
echo "To verify the updated secret, use this command:"
echo "kubectl get secret $IMAGE_PULL_SECRET -n $TARGET_NAMESPACE -o yaml | grep dockerconfigjson: | awk '{print \$2}' | base64 --decode"
echo "To delete the old API key use:"
echo "ibmcloud iam service-api-key-delete ${SERVICE_KEYNAME}-old-${TODAYS_DATE} $SERVICE_ID_NAME"
