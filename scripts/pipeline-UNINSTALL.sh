#!/bin/bash
source ./scripts/pipeline-HELPER.sh

# fail script on error
set -e

# change into the app directory which contains the configuration file
cd app

if [ -z "$REGION" ]; then
  export REGION=$(ibmcloud target | grep Region | awk '{print $2}')
fi
echo "REGION=$REGION"

# Get the workspace information
WORKSPACE_INFO=$(ibmcloud schematics workspace get --id $SCHEMATICS_WORKSPACE_NAME --output json)

# extract basename, try set values first, then defaults if not set
BASENAME=$(echo $WORKSPACE_INFO | jq -r '.template_data[].variablestore[] | select(.name=="basename").value')
if [ -z "$BASENAME" ]; then
  export BASENAME=$(echo $WORKSPACE_INFO | jq -r '.template_data | .[].values_metadata[] | select(.name=="basename").default'
fi
echo BASENAME=$BASENAME

# Extract required information from workspace JSON
# resource group
TARGET_RESOURCE_GROUP=$(echo $WORKSPACE_INFO | jq -r '.resource_group')
echo TARGET_RESOURCE_GROUP=$TARGET_RESOURCE_GROUP

ibmcloud target -g $TARGET_RESOURCE_GROUP || exit 1

# Name of Kubernetes cluster
PIPELINE_KUBERNETES_CLUSTER_NAME=$(echo $WORKSPACE_INFO | jq -r '.template_data[].variablestore[] | select(.name=="iks_cluster_name").value')
if [ -z "$PIPELINE_KUBERNETES_CLUSTER_NAME" ]; then
  export PIPELINE_KUBERNETES_CLUSTER_NAME=$(echo $WORKSPACE_INFO | jq -r '.template_data | .[].values_metadata[] | select(.name=="iks_cluster_name").default'
fi
echo PIPELINE_KUBERNETES_CLUSTER_NAME=$PIPELINE_KUBERNETES_CLUSTER_NAME

# deployment namespace in cluster
TARGET_NAMESPACE=$(echo $WORKSPACE_INFO | jq -r '.template_data[].variablestore[] | select(.name=="iks_namespace").value')
if [ -z "$TARGET_NAMESPACE" ]; then
  export TARGET_NAMESPACE=$(echo $WORKSPACE_INFO | jq -r '.template_data | .[].values_metadata[] | select(.name=="iks_namespace").default'
fi
echo TARGET_NAMESPACE=$TARGET_NAMESPACE

# download and set cluster context
echo "getting cluster config"
ibmcloud ks cluster config --cluster $PIPELINE_KUBERNETES_CLUSTER_NAME

# this should be done by TF as it is not really app-related
# echo "unbindng appid"
# ibmcloud ks cluster service unbind \
#   --cluster "$PIPELINE_KUBERNETES_CLUSTER_NAME" \
#   --namespace "$TARGET_NAMESPACE" \
#   --service "$GUID"

#
# Kubernetes
#
section "Kubernetes"
kubectl delete --namespace $TARGET_NAMESPACE -f secure-file-storage.template.yaml
kubectl delete --namespace $TARGET_NAMESPACE secret $BASENAME-docker-registry
kubectl delete --namespace $TARGET_NAMESPACE secret $BASENAME-credentials

#
# Docker image
#
REGISTRY_URL=$(ibmcloud cr info | grep -m1 -i '^Container Registry' | awk '{print $3;}')
IMAGE_URL="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}"

ibmcloud cr image-rm $IMAGE_URL

#
# Services
#

section "services to be removed using Schematics / terraform"
