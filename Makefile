DOCKER_DEFAULT_PLATFORM=linux/amd64
DOCKER_UID=$(shell id -u $(USER))

init:
	git submodule update --init
build: init
	DOCKER_DEFAULT_PLATFORM=linux/amd64 DOCKER_UID=$(DOCKER_UID) docker-compose build
setup: init
	DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose run --rm web bin/setup
up: init
	DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose up -d
restart:
	docker-compose restart web worker
