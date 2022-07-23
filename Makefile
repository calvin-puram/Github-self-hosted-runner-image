DOCKER_USER ?= calvinpuram
DIND_RUNNER_NAME ?= ${DOCKER_USER}/actions-runner-dind
TAG ?= latest
TARGETPLATFORM ?= $(shell arch)

RUNNER_VERSION ?= 2.294.0
DOCKER_VERSION ?= 20.10.12


docker-build-ubuntu:
	docker build \
	  --build-arg TARGETPLATFORM=${TARGETPLATFORM} \
	  --build-arg RUNNER_VERSION=${RUNNER_VERSION} \
	  --build-arg DOCKER_VERSION=${DOCKER_VERSION} \
	  -f actions-runner-dind.dockerfile \
	  -t ${DIND_RUNNER_NAME}:${TAG} .

docker-push-ubuntu:
	docker push ${DIND_RUNNER_NAME}:${TAG}

