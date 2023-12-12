#!/bin/bash
# fail script on error
set -e

source ./scripts/pipeline-HELPER.sh

# change into the app directory which contains the configuration file
cd app

#
# Set environments to good default values in case we are not running from the toolchain but interactively
#
section "Environment"

if [ -z "$REGION" ]; then
  export REGION=$(ibmcloud target --output json | jq -r '.region.name')
fi
echo "REGION=$REGION"

# Schematics workspace name MUST be set
if [ -z "$SCHEMATICS_WORKSPACE_NAME" ]; then
  echo "Schematics workspace required"
  exit 1
fi
# Get the workspace information
WORKSPACE_INFO=$(ibmcloud schematics workspace get --id $SCHEMATICS_WORKSPACE_NAME --output json)

# Extract required information from workspace JSON
# resource group
TARGET_RESOURCE_GROUP=$(echo $WORKSPACE_INFO | jq -r '.template_data[].variablestore[] | select(.name=="resource_group").value')
if [ -z "$TARGET_RESOURCE_GROUP" ]; then
  export TARGET_RESOURCE_GROUP=$(echo $WORKSPACE_INFO | jq -r '.template_data | .[].values_metadata[] | select(.name=="resource_group").default')
fi
echo TARGET_RESOURCE_GROUP=$TARGET_RESOURCE_GROUP
# set it
ibmcloud target -g $TARGET_RESOURCE_GROUP || exit 1

# extract basename
BASENAME=$(echo $WORKSPACE_INFO | jq -r '.template_data[].variablestore[] | select(.name=="basename").value')
if [ -z "$BASENAME" ]; then
  export BASENAME=$(echo $WORKSPACE_INFO | jq -r '.template_data | .[].values_metadata[] | select(.name=="basename").default')
fi
echo BASENAME=$BASENAME


# Name of Kubernetes cluster
PIPELINE_KUBERNETES_CLUSTER_NAME=$(echo $WORKSPACE_INFO | jq -r '.template_data[].variablestore[] | select(.name=="iks_cluster_name").value')
if [ -z "$PIPELINE_KUBERNETES_CLUSTER_NAME" ]; then
  export PIPELINE_KUBERNETES_CLUSTER_NAME=$(echo $WORKSPACE_INFO | jq -r '.template_data | .[].values_metadata[] | select(.name=="iks_cluster_name").default')
fi
echo PIPELINE_KUBERNETES_CLUSTER_NAME=$PIPELINE_KUBERNETES_CLUSTER_NAME

# deployment namespace in cluster
TARGET_NAMESPACE=$(echo $WORKSPACE_INFO | jq -r '.template_data[].variablestore[] | select(.name=="iks_namespace").value')
if [ -z "$TARGET_NAMESPACE" ]; then
  export TARGET_NAMESPACE=$(echo $WORKSPACE_INFO | jq -r '.template_data | .[].values_metadata[] | select(.name=="iks_namespace").default')
fi
echo TARGET_NAMESPACE=$TARGET_NAMESPACE

echo "IMAGE_REPOSITORY=$IMAGE_REPOSITORY"
export REGISTRY_URL=$(echo $IMAGE_REPOSITORY |  awk -F/ '{print $1}')
echo "REGISTRY_URL=$REGISTRY_URL"

#
CLUSTER_INFO=$(ibmcloud ks cluster get --cluster $PIPELINE_KUBERNETES_CLUSTER_NAME --output json)

# download and set cluster context
ibmcloud ks cluster config --cluster $PIPELINE_KUBERNETES_CLUSTER_NAME

# show available contexts for debugging reasons
# kubectl config get-contexts

#
# The user running the script will be used to pull the image
#
TARGET_JSON=$(ibmcloud target --output json)
TARGET_USER=$(echo $TARGET_JSON | jq -r '.user.user_email')
if [ -z "$TARGET_USER" ]; then
  TARGET_USER=$(echo $TARGET_JSON | jq -r '.user.display_name')
fi
check_value "$TARGET_USER"
echo "TARGET_USER=$TARGET_USER"

#
# Obtain Service ID information
#
section "Service ID"
SERVICE_ID_NAME=$BASENAME-serviceID-$TARGET_RESOURCE_GROUP
SERVICE_ID=$(ibmcloud iam service-id $SERVICE_ID_NAME --uuid)
echo "SERVICE_ID=$SERVICE_ID"
check_value "$SERVICE_ID"

#
# Key Protect
#
section "Key Protect"

KP_INSTANCE_ID=$(get_instance_id $BASENAME-kms)
KP_GUID=$(get_guid $BASENAME-kms)
echo "KP_INSTANCE_ID=$KP_INSTANCE_ID"
echo "KP_GUID=$KP_GUID"
#check_value "$KP_INSTANCE_ID"
#check_value "$KP_GUID"

KP_CREDENTIALS=$(ibmcloud resource service-key $BASENAME-accKey-kms --output JSON)
KP_IAM_APIKEY=$(echo "$KP_CREDENTIALS" | jq -r .[0].credentials.apikey)
KP_ACCESS_TOKEN=$(get_access_token $KP_IAM_APIKEY)
KP_MANAGEMENT_URL="https://$REGION.kms.cloud.ibm.com/api/v2/keys"

#
# Cloudant instance with IAM authentication
#
section "Cloudant"
CLOUDANT_INSTANCE_ID=$(get_instance_id $BASENAME-cloudant)
CLOUDANT_GUID=$(get_guid $BASENAME-cloudant)
echo "CLOUDANT_INSTANCE_ID=$CLOUDANT_INSTANCE_ID"
echo "CLOUDANT_GUID=$CLOUDANT_GUID"
check_value "$CLOUDANT_INSTANCE_ID"
check_value "$CLOUDANT_GUID"

CLOUDANT_CREDENTIALS=$(ibmcloud resource service-key $BASENAME-accKey-cloudant)
CLOUDANT_USERNAME=$(echo "$CLOUDANT_CREDENTIALS" | grep "username:" | awk '{ print $2 }')
CLOUDANT_IAM_APIKEY=$(echo "$CLOUDANT_CREDENTIALS" | sort | grep "apikey:" -m 1 | awk '{ print $2 }')
CLOUDANT_URL=$(echo "$CLOUDANT_CREDENTIALS" | grep "url:" -m 1 | awk '{ print $2 }')
CLOUDANT_ACCESS_TOKEN=$(get_access_token $CLOUDANT_IAM_APIKEY)

if [ -z "$CLOUDANT_DATABASE" ]; then
  echo 'CLOUDANT_DATABASE was not set, using default value'
  export CLOUDANT_DATABASE=secure-file-storage-metadata
fi
echo "CLOUDANT_DATABASE=$CLOUDANT_DATABASE"

#
# Cloud Object Storage with HMAC authentication
#
section "Cloud Object Storage"
COS_INSTANCE_ID=$(get_instance_id $BASENAME-cos)
COS_GUID=$(get_guid $BASENAME-cos)
check_value "$COS_INSTANCE_ID"
check_value "$COS_GUID"

COS_CREDENTIALS=$(ibmcloud resource service-key $BASENAME-accKey-cos)
COS_ACCESS_KEY_ID=$(echo "$COS_CREDENTIALS" | grep access_key_id  | awk '{ print $2 }')
COS_SECRET_ACCESS_KEY=$(echo "$COS_CREDENTIALS" | grep secret_access_key  | awk '{ print $2 }')
COS_APIKEY=$(echo "$COS_CREDENTIALS" | sort | grep "apikey:" -m 1 | awk '{ print $2 }')
COS_RESOURCE_INSTANCE_ID=$(echo "$COS_CREDENTIALS" | grep "resource_instance_id"  | awk '{ print $2 }')
COS_ENDPOINTS_URL=$(echo "$COS_CREDENTIALS" | grep endpoints | awk '{ print $2 }')
COS_ENDPOINTS=$(curl -s $COS_ENDPOINTS_URL)
COS_ACCESS_TOKEN=$(get_access_token $COS_APIKEY)

COS_BUCKET_NAME=$BASENAME-bucket-$COS_GUID
echo "COS_BUCKET_NAME=$COS_BUCKET_NAME"

if [ -z "$COS_ENDPOINT" ]; then
  echo "COS_ENDPOINT was not set, finding value from $COS_ENDPOINTS_URL"
  VPC=$(echo $CLUSTER_INFO | jq -r 'select(.vpcs) | .vpcs[]')
  if [ -z ${VPC} ]; then
    export COS_ENDPOINT=$(echo $COS_ENDPOINTS | jq -r '.["service-endpoints"].regional["'$REGION'"].private["'$REGION'"]')
  else
    export COS_ENDPOINT=$(echo $COS_ENDPOINTS | jq -r '.["service-endpoints"].regional["'$REGION'"].direct["'$REGION'"]')
  fi
  export COS_ENDPOINT_PIPELINE=$(echo $COS_ENDPOINTS | jq -r '.["service-endpoints"].regional["'$REGION'"].public["'$REGION'"]')
fi

echo "COS_ENDPOINT=$COS_ENDPOINT"
check_value "$COS_ENDPOINT"

if [ -z "$COS_IBMAUTHENDPOINT" ]; then
  echo "COS_IBMAUTHENDPOINT was not set, finding value from $COS_ENDPOINTS_URL"
  export COS_IBMAUTHENDPOINT=https://$(echo $COS_ENDPOINTS | jq -r '.["identity-endpoints"]["iam-token"]')/oidc/token
fi
echo "COS_IBMAUTHENDPOINT=$COS_IBMAUTHENDPOINT"
check_value "$COS_IBMAUTHENDPOINT"

# we previously deleted the service key, but it is required for the ImagePull secret and needs to be valid
#ibmcloud iam service-api-key-delete $BASENAME-serviceID-API-key $SERVICE_ID -f

if check_exists "$(ibmcloud iam service-api-key $BASENAME-serviceID-API-key $SERVICE_ID 2>&1)"; then
  echo "API key already exists, deleting it"
  ibmcloud iam service-api-key-delete $BASENAME-serviceID-API-key $SERVICE_ID -f
fi
API_KEY_OUT=$(ibmcloud iam service-api-key-create $BASENAME-serviceID-API-key $SERVICE_ID -d "API key for $SERVICE_ID_NAME" --force --output json)
API_KEY_VALUE=$(echo "$API_KEY_OUT" | jq -r '.apikey')

#
# App ID
#
section "App ID"
APPID_INSTANCE_ID=$(get_instance_id sfsappid)
APPID_GUID=$(get_guid sfsappid)
echo "APPID_INSTANCE_ID=$APPID_INSTANCE_ID"
echo "APPID_GUID=$APPID_GUID"
check_value "$APPID_INSTANCE_ID"
check_value "$APPID_GUID"


APPID_CREDENTIALS=$(ibmcloud resource service-key $BASENAME-accKey-appid)
APPID_MANAGEMENT_URL=$(echo "$APPID_CREDENTIALS" | grep managementUrl  | awk '{ print $2 }')
APPID_API_KEY=$(echo "$APPID_CREDENTIALS" | sort | grep "apikey:" -m 1 | awk '{ print $2 }')
APPID_ACCESS_TOKEN=$(get_access_token $APPID_API_KEY)

# Set the redirect URL on App ID
if [ -z ${VPC} ]; then
  INGRESS_SUBDOMAIN=$(echo $CLUSTER_INFO | jq -r 'select(.ingressHostname) | .ingressHostname')
else
  INGRESS_SUBDOMAIN=$(echo $CLUSTER_INFO | jq -r 'select(.ingress.hostname) | .ingress.hostname')
fi
echo "INGRESS_SUBDOMAIN=$INGRESS_SUBDOMAIN"
check_value "$INGRESS_SUBDOMAIN"

curl -X PUT \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "Authorization: Bearer $APPID_ACCESS_TOKEN" \
  -d '{ "redirectUris": [ "https://secure-file-storage.'$INGRESS_SUBDOMAIN'/redirect_uri" ] }' \
  $APPID_MANAGEMENT_URL/config/redirect_uris

#
# Deploy our app
#
section "Kubernetes"

if [ -z ${VPC} ]; then
  INGRESS_SECRET=$(echo $CLUSTER_INFO | jq -r 'select(.ingressSecretName) | .ingressSecretName')
else
  INGRESS_SECRET=$(echo $CLUSTER_INFO | jq -r 'select(.ingress.secretName) | .ingress.secretName')
fi

# we need to create an Ingress secret if deploying to non-default namespace
if [ "$TARGET_NAMESPACE" != "default" ]; then
  INGRESS_SECRET_IN_NAMESPACE=$(ibmcloud ks ingress secret ls -c $PIPELINE_KUBERNETES_CLUSTER_NAME --output json | jq -r '.[] | select(.namespace=="'$TARGET_NAMESPACE'" and .name=="'$INGRESS_SECRET'").name')
  if [ "$INGRESS_SECRET" == "$INGRESS_SECRET_IN_NAMESPACE" ] ; then
    echo "copied Ingress secret exists"
  else
    echo "copying Ingress secret to namespace $TARGET_NAMESPACE"
    INGRESS_SECRET_CRN=$(ibmcloud ks ingress secret get -c $PIPELINE_KUBERNETES_CLUSTER_NAME -n default --name $INGRESS_SECRET --output json | jq -r .crn)
    ibmcloud ks ingress secret create -c $PIPELINE_KUBERNETES_CLUSTER_NAME -n $TARGET_NAMESPACE --name $INGRESS_SECRET --cert-crn $INGRESS_SECRET_CRN
  fi
fi
echo "INGRESS_SECRET=${INGRESS_SECRET}"
check_value "$INGRESS_SECRET"

if kubectl get namespace $TARGET_NAMESPACE; then
  echo "Namespace $TARGET_NAMESPACE already exists"
else
  echo "Creating namespace $TARGET_NAMESPACE..."
  kubectl create namespace $TARGET_NAMESPACE || exit 1
fi

#
# Create a secret in the cluster holding the credentials for Cloudant, COS, and App ID
#
if kubectl get secret $BASENAME-credentials --namespace "$TARGET_NAMESPACE"; then
  kubectl delete secret $BASENAME-credentials --namespace "$TARGET_NAMESPACE"
fi

kubectl create secret generic $BASENAME-credentials \
  --from-literal="cos_endpoint=$COS_ENDPOINT" \
  --from-literal="cos_ibmAuthEndpoint=$COS_IBMAUTHENDPOINT" \
  --from-literal="cos_apiKey=$COS_APIKEY" \
  --from-literal="cos_resourceInstanceId=$COS_RESOURCE_INSTANCE_ID" \
  --from-literal="cos_access_key_id=$COS_ACCESS_KEY_ID" \
  --from-literal="cos_secret_access_key=$COS_SECRET_ACCESS_KEY" \
  --from-literal="cos_bucket_name=$COS_BUCKET_NAME" \
  --from-literal="cloudant_url=$CLOUDANT_URL" \
  --from-literal="cloudant_iam_apikey=$CLOUDANT_IAM_APIKEY" \
  --from-literal="cloudant_database=$CLOUDANT_DATABASE" \
  --from-literal="appid_oauth_server_url=$APPID_OAUTH_SERVER_URL" \
  --from-literal="appid_tenant_id=$APPID_TENANT_ID" \
  --from-literal="appid_client_id=$APPID_CLIENT_ID" \
  --from-literal="appid_secret=$APPID_SECRET" \
  --from-literal="appid_app_url=https://secure-file-storage.$INGRESS_SUBDOMAIN" \
  --namespace "$TARGET_NAMESPACE" || exit 1

#
# Create a policy, then a secret to access the registry
#
if kubectl get secret $BASENAME-docker-registry --namespace $TARGET_NAMESPACE; then
  kubectl delete secret $BASENAME-docker-registry --namespace "$TARGET_NAMESPACE"
fi
kubectl --namespace $TARGET_NAMESPACE create secret docker-registry $BASENAME-docker-registry \
    --docker-server=${REGISTRY_URL} \
    --docker-username=iamapikey \
    --docker-password=${API_KEY_VALUE} \
    --docker-email="${TARGET_USER}" || exit 1


#
# Deploy the app
#

# uncomment the imagePullSecrets
cp secure-file-storage.template.yaml secure-file-storage.yaml
sed -i 's/#      imagePullSecrets:/      imagePullSecrets:/g' secure-file-storage.yaml
sed -i 's/#        - name: $IMAGE_PULL_SECRET/        - name: $IMAGE_PULL_SECRET/g' secure-file-storage.yaml

cat secure-file-storage.yaml | \
  IMAGE_NAME=$IMAGE_NAME \
  INGRESS_SECRET=$INGRESS_SECRET \
  INGRESS_SUBDOMAIN=$INGRESS_SUBDOMAIN \
  IMAGE_PULL_SECRET=$BASENAME-docker-registry \
  IMAGE_REPOSITORY=$IMAGE_REPOSITORY \
  TARGET_NAMESPACE=$TARGET_NAMESPACE \
  BASENAME=$BASENAME \
  APPID_INSTANCE=sfsappid \
  envsubst '$APPID_INSTANCE $IMAGE_NAME $INGRESS_SECRET $INGRESS_SUBDOMAIN $IMAGE_PULL_SECRET $IMAGE_REPOSITORY $TARGET_NAMESPACE $BASENAME' \
  | \
  kubectl apply --namespace $TARGET_NAMESPACE -f - || exit 1

echo "Your app is available at https://secure-file-storage.$INGRESS_SUBDOMAIN/"
