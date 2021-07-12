#!/bin/bash

set -e
set -o pipefail

if [[ -z "$INGRESS_SUBDOMAIN" ]]; then
  echo "Ingress subdomain cannot be empty"
fi

if [[ -z "$IMAGE_REPOSITORY" ]]; then
  echo "Image repository cannot be empty"
fi

if [[ -z "$INGRESS_SECRET" ]]; then
  echo "Ingress secret cannot be empty"
fi

if [[ -z "$BASENAME" ]]; then
  BASENAME=secure-file-storage
fi

if [[ -z "$TARGET_NAMESPACE" ]]; then
  TARGET_NAMESPACE=default
fi

cat secure-file-storage.template.yaml | \
  INGRESS_SUBDOMAIN=$INGRESS_SUBDOMAIN \
  INGRESS_SECRET=$INGRESS_SECRET \
  IMAGE_REPOSITORY=$IMAGE_REPOSITORY \
  BASENAME=$BASENAME \
  TARGET_NAMESPACE=$TARGET_NAMESPACE \
  envsubst '$IMAGE_NAME $INGRESS_SECRET $INGRESS_SUBDOMAIN $IMAGE_PULL_SECRET $IMAGE_REPOSITORY $TARGET_NAMESPACE $BASENAME' > secure-file-storage.yaml
  #| \
  #oc apply -f - || exit 1