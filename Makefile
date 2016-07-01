machine:
	docker-machine create --driver virtualbox --virtualbox-memory "2048" default
	docker-machine start
	echo "To use docker, run this command: eval "$(docker-machine env)""
init:
	git submodule update --init
build: init
	docker-compose build
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
