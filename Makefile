SHELL:=/usr/bin/env bash

default: help
# via https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: bootstrap
bootstrap: ## Bootstrap dependencies via Carthage
	carthage bootstrap --platform macOS --no-use-binaries --use-xcframeworks

.PHONY: deps-update
deps-update: ## Update all dependencies via Carthage
	carthage update --platform macOS --no-use-binaries --use-xcframeworks
