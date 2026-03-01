
export COMPOSE_IGNORE_ORPHANS ?= true
export RUBY_VERSION ?= 2.3.1
RUBY_VERSION_MAJOR = $(word 1,$(subst ., ,$(RUBY_VERSION)))
export BUNDLER_VERSION ?=
ifeq ($(BUNDLER_VERSION),)
ifeq ($(RUBY_VERSION_MAJOR),2)
export BUNDLER_VERSION = 1.17.3
endif
endif
export COMPOSE_PROJECT_NAME ?= aptible-cli-$(subst .,_,$(RUBY_VERSION))

## Build and pull docker compose images
build:
	docker compose build --pull

## Open shell in a docker container, supports CMD=
bash: build
	$(MAKE) run CMD=bash

CMD ?= bash
## Run command in a docker container, supports CMD=
run:
	docker compose run cli $(CMD)

## Run tests in a docker container, supports ARGS=
test: build
	$(MAKE) test-direct ARGS="$(ARGS)"

## Run tests in a docker container without building, supports ARGS=
test-direct:
	docker compose run cli bundle exec rake $(ARGS)

## Run rubocop in a docker container, supports ARGS=
lint: build
	$(MAKE) lint-direct ARGS="$(ARGS)"

## Run rubocop in a docker container without building, supports ARGS=
lint-direct:
	docker compose run cli bundle exec rake rubocop $(ARGS)

## Clean up docker compose resources
clean:
	docker compose down --remove-orphans --volumes

## Alias for clean
down: clean

sync-readme: build
	docker compose run cli bundle exec script/sync-readme-usage

## Show this help message
help:
	@echo "\n\033[1;34mAvailable targets:\033[0m\n"
	@awk 'BEGIN {FS = ":"; prev = ""} \
					/^## / {prev = substr($$0, 4); next} \
					/^[a-zA-Z_-]+:/ {if (prev != "") printf "  \033[1;36m%-20s\033[0m %s\n", $$1, prev; prev = ""} \
					{prev = ""}' $(MAKEFILE_LIST) | sort
	@echo

integration: build
	@echo "Running integration tests..."
	@echo "Set DEPLOY_API_URL to point to your running deploy-api instance"
	@echo "Set DEPLOY_API_TOKEN if authentication is required"
	docker compose run \
		-e DEPLOY_API_URL=${DEPLOY_API_URL} \
		-e DEPLOY_API_TOKEN=${DEPLOY_API_TOKEN} \
		cli bundle exec rspec --tag integration

.PHONY: build bash test integration
