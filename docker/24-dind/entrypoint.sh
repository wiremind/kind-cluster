#!/bin/bash

echo "Starting docker daemon..."

while ! docker ps; do
    echo "Waiting for docker daemon..."

    dockerd-entrypoint.sh dockerd >/var/log/dockerd.log 2>&1 &

    sleep 1
done

echo "Docker daemon started"

# We login using an account in order to avoid Docker Hub rate limiting
# https://www.docker.com/increase-rate-limits
if [ -n "$DOCKER_USER" ] && [ -n "$DOCKER_PASSWORD" ]; then
    echo "Logging to docker hub with user ${DOCKER_USER}"
    docker login -u "${DOCKER_USER}" -p "${DOCKER_PASSWORD}"
fi

if [ -n "$CI_REGISTRY" ] && [ -n "$CI_REGISTRY_USER" ] && [ -n "$CI_REGISTRY_PASSWORD" ]; then
    echo "Logging to ${CI_REGISTRY} with user ${CI_REGISTRY_USER}"
    docker login $CI_REGISTRY -u "${CI_REGISTRY_USER}" -p "${CI_REGISTRY_PASSWORD}"
fi

if [ -n "$CI_CUSTOM_REGISTRY" ] && [ -n "$CI_CUSTOM_REGISTRY_USER" ] && [ -n "$CI_CUSTOM_REGISTRY_PASSWORD" ]; then
    echo "Logging to ${CI_CUSTOM_REGISTRY} with user ${CI_REGISTRY_USER}"
    docker login $CI_CUSTOM_REGISTRY -u "${CI_CUSTOM_REGISTRY_USER}" -p "${CI_CUSTOM_REGISTRY_PASSWORD}"
fi

if [ -z "$CLUSTER_NAME" ]; then
    export CLUSTER_NAME="kind"
    echo "Defaulting cluster name to ${CLUSTER_NAME}"
fi

if [ -z "$API_SERVER_ADDRESS" ]; then
    export API_SERVER_ADDRESS="0.0.0.0"
    echo "Defaulting api server address to ${API_SERVER_ADDRESS}"
fi

if [ -z "$API_SERVER_PORT" ]; then
    export API_SERVER_PORT="8443"
    echo "Defaulting api server port to ${API_SERVER_PORT}"
fi

if [ -z "$KINDEST_NODE_IMAGE_TAG" ]; then
    export KINDEST_NODE_IMAGE_TAG="v1.26.6"
    echo "Defaulting kindest node image tag to ${KINDEST_NODE_IMAGE_TAG}"
fi

kind_version="$(kind --version)"
export KIND_VERSION="$kind_version"

function finish {
    echo "Cleaning up docker resources"
    kind delete cluster --name "$CLUSTER_NAME"
    docker kill "$(docker ps -q)"
    docker volume prune -f | true
}
trap finish EXIT
trap finish INT

# Substitute environment variables to create final configuration file
envsubst </app/kind.yaml >/etc/kind.yaml
echo "Kind (${KIND_VERSION}) cluster will be created with the following configuration:"
cat /etc/kind.yaml

# Create cluster
kind create cluster --config /etc/kind.yaml --wait "180s"

# Expose kube config so that other containers can use it
chmod +rx -R "$HOME/.kube"
docker run --rm -v "$HOME/.kube":/usr/share/nginx/html:ro -p 10080:8080 ghcr.io/nginxinc/nginx-unprivileged:1.25.2
