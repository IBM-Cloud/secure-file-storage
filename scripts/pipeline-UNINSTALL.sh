#!/bin/bash
source ./scripts/pipeline-HELPER.sh

ibmcloud target -g $TARGET_RESOURCE_GROUP || exit 1

if [ -z "$REGION" ]; then
  export REGION=$(ibmcloud target | grep Region | awk '{print $2}')
fi
echo "REGION=$REGION"

#
# The user running the script will be used to name some resources
#
TARGET_USER=$(ibmcloud target | grep User | awk '{print $2}')
check_value "$TARGET_USER"
echo "TARGET_USER=$TARGET_USER"

#
# Kubernetes
#
section "Kubernetes"
kubectl delete --namespace $TARGET_NAMESPACE -f secure-file-storage.template.yaml
kubectl delete --namespace $TARGET_NAMESPACE secret secure-file-storage-docker-registry
kubectl delete --namespace $TARGET_NAMESPACE secret secure-file-storage-credentials

#
# Docker image
#
ibmcloud cr image-rm $IMAGE_URL

#
# Services
#
section "App ID"
GUID=$(get_guid secure-file-storage-appid)
ibmcloud cs cluster-service-unbind \
  --cluster "$PIPELINE_KUBERNETES_CLUSTER_NAME" \
  --namespace "$TARGET_NAMESPACE" \
  --service "$GUID"
ibmcloud resource service-instance-delete -f --recursive secure-file-storage-appid

section "Cloud Object Storage"
ibmcloud resource service-instance-delete -f --recursive secure-file-storage-cos

section "Cloudant"
ibmcloud resource service-instance-delete -f --recursive secure-file-storage-cloudant

section "Key Protect"
KP_GUID=$(get_guid secure-file-storage-kms)
echo "KP_GUID=$KP_GUID"
KP_CREDENTIALS=$(ibmcloud resource service-key secure-file-storage-kms-acckey-$KP_GUID)
echo "KP_CREDENTIALS=$KP_CREDENTIALS"
KP_IAM_APIKEY=$(echo "$KP_CREDENTIALS" | sort | grep "apikey:" -m 1 | awk '{ print $2 }')
echo "KP_IAM_APIKEY=$KP_IAM_APIKEY"
KP_ACCESS_TOKEN=$(get_access_token $KP_IAM_APIKEY)
echo "KP_ACCESS_TOKEN=$KP_ACCESS_TOKEN"
KP_MANAGEMENT_URL="https://keyprotect.$REGION.bluemix.net/api/v2/keys"

# Delete root key
KP_KEYS=$(curl -s $KP_MANAGEMENT_URL \
  --header "Authorization: Bearer $KP_ACCESS_TOKEN" \
  --header "Bluemix-Instance: $KP_GUID")
KP_COS_KEY_ID=$(echo $KP_KEYS | jq -e -r '.resources[] | select(.name=="secure-file-storage-root-enckey") | .id')
curl -v -X DELETE \
  "$KP_MANAGEMENT_URL/$KP_COS_KEY_ID" \
  -H "Authorization: Bearer $KP_ACCESS_TOKEN" \
  -H "Bluemix-Instance: $KP_GUID" \
  -H "Accept: application/vnd.ibm.kms.key+json"

# And the service
ibmcloud resource service-instance-delete -f --recursive secure-file-storage-kms

section "Service ID"
ibmcloud iam service-id-delete -f "secure-file-storage-serviceID-$TARGET_USER"
