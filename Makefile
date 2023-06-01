DOCKER_DEFAULT_PLATFORM=linux/amd64
init:
	git submodule update --init
build: init
	docker-compose build
setup: build
	docker-compose run --rm web bash -c 'export MAKE="make -j `nproc`" && bundle install -j `nproc`'
	docker-compose run --rm web bundle exec bin/setup
	docker-compose stop
	docker-compose down
up: init
	docker-compose up -d
restart:
	docker-compose restart web worker
