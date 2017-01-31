UID=$(shell id -u $(USER))

init:
	git submodule update --init
build: init
	UID=$(UID) docker-compose build
setup: build
	docker-compose up -d db
	sleep 5
	docker-compose run --rm --no-deps web bin/setup
up: build
	docker-compose up -d db
	sleep 5
	docker-compose up -d
restart:
	docker-compose restart web spring worker
