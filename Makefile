BRANCH    := $(shell git rev-parse --abbrev-ref HEAD)
BUILDDATE := $(shell date -u +%FT%T%z)
BUILDTS   := $(shell date -u +%s)
REVISION  := $(shell git rev-parse HEAD)
VERSION_DEV := 0.4.9-dev$(shell date +%Y%m%d%H%M)
VERSION := 0.4.8

PROMETHEUS_TAG := github.com/prometheus/common/version
KVM_PKG_NAME := github.com/jetkvm/kvm

BUILDKIT_FLAVOR := arm-rockchip830-linux-uclibcgnueabihf
BUILDKIT_PATH ?= /opt/jetkvm-native-buildkit
SKIP_NATIVE_IF_EXISTS ?= 0
SKIP_UI_BUILD ?= 0
GO_BUILD_ARGS := -tags netgo,timetzdata,nomsgpack
GO_RELEASE_BUILD_ARGS := -trimpath $(GO_BUILD_ARGS)
GO_LDFLAGS := \
  -s -w \
  -X $(PROMETHEUS_TAG).Branch=$(BRANCH) \
  -X $(PROMETHEUS_TAG).BuildDate=$(BUILDDATE) \
  -X $(PROMETHEUS_TAG).Revision=$(REVISION) \
  -X $(KVM_PKG_NAME).builtTimestamp=$(BUILDTS)

# Support both ARM and X86 architectures
TARGET_ARCH ?= arm
ifeq ($(TARGET_ARCH),x86_64)
	GO_ARGS := GOOS=linux GOARCH=amd64 CGO_ENABLED=0
else ifeq ($(TARGET_ARCH),arm)
	GO_ARGS := GOOS=linux GOARCH=arm GOARM=7 ARCHFLAGS="-arch arm"
	# if BUILDKIT_PATH exists, use buildkit to build
	ifneq ($(wildcard $(BUILDKIT_PATH)),)
		GO_ARGS := $(GO_ARGS) \
			CGO_CFLAGS="-I$(BUILDKIT_PATH)/$(BUILDKIT_FLAVOR)/include -I$(BUILDKIT_PATH)/$(BUILDKIT_FLAVOR)/sysroot/usr/include" \
			CGO_LDFLAGS="-L$(BUILDKIT_PATH)/$(BUILDKIT_FLAVOR)/lib -L$(BUILDKIT_PATH)/$(BUILDKIT_FLAVOR)/sysroot/usr/lib -lrockit -lrockchip_mpp -lrga -lpthread -lm" \
			CC="$(BUILDKIT_PATH)/bin/$(BUILDKIT_FLAVOR)-gcc" \
			LD="$(BUILDKIT_PATH)/bin/$(BUILDKIT_FLAVOR)-ld" \
			CGO_ENABLED=1 
		# GO_RELEASE_BUILD_ARGS := $(GO_RELEASE_BUILD_ARGS) -x -work
	endif
else
	$(error Unsupported architecture: $(TARGET_ARCH). Use 'arm' or 'x86_64')
endif

GO_CMD := $(GO_ARGS) go

BIN_DIR := $(shell pwd)/bin

TEST_DIRS := $(shell find . -name "*_test.go" -type f -exec dirname {} \; | sort -u)

build_native:
	@if [ "$(SKIP_NATIVE_IF_EXISTS)" = "1" ] && [ -f "internal/native/cgo/lib/libjknative.a" ]; then \
		echo "libjknative.a already exists, skipping native build..."; \
	else \
		echo "Building native..."; \
		if [ "$(TARGET_ARCH)" = "x86_64" ]; then \
			TARGET_ARCH=x86_64 ./scripts/build_cgo.sh; \
		else \
			CC="$(BUILDKIT_PATH)/bin/$(BUILDKIT_FLAVOR)-gcc" \
			LD="$(BUILDKIT_PATH)/bin/$(BUILDKIT_FLAVOR)-ld" \
			./scripts/build_cgo.sh; \
		fi \
	fi

build_dev: build_native
	@echo "Building..."
	$(GO_CMD) build \
		-ldflags="$(GO_LDFLAGS) -X $(KVM_PKG_NAME).builtAppVersion=$(VERSION_DEV)" \
		$(GO_RELEASE_BUILD_ARGS) \
		-o $(BIN_DIR)/jetkvm_app -v ./cmd

build_test2json:
	$(GO_CMD) build -o $(BIN_DIR)/test2json cmd/test2json

build_gotestsum:
	@echo "Building gotestsum..."
	$(GO_CMD) install gotest.tools/gotestsum@latest
	cp $(shell $(GO_CMD) env GOPATH)/bin/linux_arm/gotestsum $(BIN_DIR)/gotestsum

build_dev_test: build_test2json build_gotestsum
# collect all directories that contain tests
	@echo "Building tests for devices ..."
	@rm -rf $(BIN_DIR)/tests && mkdir -p $(BIN_DIR)/tests

	@cat resource/dev_test.sh > $(BIN_DIR)/tests/run_all_tests
	@for test in $(TEST_DIRS); do \
		test_pkg_name=$$(echo $$test | sed 's/^.\///g'); \
		test_pkg_full_name=$(KVM_PKG_NAME)/$$(echo $$test | sed 's/^.\///g'); \
		test_filename=$$(echo $$test_pkg_name | sed 's/\//__/g')_test; \
		$(GO_CMD) test -v \
			-ldflags="$(GO_LDFLAGS) -X $(KVM_PKG_NAME).builtAppVersion=$(VERSION_DEV)" \
			$(GO_BUILD_ARGS) \
			-c -o $(BIN_DIR)/tests/$$test_filename $$test; \
		echo "runTest ./$$test_filename $$test_pkg_full_name" >> $(BIN_DIR)/tests/run_all_tests; \
	done; \
	chmod +x $(BIN_DIR)/tests/run_all_tests; \
	cp $(BIN_DIR)/test2json $(BIN_DIR)/tests/ && chmod +x $(BIN_DIR)/tests/test2json; \
	cp $(BIN_DIR)/gotestsum $(BIN_DIR)/tests/ && chmod +x $(BIN_DIR)/tests/gotestsum; \
	tar czfv device-tests.tar.gz -C $(BIN_DIR)/tests .

frontend:
	@if [ "$(SKIP_UI_BUILD)" = "1" ] && [ -f "static/index.html" ]; then \
		echo "Skipping frontend build..."; \
	else \
		cd ui && npm ci && npm run build:device && \
		find ../static/ -type f \
			\( -name '*.js' \
			-o -name '*.css' \
			-o -name '*.html' \
			-o -name '*.ico' \
			-o -name '*.png' \
			-o -name '*.jpg' \
			-o -name '*.jpeg' \
			-o -name '*.gif' \
			-o -name '*.svg' \
			-o -name '*.webp' \
			-o -name '*.woff2' \
			\) -exec sh -c 'gzip -9 -kfv {}' \; ;\
	fi

dev_release: frontend build_dev
	@echo "Uploading release... $(VERSION_DEV)"
	@shasum -a 256 bin/jetkvm_app | cut -d ' ' -f 1 > bin/jetkvm_app.sha256
	rclone copyto bin/jetkvm_app r2://jetkvm-update/app/$(VERSION_DEV)/jetkvm_app
	rclone copyto bin/jetkvm_app.sha256 r2://jetkvm-update/app/$(VERSION_DEV)/jetkvm_app.sha256

build_release: frontend build_native
	@echo "Building release..."
	$(GO_CMD) build \
		-ldflags="$(GO_LDFLAGS) -X $(KVM_PKG_NAME).builtAppVersion=$(VERSION)" \
		$(GO_RELEASE_BUILD_ARGS) \
		-o bin/jetkvm_app ./cmd

release:
	@if rclone lsf r2://jetkvm-update/app/$(VERSION)/ | grep -q "jetkvm_app"; then \
		echo "Error: Version $(VERSION) already exists. Please update the VERSION variable."; \
		exit 1; \
	fi
	make build_release
	@echo "Uploading release..."
	@shasum -a 256 bin/jetkvm_app | cut -d ' ' -f 1 > bin/jetkvm_app.sha256
	rclone copyto bin/jetkvm_app r2://jetkvm-update/app/$(VERSION)/jetkvm_app
	rclone copyto bin/jetkvm_app.sha256 r2://jetkvm-update/app/$(VERSION)/jetkvm_app.sha256