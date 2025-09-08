#!/bin/bash

# Reflex SDK Release Script
# Usage: ./scripts/release.sh [version] [tag]
# Example: ./scripts/release.sh 1.0.0 latest

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
VERSION=${1:-}
TAG=${2:-latest}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
    print_error "This script must be run from the SDK directory"
    exit 1
fi

# Check if version is provided
if [ -z "$VERSION" ]; then
    print_error "Version is required"
    echo "Usage: $0 <version> [tag]"
    echo "Example: $0 1.0.0 latest"
    exit 1
fi

# Validate version format (basic semver check)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9\.-]+)?$ ]]; then
    print_error "Invalid version format. Use semantic versioning (e.g., 1.0.0, 1.0.0-beta.1)"
    exit 1
fi

print_status "Starting release process for version $VERSION with tag '$TAG'"

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    print_warning "Working directory is not clean. Uncommitted changes:"
    git status --short
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Release cancelled"
        exit 1
    fi
fi

# Run tests and build
print_status "Running linting..."
npm run lint

print_status "Running tests..."
npm test

print_status "Building SDK..."
npm run build

# Update version in package.json
print_status "Updating version to $VERSION..."
npm version $VERSION --no-git-tag-version

# Dry run publish
print_status "Running dry-run publish..."
npm run publish:dry

# Confirm before publishing
print_warning "About to publish @reflex-mev/sdk@$VERSION with tag '$TAG'"
read -p "Continue with publishing? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Release cancelled"
    # Revert version change
    git checkout -- package.json
    exit 1
fi

# Publish to NPM
print_status "Publishing to NPM..."
if [ "$TAG" = "latest" ]; then
    npm publish
else
    npm publish --tag $TAG
fi

print_success "Successfully released @reflex-mev/sdk@$VERSION!"
print_status "NPM package: https://www.npmjs.com/package/@reflex-mev/sdk"

# Show next steps
echo
print_status "Next steps:"
echo "1. Check NPM package: https://www.npmjs.com/package/@reflex-mev/sdk"
echo "2. Update documentation if needed"
echo "3. Announce the release"
