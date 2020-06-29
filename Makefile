UID=$(shell id -u $(USER))

init:
	git submodule update --init
build: init
	UID=$(UID) docker-compose build
setup: init
	docker-compose run --rm web bin/setup
up: init
	docker-compose up -d
restart:
	docker-compose restart web worker
