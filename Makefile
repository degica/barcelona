build:
	docker-compose build
setup: build
	docker-compose up -d spring db
	sleep 5
	docker-compose run web bin/setup
up: build
	docker-compose up -d db
	sleep 5
	docker-compose up -d
