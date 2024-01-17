#!/bin/bash

set -e
set -o pipefail

if [[ -z "$INGRESS_SUBDOMAIN" ]]; then
  echo "INGRESS_SUBDOMAIN must be in the environment"
  exit 1
fi

if [[ -z "$IMAGE_REPOSITORY" ]]; then
  echo "IMAGE_REPOSITORY must be in the environment"
  exit 1
fi

if [[ -z "$INGRESS_SECRET" ]]; then
  echo "INGRESS_SECRET must be in the environment"
  exit 1
fi

if [[ -z "$BASENAME" ]]; then
  export BASENAME=secure-file-storage
fi

if [[ -z "$TARGET_NAMESPACE" ]]; then
  export TARGET_NAMESPACE=default
fi

cat secure-file-storage.template.yaml | \
  envsubst '$IMAGE_PULL_SECRET $IMAGE_REPOSITORY $TARGET_NAMESPACE $BASENAME' > secure-file-storage.yaml


if [[ -z "$MYDOMAIN" ]]; then
  cat secure-file-storage-ingress.template.yaml | \
    envsubst '$INGRESS_SECRET $INGRESS_SUBDOMAIN $TARGET_NAMESPACE $BASENAME' > secure-file-storage-ingress.yaml
  exit
fi

cat secure-file-storage-ingress.template.yaml | \
  sed -e 's/^# //' |
  envsubst '$MYDOMAIN $INGRESS_SECRET $INGRESS_SUBDOMAIN $TARGET_NAMESPACE $BASENAME' > secure-file-storage-ingress.yaml
