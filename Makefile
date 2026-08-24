.PHONY: help dev build test lint migrate-up migrate-down migrate-create proto docker-build clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev: ## Start docker-compose and run backend with hot reload (requires air)
	docker-compose up -d
	air -c .air.toml

build: ## Compile Go binary
	go build -o bin/miigho cmd/server/main.go

test: ## Run all Go tests with race detector and coverage
	go test -race -cover ./...

lint: ## Run golangci-lint
	golangci-lint run ./...

migrate-up: ## Run database migrations up
	migrate -path migrations -database "postgres://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}?sslmode=disable" up

migrate-down: ## Run database migrations down
	migrate -path migrations -database "postgres://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}?sslmode=disable" down

migrate-create: ## Create a new database migration file (usage: make migrate-create NAME=init)
	migrate create -ext sql -dir migrations -seq $(NAME)

proto: ## Compile protobuf files
	protoc --go_out=. --go_opt=paths=source_relative \
	       --go-grpc_out=. --go-grpc_opt=paths=source_relative \
	       proto/*.proto

docker-build: ## Build production Docker image
	docker build -t miigho-backend:latest -f deploy/Dockerfile .

clean: ## Clean build artifacts
	rm -rf bin/
	go clean
