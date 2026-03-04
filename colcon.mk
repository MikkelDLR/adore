SHELL := /bin/bash

RAM_KB := $(shell grep MemTotal /proc/meminfo | awk '{print $$2}')
RAM_GB := $(shell echo $$(( $(RAM_KB) / 1024 / 1024 )))

ifeq ($(shell [ $(RAM_KB) -ge 8000000 ] && echo yes || echo no),yes)
  PARALLEL_WORKERS         := $(shell echo $$(( $$(nproc) - 1 )))
  PARALLEL_WORKERS_RELEASE := $(shell echo $$(( $$(nproc) - 2 )))
  EXECUTOR_ARG             := --parallel-workers $(PARALLEL_WORKERS)
  EXECUTOR_ARG_RELEASE     := --parallel-workers $(PARALLEL_WORKERS_RELEASE)
else
  EXECUTOR_ARG         := --executor sequential
  EXECUTOR_ARG_RELEASE := --executor sequential
endif

.PHONY: colcon_build
colcon_build: ## Build all ROS2 packages
	@echo "Detected RAM: $(RAM_KB) kB ($(RAM_GB) GB)"
	@echo "Executor: $(EXECUTOR_ARG)"
	source /opt/ros/$${ROS_DISTRO}/setup.bash && colcon build $(EXECUTOR_ARG)

.PHONY: colcon_build_release
colcon_build_release: ## Build all ROS2 packages in Release mode
	@echo "Detected RAM: $(RAM_KB) kB ($(RAM_GB) GB)"
	@echo "Executor: $(EXECUTOR_ARG_RELEASE)"
	source /opt/ros/$${ROS_DISTRO}/setup.bash && \
		colcon build $(EXECUTOR_ARG_RELEASE) --cmake-args -DCMAKE_BUILD_TYPE=Release && \
		source install/local_setup.sh

.PHONY: colcon_build_single_core
colcon_build_single_core: ## Build all ROS2 packages, force single-threaded regardless of RAM
	source /opt/ros/$${ROS_DISTRO}/setup.bash && colcon build --executor sequential

.PHONY: colcon_clean
colcon_clean: ## Clean the colcon workspace build artifacts
	rm -rf build/* log/* install/*
