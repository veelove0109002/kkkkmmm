#!/usr/bin/env bash
#
# Exit immediately if a command exits with a non-zero status
set -e

# Function to display help message
show_help() {
    echo "Usage: $0 [options] -r <remote_ip>"
    echo
    echo "Required:"
    echo "  -r, --remote <remote_ip>   Remote host IP address"
    echo
    echo "Optional:"
    echo "  -u, --user <remote_user>   Remote username (default: root)"
    echo "      --run-go-tests         Run go tests"
    echo "      --run-go-tests-only    Run go tests and exit"
    echo "      --skip-ui-build        Skip frontend/UI build"
    echo "      --skip-native-build    Skip native build"
    echo "      --disable-docker       Disable docker build"
    echo "  -i, --install              Build for release and install the app"
    echo "      --help                 Display this help message"
    echo
    echo "Example:"
    echo "  $0 -r 192.168.0.17"
    echo "  $0 -r 192.168.0.17 -u admin"
}

# Default values
SCRIPT_PATH=$(realpath "$(dirname $(realpath "${BASH_SOURCE[0]}"))")
REMOTE_USER="root"
REMOTE_PATH="/userdata/jetkvm/bin"
SKIP_UI_BUILD=false
SKIP_UI_BUILD_RELEASE=0
SKIP_NATIVE_BUILD=0
RESET_USB_HID_DEVICE=false
LOG_TRACE_SCOPES="${LOG_TRACE_SCOPES:-jetkvm,cloud,websocket,native,jsonrpc}"
RUN_GO_TESTS=false
RUN_GO_TESTS_ONLY=false
INSTALL_APP=false
BUILD_IN_DOCKER=true
DOCKER_BUILD_DEBUG=false
DOCKER_BUILD_TAG=ghcr.io/jetkvm/buildkit:latest

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--remote)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --skip-ui-build)
            SKIP_UI_BUILD=true
            shift
            ;;
        --skip-native-build)
            SKIP_NATIVE_BUILD=1
            shift
            ;;
        --reset-usb-hid)
            RESET_USB_HID_DEVICE=true
            shift
            ;;
        --disable-docker)
            BUILD_IN_DOCKER=false
            shift
            ;;
        --docker-build-debug)
            DOCKER_BUILD_DEBUG=true
            shift
            ;;
        --run-go-tests)
            RUN_GO_TESTS=true
            shift
            ;;
        --run-go-tests-only)
            RUN_GO_TESTS_ONLY=true
            RUN_GO_TESTS=true
            shift
            ;;
        -i|--install)
            INSTALL_APP=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

source ${SCRIPT_PATH}/build_utils.sh

# Verify required parameters
if [ -z "$REMOTE_HOST" ]; then
    msg_err "Error: Remote IP is a required parameter"
    show_help
    exit 1
fi

# check if the current CPU architecture is x86_64
CURRENT_ARCH=$(uname -m)
if [ "$CURRENT_ARCH" = "x86_64" ]; then
    msg_info "Detected X86_64 architecture"
    # Set target architecture for X86 builds
    export TARGET_ARCH=x86_64
    BUILD_IN_DOCKER=false
elif [ "$CURRENT_ARCH" = "aarch64" ] || [ "$CURRENT_ARCH" = "arm64" ]; then
    msg_info "Detected ARM64 architecture"
    export TARGET_ARCH=arm
    BUILD_IN_DOCKER=true
else
    msg_warn "Warning: Unsupported architecture: $CURRENT_ARCH"
    msg_warn "Defaulting to ARM build in Docker"
    export TARGET_ARCH=arm
    BUILD_IN_DOCKER=true
fi

if [ "$BUILD_IN_DOCKER" = true ]; then
    build_docker_image
fi

# Build the development version on the host
# When using `make build_release`, the frontend will be built regardless of the `SKIP_UI_BUILD` flag
# check if static/index.html exists
if [[ "$SKIP_UI_BUILD" = true && ! -f "static/index.html" ]]; then
    msg_warn "static/index.html does not exist, forcing UI build"
    SKIP_UI_BUILD=false
fi

if [[ "$SKIP_UI_BUILD" = false && "$JETKVM_INSIDE_DOCKER" != 1 ]]; then 
    msg_info "▶ Building frontend"
    make frontend SKIP_UI_BUILD=0
    SKIP_UI_BUILD_RELEASE=1
fi

if [[ "$SKIP_UI_BUILD_RELEASE" = 0 && "$BUILD_IN_DOCKER" = true ]]; then
    msg_info "UI build is skipped when building in Docker"
    SKIP_UI_BUILD_RELEASE=1
fi

if [ "$RUN_GO_TESTS" = true ]; then
    msg_info "▶ Building go tests"
    make build_dev_test  

    msg_info "▶ Copying device-tests.tar.gz to remote host"
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "cat > /tmp/device-tests.tar.gz" < device-tests.tar.gz

    msg_info "▶ Running go tests"
    ssh "${REMOTE_USER}@${REMOTE_HOST}" ash << 'EOF'
set -e
TMP_DIR=$(mktemp -d)
cd ${TMP_DIR}
tar zxf /tmp/device-tests.tar.gz
./gotestsum --format=testdox \
    --jsonfile=/tmp/device-tests.json \
    --post-run-command 'sh -c "echo $TESTS_FAILED > /tmp/device-tests.failed"' \
    --raw-command -- ./run_all_tests -json

GOTESTSUM_EXIT_CODE=$?
if [ $GOTESTSUM_EXIT_CODE -ne 0 ]; then
    echo "❌ Tests failed (exit code: $GOTESTSUM_EXIT_CODE)"
    rm -rf ${TMP_DIR} /tmp/device-tests.tar.gz
    exit 1
fi

TESTS_FAILED=$(cat /tmp/device-tests.failed)
if [ "$TESTS_FAILED" -ne 0 ]; then
    echo "❌ Tests failed $TESTS_FAILED tests failed"
    rm -rf ${TMP_DIR} /tmp/device-tests.tar.gz
    exit 1
fi

echo "✅ Tests passed"
rm -rf ${TMP_DIR} /tmp/device-tests.tar.gz
EOF

    if [ "$RUN_GO_TESTS_ONLY" = true ]; then
        msg_info "▶ Go tests completed"
        exit 0
    fi
fi

if [ "$INSTALL_APP" = true ]
then
	msg_info "▶ Building release binary"
	do_make build_release SKIP_NATIVE_IF_EXISTS=${SKIP_NATIVE_BUILD} SKIP_UI_BUILD=${SKIP_UI_BUILD_RELEASE}
	
	# Copy the binary to the remote host as if we were the OTA updater.
	ssh "${REMOTE_USER}@${REMOTE_HOST}" "cat > /userdata/jetkvm/jetkvm_app.update" < bin/jetkvm_app
	
	# Reboot the device, the new app will be deployed by the startup process.
	ssh "${REMOTE_USER}@${REMOTE_HOST}" "reboot"
else
	msg_info "▶ Building development binary"
	do_make build_dev SKIP_NATIVE_IF_EXISTS=${SKIP_NATIVE_BUILD} SKIP_UI_BUILD=${SKIP_UI_BUILD_RELEASE}
	
	# Kill any existing instances of the application
	ssh "${REMOTE_USER}@${REMOTE_HOST}" "killall jetkvm_app_debug || true"
	
	# Copy the binary to the remote host
	ssh "${REMOTE_USER}@${REMOTE_HOST}" "cat > ${REMOTE_PATH}/jetkvm_app_debug" < bin/jetkvm_app
	
	if [ "$RESET_USB_HID_DEVICE" = true ]; then
	msg_info "▶ Resetting USB HID device"
	msg_warn "The option has been deprecated and will be removed in a future version, as JetKVM will now reset USB gadget configuration when needed"
	# Remove the old USB gadget configuration
	ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -rf /sys/kernel/config/usb_gadget/jetkvm/configs/c.1/hid.usb*"
	ssh "${REMOTE_USER}@${REMOTE_HOST}" "ls /sys/class/udc > /sys/kernel/config/usb_gadget/jetkvm/UDC"
	fi
	
	# Deploy and run the application on the remote host
	ssh "${REMOTE_USER}@${REMOTE_HOST}" ash << EOF
set -e

# Set the library path to include the directory where librockit.so is located
export LD_LIBRARY_PATH=/oem/usr/lib:\$LD_LIBRARY_PATH

# Kill any existing instances of the application
killall jetkvm_app || true
killall jetkvm_app_debug || true

# Navigate to the directory where the binary will be stored
cd "${REMOTE_PATH}"

# Make the new binary executable
chmod +x jetkvm_app_debug

# Run the application in the background
PION_LOG_TRACE=${LOG_TRACE_SCOPES} ./jetkvm_app_debug | tee -a /tmp/jetkvm_app_debug.log
EOF
fi

echo "Deployment complete."
