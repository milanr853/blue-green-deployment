#!/usr/bin/env bash
set -euo pipefail

# Load env file if exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Input TAG from CI/CD or default to git short SHA
TAG=${1:-$(git rev-parse --short HEAD)}
NS=bluegreen

# Make sure DOCKER_IMAGE_REPO is defined
if [ -z "${DOCKER_IMAGE_REPO:-}" ]; then
  echo "❌ DOCKER_IMAGE_REPO not set in env"
  exit 1
fi

IMAGE="${DOCKER_IMAGE_REPO}:${TAG}"

# Ensure namespace exists
kubectl get ns ${NS} >/dev/null 2>&1 || kubectl create ns ${NS}

# Apply base manifests (namespace, deployments, service)
for f in k8s/deployment-blue.yml k8s/deployment-green.yml k8s/service.yml; do
  if [ -f "$f" ]; then
    sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" "$f" | kubectl apply -n ${NS} -f -
  else
    echo "⚠️  Warning: File $f not found, skipping."
  fi
done

# Detect current version from Service selector
CURRENT=$(kubectl -n ${NS} get svc myapp -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")
TARGET="blue"
if [ "$CURRENT" = "blue" ]; then
  TARGET="green"
elif [ "$CURRENT" = "green" ]; then
  TARGET="blue"
fi

echo "🚀 Deploying image ${IMAGE} to ${TARGET}"

# Update target deployment image
kubectl -n ${NS} set image deployment/myapp-${TARGET} myapp=${IMAGE}

# Wait for rollout (increase timeout if needed)
kubectl -n ${NS} rollout status deployment/myapp-${TARGET} --timeout=300s

# Switch service to new version
kubectl -n ${NS} patch svc myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"$TARGET\"}}}"

echo "✅ Traffic switched to $TARGET using image ${IMAGE}"
