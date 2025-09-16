#!/usr/bin/env bash
set -euo pipefail

# Load env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

TAG=${1:-$(git rev-parse --short HEAD)}
NS=${K8S_NAMESPACE}
IMAGE="${DOCKER_IMAGE_REPO}:${TAG}"

kubectl apply -f k8s/namespace.yaml || true

# Apply deployments and service, replacing PLACEHOLDER with actual image
for f in k8s/deployment-blue.yaml k8s/deployment-green.yaml k8s/service.yaml; do
  sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" "$f" | kubectl apply -n ${NS} -f -
done

# Detect current version
CURRENT=$(kubectl -n ${NS} get svc myapp -o jsonpath='{.spec.selector.version}' || echo "none")
if [ "$CURRENT" = "blue" ]; then
  TARGET=green
else
  TARGET=blue
fi

echo "Deploying image ${IMAGE} to ${TARGET}"

# Update target deployment image
kubectl -n ${NS} set image deployment/myapp-${TARGET} myapp=${IMAGE} --record

kubectl -n ${NS} rollout status deployment/myapp-${TARGET} --timeout=180s

# Switch service
kubectl -n ${NS} patch svc myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"$TARGET\"}}}"

echo "Traffic switched to $TARGET using image ${IMAGE}"
