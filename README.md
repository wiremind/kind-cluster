# kind-cluster

This repository defines the unofficial [kind](https://github.com/kubernetes-sigs/kind) docker image.

* [docker 24-dind](docker/24-dind)

which are published to [ghcr.io](https://github.com/wiremind/kind-cluster/pkgs/container/kind-cluster).


__note__ - requires latest docker to be installed and available

## Using Images

### pull docker image

```bash
docker pull ghcr.io/wiremind/kind-cluster:latest
```

### run docker image

```bash
docker run --rm --name kind-cluster --privileged -p 10080:10080 -p 8443:8443 ghcr.io/wiremind/kind-cluster:latest
```

### building docker image

```bash
docker build -t kind-cluster:local docker/24-dind
```

## Contacting kind cluster

### Retrieve kube config
```bash
mkdir -p $HOME/.kube
curl http://127.0.0.1:10080/config > $HOME/.kube/config
```

### API server
```bash
curl -k https://127.0.0.1:8443
```

## Configuring your CI
```yaml
.compose-test-kind-cluster:
  variables:
    # https://github.com/kubernetes-sigs/kind/releases
    KIND_CLUSTER_VERSION: v0.20.0
    KINDEST_NODE_IMAGE_TAG: v1.26.6@sha256:6e2d8b28a5b601defe327b98bd1c2d1930b49e5d8c512e1895099e4504007adb

    # Access URL to retrieve kube config
    KUBE_CONFIG_URL: http://${CI_JOB_ID}-kind-cluster:10080/config
  services:
    - name: ghcr.io/wiremind/kind-cluster:${KIND_CLUSTER_VERSION}
      alias: ${CI_JOB_ID}-kind-cluster
      variables:
        # Kubernetes related
        KUBERNETES_MEMORY_REQUEST: 512Mi
        KUBERNETES_MEMORY_LIMIT: 2Gi
        KUBERNETES_CPU_LIMIT: 3
        KUBERNETES_SERVICE_MEMORY_REQUEST: 512Mi
        KUBERNETES_SERVICE_MEMORY_LIMIT: 4Gi
        KUBERNETES_SERVICE_CPU_LIMIT: 3

        # Container image related
        DOCKER_USER: "myuser"
        DOCKER_PASSWORD: "mypassword"
        CLUSTER_NAME: "kind"

.platform-e2e-test:
  stage: test
  image: $DOCKER_TEST_IMAGE
  tags:
    - end2end-tests-platform
  extends:
    - .compose-test-kind-cluster
  services:
    - !reference [.compose-test-kind-cluster, services]
  before_script:
    - echo -e "\e[0Ksection_start:`date +%s`:test_setup[collapsed=true]\r\e[0KSetting up tests..."
    - until $(curl --output /dev/null --silent --head --fail ${KUBE_CONFIG_URL}); do echo "Waiting for kind cluster to come up online (${KUBE_CONFIG_URL})..."; sleep 5; done
    - mkdir -p $HOME/.kube && curl "${KUBE_CONFIG_URL}" > $HOME/.kube/config && chmod 600 $HOME/.kube/config
    - echo -e "\e[0Ksection_end:`date +%s`:test_setup\r\e[0K"
  script:
    - kubectl get nodes && kubectl get pods
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

## Add Extra Nodes

Define the environment variable :
```bash
CLUSTER_EXTRA_NODES="
  - role: worker
  - role: worker
  - role: worker"
```

## Private Registry

An access to GitLab private registry is possible with the environment variables :`$CI_REGISTRY` `$CI_REGISTRY_USER` and `$CI_REGISTRY_PASSWORD`.
the variables are predefined.

For a custom private registry, an access is possible by providing the variables : `$CI_CUSTOM_REGISTRY` `$CI_CUSTOM_REGISTRY_USER` and `$CI_CUSTOM_REGISTRY_PASSWORD`.