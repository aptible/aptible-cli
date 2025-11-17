
export COMPOSE_IGNORE_ORPHANS ?= true

build:
	docker compose build --pull

bash: build
	$(MAKE) run CMD=bash

CMD ?= bash
run:
	docker compose run cli $(CMD)

test: build
	$(MAKE) test-direct ARGS="$(ARGS)"

test-direct:
	docker compose run cli bundle exec rake $(ARGS)

down:
	docker compose down --remove-orphans $(ARGS)

.PHONY: build bash test