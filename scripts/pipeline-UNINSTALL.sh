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
TARGET_JSON=$(ibmcloud target --output json)
TARGET_USER=$(echo $TARGET_JSON | jq -r '.user.user_email')
if [ -z "$TARGET_USER" ]; then
  TARGET_USER=$(echo $TARGET_JSON | jq -r '.user.display_name')
fi
check_value "$TARGET_USER"
echo "TARGET_USER=$TARGET_USER"


# remove App ID binding to Kubernetes cluster
GUID=$(get_guid secure-file-storage-appid)
ibmcloud ks cluster service unbind \
  --cluster "$PIPELINE_KUBERNETES_CLUSTER_NAME" \
  --namespace "$TARGET_NAMESPACE" \
  --service "$GUID"

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

section "service to be removed using Schematics / terraform"
