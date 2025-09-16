#!/usr/bin/env bash
set -euo pipefail

# Load env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

TAG=${1:-$(git rev-parse --short HEAD)}
NS=bluegreen
IMAGE="${DOCKER_IMAGE_REPO}:${TAG}"

# Ensure namespace exists
kubectl get ns ${NS} >/dev/null 2>&1 || kubectl create ns ${NS}

# Apply base manifests (namespace, deployments, service)
for f in k8s/namespace.yml k8s/deployment-blue.yml k8s/deployment-green.yml k8s/service.yml; do
  if [ -f "$f" ]; then
    # Replace image placeholder dynamically
    sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" "$f" | kubectl apply -n ${NS} -f -
  else
    echo "⚠️  Warning: File $f not found, skipping."
  fi
done

# Detect current version from Service selector
CURRENT=$(kubectl -n ${NS} get svc myapp -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")
if [ "$CURRENT" = "blue" ]; then
  TARGET=green
else
  TARGET=blue
fi

echo "🚀 Deploying image ${IMAGE} to ${TARGET}"

# Update target deployment image
kubectl -n ${NS} set image deployment/myapp-${TARGET} myapp=${IMAGE} --record

# Wait for rollout
kubectl -n ${NS} rollout status deployment/myapp-${TARGET} --timeout=180s

# Switch service to new version
kubectl -n ${NS} patch svc myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"$TARGET\"}}}"

echo "✅ Traffic switched to $TARGET using image ${IMAGE}"
