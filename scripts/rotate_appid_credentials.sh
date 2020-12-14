#!/bin/bash

# fail script on error
set -e

source ./scripts/pipeline-HELPER.sh

if [ -z "$REGION" ]; then
  export REGION=$(ibmcloud target --output json | jq -r '.region.name')
fi
echo "REGION=$REGION"

if [ -z "$TARGET_RESOURCE_GROUP" ]; then
  TARGET_RESOURCE_GROUP=default
fi
echo TARGET_RESOURCE_GROUP=$TARGET_RESOURCE_GROUP

if [ -z "$TARGET_NAMESPACE" ]; then
  export TARGET_NAMESPACE=default
fi
echo "TARGET_NAMESPACE=$TARGET_NAMESPACE"

# Obtain today's date
printf -v TODAYS_DATE '%(%Y%m%d)T' -1

section "Getting existing metadata"
APPID_BINDING_SECRET_OUT=$(kubectl get secret binding-secure-file-storage-appid --namespace $TARGET_NAMESPACE -o json)
APPID_BINDING_JSON=$(echo "$APPID_BINDING_SECRET_OUT" | jq -r '.data.binding' | base64 --decode )
APPID_KEYNAME=$(echo "$APPID_BINDING_JSON" | jq -r '.iam_apikey_name')
APPID_GUID=$(echo "$APPID_BINDING_JSON" | jq -r '.tenantId')

section "Create new key and replace secret"
echo "Renaming existing key to ${APPID_KEYNAME}-old-${TODAYS_DATE}"
ibmcloud resource service-key-update ${APPID_KEYNAME} -n ${APPID_KEYNAME}-old-${TODAYS_DATE} -g $TARGET_RESOURCE_GROUP -f 2>&1
echo "Creating new key ${APPID_KEYNAME}"
ibmcloud resource service-key-create ${APPID_KEYNAME} Writer --instance-id ${APPID_GUID} -g $TARGET_RESOURCE_GROUP -f 2>&1
APPID_NEW_CREDENTIALS_OUT=$(ibmcloud resource service-key ${APPID_KEYNAME} -g $TARGET_RESOURCE_GROUP --output json)
APPID_NEW_CREDENTIALS=$(echo -n "$APPID_NEW_CREDENTIALS_OUT" | jq -r -c '.[].credentials')

# Now generate a new secret and replace the existing one
section "Applying credentials to existing secret"
kubectl create secret generic binding-secure-file-storage-appid \
        --from-literal="binding=${APPID_NEW_CREDENTIALS}" -n $TARGET_NAMESPACE -o yaml --dry-run=true \
        | kubectl apply -f - 2>&1

section "Done"
echo "Now check that everything works. Thereafter you can remove the old key with the following command:"
echo "ibmcloud resource service-key-delete ${APPID_KEYNAME}-old-${TODAYS_DATE} -g $TARGET_RESOURCE_GROUP"