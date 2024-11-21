# Makefile

K3S_VERSION ?= v1.30.6-k3s1
IMAGE_NAME := k3s-service
GIT_HASH := $(shell git log --pretty=format:'%h' -1)

TAG := $(K3S_VERSION)
IMAGE_FILE_ALPINE := $(IMAGE_NAME).$(TAG).img
REMOTE_IMAGE_NAME := $(DOCKER_REGISTRY)/$(DOCKER_REPO)/$(IMAGE_NAME)
$(info $$(TAG) is [${TAG}])
$(info $$(RELEASE_BUILD) is [${RELEASE_BUILD}])

### Default rule for building locally ###

.PHONY: all
all:
	$(MAKE) build

$(IMAGE_FILE_ALPINE): k3s/Dockerfile.alpine
	docker build --rm \
		--build-arg K3S_VERSION="$(subst -,+,$(K3S_VERSION))" \
		-t "$(IMAGE_NAME):$(TAG)" -f $< k3s/

.PHONY: clean
clean:
	rm -f *.img

### Build contract ###

.PHONY: k3s-build
k3s-build: build-k3s-alpine

.PHONY: build-k3s-alpine
build-k3s-alpine: $(IMAGE_FILE_ALPINE)

K3S_SERVICE_NAME ?= k3s-service
export K3S_SERVICE_NAME
ifneq (, $(shell which docker))
K3S_SERVICE_RUN=$(shell docker ps -a --filter name=$(K3S_SERVICE_NAME) --format={{.Names}})
export K3S_SERVICE_RUN
$(info $$(K3S_SERVICE_RUN) is [${K3S_SERVICE_RUN}])
ifneq ($(K3S_SERVICE_RUN),)
K3S_SERVICE_HOST := $(shell docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(K3S_SERVICE_RUN))
$(info $$(K3S_SERVICE_HOST) is [${K3S_SERVICE_HOST}])
export K3S_SERVICE_HOST
endif
endif

K3S_SERVICE_PORT := 18081
K3S_REGISTRY_PORT := 5000
K3S_SERVICE_PORTS := 6443:6443 ${K3S_SERVICE_PORT}:${K3S_SERVICE_PORT} \
        $(K3S_REGISTRY_PORT):$(K3S_REGISTRY_PORT) 40000:40000 50000:50000 \
        $(K3S_CUSTOM_PORTS)

.PHONY: k3s-start
k3s-start:
ifneq ($(K3S_SERVICE_RUN),$(K3S_SERVICE_NAME))
	@docker run -d -p 6443:6443 -p 18081:18081 -p 5000:5000	\
		-e DOCKER_REGISTRY_HOST \
		--tmpfs /run --tmpfs /var/run \
		--privileged \
		--shm-size=2g \
		--name $(K3S_SERVICE_NAME) $(K3S_SERVICE_NAME):$(K3S_VERSION)
endif

KUBECONFIG_FILE ?= $(PWD)/envs/k3s/k3s.yaml
.PHONY: k3s-kubeconfig
k3s-kubeconfig:
	while [ "$$(curl -s -o /dev/null -w ''%{http_code}'' http://$(K3S_SERVICE_HOST):$(K3S_SERVICE_PORT)/k3s.yaml)" != "200" ];do sleep 3;done;
	curl $(K3S_SERVICE_HOST):$(K3S_SERVICE_PORT)/k3s.yaml -o $(KUBECONFIG_FILE);
	sed -i "s/127.0.0.1/$(K3S_SERVICE_HOST)/g" $(KUBECONFIG_FILE);
	@echo Run:
	export KUBECONFIG=$(KUBECONFIG_FILE)
k3s-stop:
ifneq ($(K3S_SERVICE_RUN),)
	@docker rm -f $(K3S_SERVICE_RUN)
endif

