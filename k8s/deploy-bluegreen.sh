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

# ---------------------------
# Build BLUE and GREEN images
# ---------------------------
echo "📦 Building BLUE image..."
docker build \
  --build-arg VITE_DEPLOYMENT_COLOR=blue \
  --build-arg VITE_APP_VERSION=$TAG \
  -t ${DOCKER_IMAGE_REPO}:blue-${TAG} .

echo "📦 Building GREEN image..."
docker build \
  --build-arg VITE_DEPLOYMENT_COLOR=green \
  --build-arg VITE_APP_VERSION=$TAG \
  -t ${DOCKER_IMAGE_REPO}:green-${TAG} .

echo "🚀 Pushing images..."
docker push ${DOCKER_IMAGE_REPO}:blue-${TAG}
docker push ${DOCKER_IMAGE_REPO}:green-${TAG}

# ---------------------------
# Ensure namespace exists
# ---------------------------
kubectl get ns ${NS} >/dev/null 2>&1 || kubectl create ns ${NS}

# ---------------------------
# Apply base manifests
# ---------------------------
for f in k8s/deployment-blue.yml k8s/deployment-green.yml k8s/service.yml; do
  if [ -f "$f" ]; then
    if [[ "$f" == *"deployment-blue.yml" ]]; then
      sed "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE_REPO}:blue-${TAG}|g" "$f" | kubectl apply -n ${NS} -f -
    elif [[ "$f" == *"deployment-green.yml" ]]; then
      sed "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE_REPO}:green-${TAG}|g" "$f" | kubectl apply -n ${NS} -f -
    else
      sed "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE_REPO}:blue-${TAG}|g" "$f" | kubectl apply -n ${NS} -f -
    fi
  else
    echo "⚠️  Warning: File $f not found, skipping."
  fi
done

# ---------------------------
# Detect current version from Service selector
# ---------------------------
CURRENT=$(kubectl -n ${NS} get svc myapp -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")
TARGET="blue"
if [ "$CURRENT" = "blue" ]; then
  TARGET="green"
elif [ "$CURRENT" = "green" ]; then
  TARGET="blue"
fi

echo "🚀 Rolling out ${TARGET} deployment with its image"

# Update target deployment image (already tagged per color)
kubectl -n ${NS} set image deployment/myapp-${TARGET} myapp=${DOCKER_IMAGE_REPO}:${TARGET}-${TAG}

# Wait for rollout
kubectl -n ${NS} rollout status deployment/myapp-${TARGET} --timeout=300s

# Switch service to new version
kubectl -n ${NS} patch svc myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"$TARGET\"}}}"

echo "✅ Traffic switched to $TARGET using image ${DOCKER_IMAGE_REPO}:${TARGET}-${TAG}"
