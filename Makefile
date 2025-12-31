.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: validate
validate: ## Validate all YAML manifests
	@echo " Validating YAML files..."
	@find . -name "*.yaml" -o -name "*.yml" | xargs yamllint -c .yamllint || true

.PHONY: lint-docker
lint-docker: ## Lint all Dockerfiles
	@echo " Linting Dockerfiles..."
	@find docker -name "Dockerfile*" -exec hadolint {} \;

.PHONY: test
test: ## Run all tests
	@echo " Running tests..."
	@cd tests && pytest -v

.PHONY: install-tools
install-tools: ## Install development tools
	@echo " Installing development tools..."
	pip install yamllint
	pip install pytest
	apt-get install -y shellcheck

.PHONY: git-status
git-status: ## Show git status
	@git status
	@echo ""
	@echo "Current branch: $$(git branch --show-current)"

.PHONY: tree
tree: ## Show directory structure
	@tree -L 3 -I '.git|__pycache__|*.pyc'
