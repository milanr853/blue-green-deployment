#!/usr/bin/env bash
set -euo pipefail

# Load env file if exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Input TAG from CI/CD or default to git short SHA
TAG=${1:-$(git rev-parse --short HEAD)}
TARGET=${2:-}   # Deployment color (blue/green) from CI/CD
NS=bluegreen

# Make sure DOCKER_IMAGE_REPO is defined
if [ -z "${DOCKER_IMAGE_REPO:-}" ]; then
  echo "❌ DOCKER_IMAGE_REPO not set in env"
  exit 1
fi

if [ -z "$TARGET" ]; then
  echo "❌ Deployment color not provided (blue/green required)"
  exit 1
fi

IMAGE="${DOCKER_IMAGE_REPO}:${TAG}"

# Ensure namespace exists
kubectl get ns ${NS} >/dev/null 2>&1 || kubectl create ns ${NS}

echo "🚀 Deploying image ${IMAGE} to ${TARGET}"

# Apply only the chosen deployment + service
for f in k8s/deployment-${TARGET}.yml k8s/service.yml; do
  if [ -f "$f" ]; then
    sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" "$f" | kubectl apply --record -n ${NS} -f -
  else
    echo "⚠️  Warning: File $f not found, skipping."
  fi
done

# Wait for rollout (rollback if fails)
kubectl -n ${NS} rollout status deployment/myapp-${TARGET} --timeout=300s || \
kubectl -n ${NS} rollout undo deployment/myapp-${TARGET}

# Switch service to new version
kubectl -n ${NS} patch svc myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"$TARGET\"}}}"

echo "✅ Traffic switched to $TARGET using image ${IMAGE}"
