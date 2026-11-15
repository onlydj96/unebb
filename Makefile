.PHONY: help get codegen watch clean build analyze test format format-check \
	functions-check check l10n outdated upgrade upgrade-major dev all

# Edge Function sources checked by `functions-check` (requires Deno 2).
FUNCTION_SOURCES := supabase/functions/*/index.ts supabase/functions/_shared/*.ts \
	supabase/functions/*/*_test.ts

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

get: ## Install dependencies
	flutter pub get

codegen: ## Generate code (freezed, json_serializable)
	dart run build_runner build --delete-conflicting-outputs

watch: ## Watch for changes and regenerate code automatically
	dart run build_runner watch --delete-conflicting-outputs

clean: ## Remove build artifacts (run `make dev` afterwards)
	flutter clean

build: ## Build the app (debug mode)
	flutter build apk --debug

analyze: ## Run static analysis
	flutter analyze

test: ## Run all Flutter tests
	flutter test

format: ## Format all Dart files
	dart format lib test

format-check: ## Fail if any Dart file is not formatted
	dart format --output=none --set-exit-if-changed lib test

functions-check: ## Type-check, lint and test the Edge Functions (needs Deno)
	deno check $(FUNCTION_SOURCES)
	deno lint supabase/functions
	deno test --allow-env supabase/functions

check: format-check analyze test functions-check ## Run the same checks as CI

l10n: ## Generate localization files
	flutter gen-l10n

outdated: ## Check for outdated dependencies
	flutter pub outdated

upgrade: ## Upgrade dependencies (minor versions only)
	flutter pub upgrade

upgrade-major: ## Upgrade dependencies (including major versions)
	flutter pub upgrade --major-versions

dev: get l10n codegen ## Setup development environment
	@echo "✅ Development environment ready!"

all: clean dev check ## Clean, install, generate, then run every check
	@echo "✅ All tasks completed!"
