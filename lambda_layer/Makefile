.PHONY: build zip clean help

PYTHON_RUNTIME ?= 3.11

help:
	@echo "Lambda Layer Build Targets:"
	@echo "  make build      - Build the lambda layer using Docker"
	@echo "  make zip        - Create lambda_layer.zip"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make all        - Build and zip (same as: build zip)"

build:
	rm -rf python lambda_layer.zip
	@mkdir -p python
	@command -v docker >/dev/null 2>&1 || { echo "Docker is required for this build." >&2; exit 1; }
	@echo "Building with Docker for Python $(PYTHON_RUNTIME)..."
	@DOCKER_BUILDKIT=1 docker build --no-cache --build-arg PYTHON_RUNTIME=$(PYTHON_RUNTIME) --build-arg LAMBDA_TASK_ROOT=/var/task -t lambda-layer-builder .
	@container_id=$$(docker create lambda-layer-builder); \
		docker cp $$container_id:/python ./; \
		docker rm $$container_id
	@echo "✓ Layer built in ./python"

zip: 
	@echo "Creating zip file..."
	@zip -r lambda_layer.zip python
	@echo "✓ Lambda layer created: lambda_layer.zip"
	@ls -lh lambda_layer.zip

all: build zip

clean:
	rm -rf python lambda_layer.zip __pycache__
	@echo "✓ Cleaned up build artifacts"
