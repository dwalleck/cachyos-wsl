# CachyOS WSL Distribution Makefile
#
# This Makefile orchestrates the build of CachyOS WSL distributions.
# It runs the build script inside a CachyOS Docker container to ensure
# a clean, reproducible build environment.

.PHONY: help rootfs rootfs-v3 rootfs-v4 rootfs-znver4 clean distclean

# Configuration
DOCKER_IMAGE := cachyos/cachyos:latest
DOCKER_RUN := docker run --rm --privileged \
	-v $(CURDIR):/workspace \
	-w /workspace \
	$(DOCKER_IMAGE)

# Default target
help:
	@echo "CachyOS WSL Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make rootfs        - Build x86-64-v3 rootfs (default)"
	@echo "  make rootfs-v3     - Build x86-64-v3 rootfs"
	@echo "  make rootfs-v4     - Build x86-64-v4 rootfs"
	@echo "  make rootfs-znver4 - Build AMD Zen 4 optimized rootfs"
	@echo "  make clean         - Remove build artifacts"
	@echo "  make distclean     - Remove all build artifacts and dist directory"
	@echo ""
	@echo "The build runs inside a Docker container to ensure reproducibility."
	@echo "Output will be in: dist/"

# Default architecture: v3
rootfs: rootfs-v3

# Build v3 (x86-64-v3) rootfs
rootfs-v3:
	@echo "==> Building CachyOS WSL rootfs (x86-64-v3)..."
	@echo ""
	$(DOCKER_RUN) /workspace/build/build-rootfs.sh v3
	@echo ""
	@echo "==> Build complete! Output: dist/cachyos-v3-rootfs.tar.gz"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Rename to .wsl: mv dist/cachyos-v3-rootfs.tar.gz dist/cachyos-v3.wsl"
	@echo "  2. Test installation with PowerShell script"

# Build v4 (x86-64-v4) rootfs
rootfs-v4:
	@echo "==> Building CachyOS WSL rootfs (x86-64-v4)..."
	@echo ""
	$(DOCKER_RUN) /workspace/build/build-rootfs.sh v4
	@echo ""
	@echo "==> Build complete! Output: dist/cachyos-v4-rootfs.tar.gz"

# Build znver4 (AMD Zen 4) rootfs
rootfs-znver4:
	@echo "==> Building CachyOS WSL rootfs (AMD Zen 4)..."
	@echo ""
	$(DOCKER_RUN) /workspace/build/build-rootfs.sh znver4
	@echo ""
	@echo "==> Build complete! Output: dist/cachyos-znver4-rootfs.tar.gz"

# Clean build artifacts but keep dist directory
clean:
	@echo "==> Cleaning build artifacts..."
	rm -f dist/*.tar.gz
	rm -f dist/*.wsl
	@echo "==> Clean complete"

# Remove everything including dist directory
distclean: clean
	@echo "==> Removing dist directory..."
	rm -rf dist/
	@echo "==> Distclean complete"
