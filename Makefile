export USER_NAME  := $(shell id -un)
export USER_UID   := $(shell id -u)
export USER_GID   := $(shell id -g)
export ROS_DISTRO ?= jazzy

COMPOSE        := docker compose
DEV_CONTAINER  := adore
ZSH_HISTORY    := .zsh_history
IMAGE_SAVE_DIR := build/images
PACKAGE_NAME   := adore-$(shell git rev-parse --short HEAD 2>/dev/null || echo dev).tar.gz

.PHONY: help
help:
	@if [ -t 1 ]; then \
		BOLD="\033[1m"; CYAN="\033[36m"; YELLOW="\033[33m"; RESET="\033[0m"; \
	else \
		BOLD=""; CYAN=""; YELLOW=""; RESET=""; \
	fi; \
	printf "$${BOLD}Usage:$${RESET} make $${CYAN}<target>$${RESET}\n\n"; \
	grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
		| awk -v c="$$CYAN" -v y="$$YELLOW" -v r="$$RESET" \
		  'BEGIN {FS = ":.*##"} {printf "  %s%-12s%s %s\n", c, $$1, r, $$2}'


DOCKER_COLCON_RUN = docker run --rm \
	-v "$(shell pwd):/home/$(USER_NAME)/adore" \
	-w "/home/$(USER_NAME)/adore/" \
	-e ROS_DISTRO=$(ROS_DISTRO) \
	adore_dev:latest \
	make -f /home/$(USER_NAME)/adore/colcon.mk

.PHONY: build
build: build-dev build-ci ## Build base, dev, and CI images
	bash docker/scripts/setup_colcon_src.sh
	$(DOCKER_COLCON_RUN) colcon_build

.PHONY: build-release
build-release: ## Build all ROS2 packages in Release mode inside the dev container
	$(DOCKER_COLCON_RUN) colcon_build_release

.PHONY: build-single-core
build-single-core: ## Build all ROS2 packages single-threaded inside the dev container
	$(DOCKER_COLCON_RUN) colcon_build_single_core

.PHONY: colcon-clean
colcon-clean: ## Clean colcon workspace build artifacts inside the dev container
	$(DOCKER_COLCON_RUN) colcon_clean

.PHONY: clean
clean: ## Remove adore containers and images
	$(COMPOSE) down --rmi local --remove-orphans 2>/dev/null || true
	@for repo in adore_dev adore_ci adore_base; do \
		ids=$$(docker images --format '{{.Repository}} {{.ID}}' | awk -v r="$$repo" '$$1==r{print $$2}'); \
		if [ -n "$$ids" ]; then \
			echo "Removing $$repo images: $$ids"; \
			docker rmi -f $$ids || true; \
		fi; \
	done

$(ZSH_HISTORY):
	touch $(ZSH_HISTORY)

.PHONY: start
start: $(ZSH_HISTORY) ## Start the dev container in the background
	$(COMPOSE) up -d dev

.PHONY: stop
stop: ## Stop the dev container
	$(COMPOSE) stop dev

.PHONY: cli
cli: start ## Attach to the running dev container
	docker exec -it \
		-w "/home/$(USER_NAME)/adore" \
		-e HISTFILE="/home/$(USER_NAME)/.zsh_history" \
		-e HISTSIZE=100000 \
		-e SAVEHIST=100000 \
		$(DEV_CONTAINER) \
		bash -lc " \
			source /opt/ros/$$ROS_DISTRO/setup.sh && \
			if [ -f .colcon_workspace/install/local_setup.sh ]; then \
				source .colcon_workspace/install/local_setup.sh; \
			fi && \
			exec zsh \
		"


.PHONY: build-base
build-base: ## Build only the base image
	docker build \
		-f docker/base/Dockerfile \
		-t adore_base:latest \
		.

.PHONY: build-dev
build-dev: build-base ## Build base + dev image
	docker build \
		-f docker/dev/Dockerfile \
		--build-arg USER_UID=$(USER_UID) \
		--build-arg USER_GID=$(USER_GID) \
		--build-arg USERNAME=$(USER_NAME) \
		-t adore_dev:latest \
		.

.PHONY: build-ci
build-ci: build-base ## Build base + CI image
	docker build \
		-f docker/ci/Dockerfile \
		--build-arg USER_UID=$(USER_UID) \
		--build-arg USER_GID=$(USER_GID) \
		--build-arg USERNAME=$(USER_NAME) \
		-t adore_ci:latest \
		.


.PHONY: ci
ci: ## Run the full CI suite (build + test + docs)
	$(COMPOSE) run --rm ci

.PHONY: docs
docs: ## Run docs generation only
	$(COMPOSE) run --rm docs


.PHONY: save
save: ## Save all Docker images to build/images/
	mkdir -p $(IMAGE_SAVE_DIR)
	@for img in adore_base adore_dev adore_ci; do \
		out="$(IMAGE_SAVE_DIR)/$$img.tar"; \
		echo "--- Saving $$img:latest -> $$out ---"; \
		docker save -o "$$out" "$$img:latest"; \
	done
	@echo "All images saved to $(IMAGE_SAVE_DIR)/"

.PHONY: load
load: ## Load all Docker images from build/images/
	@for img in adore_base adore_dev adore_ci; do \
		tar="$(IMAGE_SAVE_DIR)/$$img.tar"; \
		if [ ! -f "$$tar" ]; then \
			echo "ERROR: $$tar not found; run 'make save' first." >&2; \
			exit 1; \
		fi; \
		echo "--- Loading $$img from $$tar ---"; \
		docker load -i "$$tar"; \
	done

.PHONY: package
package: save ## Save images then create a tar.gz archive of the project
	@echo "--- Creating archive $(PACKAGE_NAME) ---"
	tar \
		--exclude='./.git' \
		--exclude='./$(PACKAGE_NAME)' \
		-czf "$(PACKAGE_NAME)" \
		.
	@echo "Package created: $(PACKAGE_NAME)"
