# BambooHR CLI Makefile

BINARY_NAME = bamboohr-cli
SOURCE_FILE = src/bamboohr_clock_corrected.cr

.PHONY: build run clean install test test-verbose test-integration help

# Default target
all: build

# Build the application
build:
	@echo "🔨 Building BambooHR CLI..."
	shards build
	@echo "✅ Build complete: ./bin/$(BINARY_NAME)"

# Build optimized release version
release:
	@echo "🚀 Building optimized release..."
	shards build --production --release --no-debug
	@echo "✅ Release build complete: ./bin/$(BINARY_NAME)"

# Run the application directly from source
run:
	@echo "🏃 Running from source..."
	crystal run $(SOURCE_FILE)

# Run the compiled binary
start: build
	@echo "🚀 Starting BambooHR CLI..."
	./bin/$(BINARY_NAME)

# Run tests
test:
	@echo "🧪 Running tests..."
	crystal spec
	@echo "✅ Tests complete"

# Run tests with verbose output
test-verbose:
	@echo "🧪 Running tests (verbose)..."
	crystal spec --verbose
	@echo "✅ Tests complete"

# Run integration tests (requires environment variables)
test-integration:
	@echo "🧪 Running integration tests..."
	@echo "⚠️  Make sure BAMBOOHR_* environment variables are set"
	INTEGRATION_TEST=true crystal spec --tag integration
	@echo "✅ Integration tests complete"

# Run tests and show coverage (if available)
test-coverage:
	@echo "🧪 Running tests with coverage..."
	crystal spec --verbose --junit_output=test_results.xml
	@echo "✅ Tests complete with coverage"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf bin/
	rm -f test_results.xml
	@echo "✅ Clean complete"

# Install to /usr/local/bin (requires sudo)
install: release
	@echo "📦 Installing to /usr/local/bin..."
	sudo cp ./bin/$(BINARY_NAME) /usr/local/bin/
	@echo "✅ Installed successfully"

# Development setup
setup:
	@echo "🔧 Setting up development environment..."
	@echo "📋 Checking Crystal installation..."
	crystal --version
	@echo "📋 Installing dependencies..."
	shards install
	@echo "✅ Setup complete"

# Show help
help:
	@echo "BambooHR CLI Build Commands:"
	@echo ""
	@echo "  make build           - Build the application (uses shards build)"
	@echo "  make release         - Build optimized release version"
	@echo "  make run             - Run directly from source"
	@echo "  make start           - Build and run the binary"
	@echo "  make test            - Run unit tests"
	@echo "  make test-verbose    - Run tests with verbose output"
	@echo "  make test-integration- Run integration tests (needs env vars)"
	@echo "  make test-coverage   - Run tests with coverage report"
	@echo "  make clean           - Remove build artifacts"
	@echo "  make install         - Install to /usr/local/bin"
	@echo "  make setup           - Setup development environment"
	@echo "  make help            - Show this help message"
	@echo ""
	@echo "Binary location: ./bin/bamboohr-cli"
