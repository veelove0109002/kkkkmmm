#!/bin/bash

# Build script for X86_64 hardware version with real HDMI capture
# This version enables actual video capture using V4L2

set -e

echo "Building JetKVM for X86_64 with hardware HDMI capture support..."

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Error: Hardware video capture is only supported on Linux"
    exit 1
fi

# Check for required dependencies
echo "Checking dependencies..."

# Check for V4L2 development headers
if ! pkg-config --exists libv4l2 2>/dev/null; then
    echo "Warning: libv4l2 development headers not found"
    echo "Install with: sudo apt-get install libv4l-dev"
fi

# Check for video devices
if ! ls /dev/video* >/dev/null 2>&1; then
    echo "Warning: No video devices found in /dev/"
    echo "Make sure your HDMI capture device is connected and recognized"
fi

# Set build environment
export CGO_ENABLED=1
export GOOS=linux
export GOARCH=amd64

# Build tags for hardware support
BUILD_TAGS="hardware"

echo "Building frontend..."
cd ui
npm ci
npm run build:device
cd ..

echo "Building Go application with hardware support..."
go build -tags="$BUILD_TAGS" -ldflags="-s -w" -o bin/jetkvm_x86_hardware ./cmd/jetkvm

echo "Build completed successfully!"
echo ""
echo "Hardware Requirements:"
echo "- Linux system with V4L2 support"
echo "- HDMI capture device (USB or PCIe)"
echo "- Video device accessible at /dev/video0, /dev/video1, etc."
echo ""
echo "Usage:"
echo "  sudo ./bin/jetkvm_x86_hardware"
echo ""
echo "Note: Root privileges may be required for video device access"

# Create a simple test script
cat > test_video_devices.sh << 'EOF'
#!/bin/bash

echo "Testing video devices..."

for device in /dev/video*; do
    if [ -c "$device" ]; then
        echo "Found video device: $device"
        
        # Try to get device info
        if command -v v4l2-ctl >/dev/null 2>&1; then
            echo "  Device info:"
            v4l2-ctl --device="$device" --info 2>/dev/null | head -5 || echo "    Could not get device info"
            echo "  Supported formats:"
            v4l2-ctl --device="$device" --list-formats 2>/dev/null | head -10 || echo "    Could not list formats"
        else
            echo "  Install v4l-utils for detailed device information: sudo apt-get install v4l-utils"
        fi
        echo ""
    fi
done

if ! ls /dev/video* >/dev/null 2>&1; then
    echo "No video devices found!"
    echo "Common solutions:"
    echo "1. Connect your HDMI capture device"
    echo "2. Load USB Video Class driver: sudo modprobe uvcvideo"
    echo "3. Check dmesg for device recognition: dmesg | grep -i video"
fi
EOF

chmod +x test_video_devices.sh

echo "Created test_video_devices.sh - run this to check your video devices"