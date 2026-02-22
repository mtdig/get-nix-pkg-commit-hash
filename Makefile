SCRIPT      := get-nix-pkg-commit-hash.sh
VERSION_FILE := $(SCRIPT)

# Extract current version from the script header
CURRENT_VERSION := $(shell grep '^# Version:' $(VERSION_FILE) | awk '{print $$NF}')

.PHONY: help test changelog version bump-patch bump-minor bump-major release tag

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

test: ## Run tests
	./test.sh

version: ## Show current version
	@echo $(CURRENT_VERSION)

changelog: ## Generate CHANGELOG.md from git tags and commits
	git cliff --output CHANGELOG.md

preview: ## Preview unreleased changelog to stdout
	git cliff --unreleased

next-version: ## Show what the next version would be (based on commits)
	@git cliff --bumped-version

bump-patch: ## Bump patch version (1.0.0 -> 1.0.1)
	$(call bump,patch)

bump-minor: ## Bump minor version (1.0.0 -> 1.1.0)
	$(call bump,minor)

bump-major: ## Bump major version (1.0.0 -> 2.0.0)
	$(call bump,major)

release: ## Auto-bump based on conventional commits, tag, and generate changelog
	@NEW_VERSION=$$(git cliff --bumped-version) && \
	echo "Releasing $$NEW_VERSION (was $(CURRENT_VERSION))..." && \
	sed -i "s/^# Version:       .*/# Version:       $${NEW_VERSION#v}/" $(VERSION_FILE) && \
	sed -i "s/^# Last modified: .*/# Last modified: $$(date +%Y-%m-%d)/" $(VERSION_FILE) && \
	git cliff --tag $$NEW_VERSION --output CHANGELOG.md && \
	git add $(VERSION_FILE) CHANGELOG.md && \
	git commit -m "chore(release): prepare for $$NEW_VERSION" && \
	git tag -a $$NEW_VERSION -m "$$NEW_VERSION" && \
	echo "Done. Run 'make push' to publish."

push: ## Push commits and tags to origin
	git push origin main --tags

tag: ## Create a git tag for the current version
	git tag -a v$(CURRENT_VERSION) -m "v$(CURRENT_VERSION)"

# ── helper ────────────────────────────────────────────────────────────
define bump
	@IFS='.' read -r major minor patch <<< "$(CURRENT_VERSION)"; \
	case "$(1)" in \
		patch) patch=$$((patch + 1)) ;; \
		minor) minor=$$((minor + 1)); patch=0 ;; \
		major) major=$$((major + 1)); minor=0; patch=0 ;; \
	esac; \
	NEW="$$major.$$minor.$$patch"; \
	echo "$(CURRENT_VERSION) -> $$NEW"; \
	sed -i "s/^# Version:       .*/# Version:       $$NEW/" $(VERSION_FILE); \
	sed -i "s/^# Last modified: .*/# Last modified: $$(date +%Y-%m-%d)/" $(VERSION_FILE)
endef
