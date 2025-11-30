# Makefile for DriftHound

setup:
	bundle install
	bin/rails db:drop db:create db:migrate db:seed

start:
	bin/rails server

docker-run-tests:
	docker compose up -d
	docker compose exec app bin/rails test

docker-db-setup:
	docker compose up -d
	docker compose exec app bin/rails db:drop db:create db:migrate db:seed

docker-start:
	docker compose up --build -d

docker-token:
	docker compose exec app bin/rails api_tokens:generate[my-ci-token]

docker-stop:
	docker compose down

docker-destroy:
	docker compose down -v

test:
	bin/rails test
