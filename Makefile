.PHONY: help dev build test migrate clean test-integration test-backend-all

# Go parameters
GOCMD  := go
GOBUILD := $(GOCMD) build
GOTEST := $(GOCMD) test
GOFMT := $(GOCMD) fmt
GOMOD := $(GOCMD) mod

# Directories
BACKEND_DIR := backend
FRONTEND_DIR := frontend

# Docker
DOCKER := docker compose

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Development ──────────────────────────────────────

dev: ## Start all services (postgres, redis, minio, chrome)
	$(DOCKER) up -d postgres redis minio chrome
	@echo "Services started. Run 'make dev-server' and 'make dev-worker' in separate terminals."

dev-server: ## Run backend server with hot-reload
	cd $(BACKEND_DIR) && $(GOCMD) run ./cmd/server

dev-worker: ## Run background worker
	cd $(BACKEND_DIR) && $(GOCMD) run ./cmd/worker

dev-frontend: ## Run Flutter frontend
	cd $(FRONTEND_DIR) && flutter run

# ── Build ────────────────────────────────────────────

build: build-server build-worker ## Build all binaries

build-server: ## Build server binary
	cd $(BACKEND_DIR) && $(GOBUILD) -o ./bin/server ./cmd/server

build-worker: ## Build worker binary
	cd $(BACKEND_DIR) && $(GOBUILD) -o ./bin/worker ./cmd/worker

# ── Database ─────────────────────────────────────────

migrate: ## Run database migrations
	cd $(BACKEND_DIR) && $(GOCMD) run ./cmd/migrate

migrate-create: ## Create a new migration (usage: make migrate-create name=xxx)
	@read -p "Migration name: " name; \
	migrate create -ext sql -dir $(BACKEND_DIR)/db/migrations -seq $$name

# ── Code Generation ──────────────────────────────────

generate: ## Run all code generation
	cd $(BACKEND_DIR) && sqlc generate
	cd $(FRONTEND_DIR) && dart run build_runner build --delete-conflicting-outputs

generate-sqlc: ## Generate sqlc Go code
	cd $(BACKEND_DIR) && sqlc generate

generate-drift: ## Generate Drift Dart code
	cd $(FRONTEND_DIR) && dart run build_runner build --delete-conflicting-outputs

# ── Test ─────────────────────────────────────────────

test: test-backend test-frontend ## Run all tests

test-backend: ## Run backend tests
	cd $(BACKEND_DIR) && $(GOTEST) ./... -v -count=1

test-frontend: ## Run frontend tests
	cd $(FRONTEND_DIR) && flutter test

test-integration: ## Run integration tests (requires Docker)
	cd $(BACKEND_DIR) && $(GOTEST) -tags=integration -v -count=1 ./internal/repository/ ./internal/handler/

test-backend-all: test-backend test-integration ## Run all backend tests (unit + integration)

# ── Coverage ─────────────────────────────────────────

coverage-backend: ## Generate backend test coverage report
	cd $(BACKEND_DIR) && $(GOTEST) ./... -race -count=1 -coverprofile=coverage.out -covermode=atomic
	@cd $(BACKEND_DIR) && $$(GOCMD) tool cover -func=coverage.out | grep total
	@echo "Detailed report: cd backend && go tool cover -html=coverage.out -o coverage.html"

coverage-frontend: ## Generate frontend test coverage report
	cd $(FRONTEND_DIR) && flutter test --coverage
	@echo "Coverage data: frontend/coverage/lcov.info"

# ── Release ──────────────────────────────────────────

release: ## Create a release (usage: make release bump=patch|minor|major)
	@bash scripts/release.sh $(or $(bump),patch)

# ── Formatting ───────────────────────────────────────

fmt: ## Format all code
	cd $(BACKEND_DIR) && $(GOFMT) ./...
	cd $(FRONTEND_DIR) && dart format lib/

lint: ## Lint all code
	cd $(BACKEND_DIR) && golangci-lint run
	cd $(FRONTEND_DIR) && dart analyze

# ── Docker ───────────────────────────────────────────

docker-up: ## Start all containers
	$(DOCKER) up -d

docker-down: ## Stop all containers
	$(DOCKER) down

docker-logs: ## Tail container logs
	$(DOCKER) logs -f

docker-reset: ## Reset all containers and volumes
	$(DOCKER) down -v
	$(DOCKER) up -d

# ── Clean ────────────────────────────────────────────

clean: ## Clean build artifacts
	rm -rf $(BACKEND_DIR)/bin
	cd $(FRONTEND_DIR) && flutter clean

# ── Flutter Setup ────────────────────────────────────

flutter-init: ## Initialize Flutter project (run once)
	cd $(FRONTEND_DIR) && flutter pub get

flutter-build: ## Build Flutter release
	cd $(FRONTEND_DIR) && flutter build apk --release
