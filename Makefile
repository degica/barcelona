DOCKER_DEFAULT_PLATFORM=linux/amd64
init:
	git submodule update --init
build: init
	docker-compose build
setup: build
	docker-compose run --rm -e BUNDLE_IGNORE_CONFIG=true test bash -c 'export MAKE="make -j `nproc`" && bundle install -j `nproc`'
	docker-compose run --rm test bundle exec bin/setup
	docker-compose stop
up: init
	docker-compose up -d
restart:
	docker-compose restart web worker test
dbreset: down
	docker volume rm -f barcelona_pgdata
	docker-compose up -d
	docker-compose run --rm test bundle exec bin/setup
down:
	# make sure e2e process is not attached to this network
	docker ps -a | grep barcelona-e2e-e2e | cut -d' ' -f1 | xargs docker rm -f
	docker-compose down -t 0
bundle-reset: down
	docker volume rm -f barcelona_bundle
	docker volume ls
	docker-compose run --rm -e BUNDLE_IGNORE_CONFIG=true test bash -c 'export MAKE="make -j `nproc`" && bundle install -j `nproc`'
test:
	docker-compose run --rm -e RAILS_ENV=test test bundle exec rspec -f d