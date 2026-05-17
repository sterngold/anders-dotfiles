# Polyglot Makefile — override per repo as needed.
# Targets are mandatory: install, build, test, lint, fmt.

.PHONY: install build test lint fmt clean

install: ## Install deps
	@if [ -f pyproject.toml ];  then uv sync; fi
	@if [ -f package.json ];    then npm ci;  fi
	@if [ -f Package.swift ];   then swift package resolve; fi
	@pre-commit install --install-hooks || true

build: ## Build the project
	@if [ -f pyproject.toml ];  then uv run python -m build || true; fi
	@if [ -f package.json ];    then npm run build --if-present; fi
	@if [ -f Package.swift ];   then swift build; fi

test: ## Run tests
	@if [ -f pyproject.toml ];  then uv run pytest -q; fi
	@if [ -f package.json ];    then npm test --if-present; fi
	@if [ -f Package.swift ];   then swift test; fi

lint: ## Lint + typecheck
	@if [ -f pyproject.toml ];  then uv run ruff check . && uv run ruff format --check .; fi
	@if [ -f package.json ];    then npm run lint --if-present; fi

fmt: ## Auto-format
	@if [ -f pyproject.toml ];  then uv run ruff format . && uv run ruff check --fix .; fi
	@if [ -f package.json ];    then npx prettier --write . 2>/dev/null || true; fi

clean:
	rm -rf .pytest_cache .ruff_cache .mypy_cache dist build node_modules .next out .build DerivedData
