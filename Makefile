.DEFAULT_GOAL := help

# Enable users to override the golang used to accommodate custom installations
GO ?= go

# CGO_ENABLED=0 is not FIPS compliant. Large commercial vendors and FedRAMP require FIPS compliant crypto
CGO_ENABLED := 1

# Version information for build metadata
git_sha:=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
git_dirty:=$(shell git diff --quiet 2>/dev/null || echo "-modified")
build_version:=$(git_sha)$(git_dirty)
build_time:=$(shell date -u '+%Y-%m-%d %H:%M:%S UTC')
ldflags=-X github.com/openshift-hyperfleet/adapter-landing-zone/pkg/version.Version=$(build_version) -X 'github.com/openshift-hyperfleet/adapter-landing-zone/pkg/version.BuildTime=$(build_time)'

# Test output format
ifndef TEST_SUMMARY_FORMAT
	TEST_SUMMARY_FORMAT=short-verbose
endif

# Prints a list of useful targets.
help:
	@echo ""
	@echo "adapter-landing-zone - GCP Environment Preparation Adapter"
	@echo ""
	@echo "make verify               verify source code"
	@echo "make lint                 run golangci-lint"
	@echo "make binary               compile binary"
	@echo "make install              compile and install binary in GOPATH bin"
	@echo "make test                 run unit tests"
	@echo "make test-helm            run helm chart tests (placeholder)"
	@echo "make test-integration     run integration tests"
	@echo "make clean                delete temporary generated files"
	@echo "$(fake)"
.PHONY: help

# Checks if a GOPATH is set, or emits an error message
check-gopath:
ifndef GOPATH
	$(error GOPATH is not set)
endif
.PHONY: check-gopath

# Verifies that source passes standard checks.
verify: check-gopath
	${GO} vet ./cmd/... ./pkg/...
	! gofmt -l cmd pkg test | sed 's/^/Unformatted file: /' | grep .
.PHONY: verify

# Runs linter to verify that everything is following best practices
lint:
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "golangci-lint not found. Install it with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
		exit 1; \
	fi
.PHONY: lint

# Build binary
binary: check-gopath
	echo "Building version: ${build_version}"
	CGO_ENABLED=$(CGO_ENABLED) GOEXPERIMENT=boringcrypto ${GO} build -ldflags="$(ldflags)" -o adapter-landing-zone ./cmd/adapter-landing-zone
.PHONY: binary

# Install binary
install: check-gopath
	CGO_ENABLED=$(CGO_ENABLED) GOEXPERIMENT=boringcrypto ${GO} install -ldflags="$(ldflags)" ./cmd/adapter-landing-zone
.PHONY: install

# Run unit tests
#
# Args:
#   TESTFLAGS: Flags to pass to `go test`. The `-v` argument is always passed.
#
# Examples:
#   make test TESTFLAGS="-run TestSomething"
test: check-gopath
	@if command -v gotestsum >/dev/null 2>&1; then \
		gotestsum --format $(TEST_SUMMARY_FORMAT) -- -p 1 -v $(TESTFLAGS) ./pkg/... ./cmd/...; \
	else \
		${GO} test -p 1 -v $(TESTFLAGS) ./pkg/... ./cmd/...; \
	fi
.PHONY: test

# Run helm chart tests (placeholder for CI/CD pipeline)
test-helm:
	@echo "Helm chart tests not yet implemented"
	@echo "This is a placeholder command to unblock pre-submit jobs"
	@exit 0
.PHONY: test-helm

# Run integration tests
#
# Args:
#   TESTFLAGS: Flags to pass to `go test`. The `-v` argument is always passed.
#
# Example:
#   make test-integration
#   make test-integration TESTFLAGS="-run TestGCPSetup"
test-integration: check-gopath
	@if command -v gotestsum >/dev/null 2>&1; then \
		gotestsum --format $(TEST_SUMMARY_FORMAT) -- -p 1 -v -timeout 1h $(TESTFLAGS) ./test/integration; \
	else \
		${GO} test -p 1 -v -timeout 1h $(TESTFLAGS) ./test/integration; \
	fi
.PHONY: test-integration

# Delete temporary files
clean:
	rm -rf \
		adapter-landing-zone \
		*.log \
		coverage.out
.PHONY: clean

# Format source code
fmt:
	gofmt -w cmd pkg test
.PHONY: fmt
