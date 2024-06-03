build:
	docker compose build --pull

bash: build
	docker compose run cli bash

test: build
	docker compose run cli bundle exec rake

.PHONY: build bash test
