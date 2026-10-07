.PHONY: help codegen watch clean get build analyze test format

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

get: ## Install dependencies
	flutter pub get

codegen: ## Generate code (freezed, json_serializable, riverpod)
	flutter pub run build_runner build --delete-conflicting-outputs

watch: ## Watch for changes and regenerate code automatically
	flutter pub run build_runner watch --delete-conflicting-outputs

clean: ## Clean build artifacts and generated files
	flutter clean
	flutter pub get
	$(MAKE) codegen

build: ## Build the app (debug mode)
	flutter build apk --debug

analyze: ## Run static analysis
	flutter analyze

test: ## Run all tests
	flutter test

format: ## Format all Dart files
	dart format lib test

l10n: ## Generate localization files
	flutter gen-l10n

outdated: ## Check for outdated dependencies
	flutter pub outdated

upgrade: ## Upgrade dependencies (minor versions only)
	flutter pub upgrade

upgrade-major: ## Upgrade dependencies (including major versions)
	flutter pub upgrade --major-versions

dev: get codegen ## Setup development environment
	@echo "✅ Development environment ready!"

all: clean get codegen analyze test ## Run full build pipeline
	@echo "✅ All tasks completed!"
