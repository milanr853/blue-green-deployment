#!/usr/bin/env bash
set -euo pipefail

# Usage:
# ./deploy-bluegreen.sh <registry-host:port> <image-tag>
# Example: ./deploy-bluegreen.sh localhost:5000 abc123

REGISTRY=${1:-localhost:5000}
TAG=${2:-latest}
NS=bluegreen
IMAGE=${REGISTRY}/myapp:${TAG}

# ensure ns exists
kubectl apply -f namespace.yaml -n ${NS} || true

echo "Ensuring namespace exists..."
kubectl apply -f namespace.yaml

# create deployments and service if not present (with placeholder image)
echo "Applying k8s manifests (if first run, placeholders will be replaced)..."
# Replace IMAGE_PLACEHOLDER in files and apply
for f in deployment-blue.yaml deployment-green.yaml service.yaml; do
  sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" "$f" | kubectl apply -n ${NS} -f -
done

# Determine current version from service selector
CURRENT=$(kubectl -n ${NS} get svc myapp -o jsonpath='{.spec.selector.version}' || echo "none")
if [ "$CURRENT" = "blue" ]; then
  TARGET=green
else
  TARGET=blue
fi

echo "Current service selector: $CURRENT. Deploying image to $TARGET"

# Update target deployment image (container name must match 'myapp' in manifest)
kubectl -n ${NS} set image deployment/myapp-${TARGET} myapp=${IMAGE} --record

echo "Waiting for rollout..."
kubectl -n ${NS} rollout status deployment/myapp-${TARGET} --timeout=120s

echo "Patching service to point to $TARGET..."
kubectl -n ${NS} patch svc myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"$TARGET\"}}}"

echo "Traffic switched to $TARGET (image: ${IMAGE})"

