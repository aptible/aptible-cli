build:
	docker compose build --pull

bash: build
	docker compose run cli bash

test: build
	docker compose run cli bundle exec rake

integration: build
	@echo "Running integration tests..."
	@echo "Set DEPLOY_API_URL to point to your running deploy-api instance"
	@echo "Set DEPLOY_API_TOKEN if authentication is required"
	docker compose run \
		-e DEPLOY_API_URL=${DEPLOY_API_URL} \
		-e DEPLOY_API_TOKEN=${DEPLOY_API_TOKEN} \
		cli bundle exec rspec --tag integration

.PHONY: build bash test integration
