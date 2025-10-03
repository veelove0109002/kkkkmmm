# JetKVM X86_64 Hardware Support

This document describes how to build and use JetKVM on X86_64 systems with real HDMI capture hardware.

## Overview

Unlike the simulation version, this build provides actual HDMI video capture using V4L2 (Video4Linux2) interface. This allows you to use JetKVM with real HDMI capture devices on X86_64 Linux systems.

## Hardware Requirements

### HDMI Capture Device
You need a HDMI capture device that appears as a V4L2 video device. Compatible devices include:

- **USB HDMI Capture Cards**:
  - Elgato Cam Link 4K
  - AVerMedia Live Gamer Ultra
  - EVGA XR1 Lite
  - Generic USB 3.0 HDMI capture devices

- **PCIe HDMI Capture Cards**:
  - Blackmagic DeckLink series
  - AVerMedia Live Gamer HD 2
  - Magewell Pro Capture series

### System Requirements
- Linux system (Ubuntu 20.04+ recommended)
- V4L2 support in kernel
- USB 3.0 port (for USB capture devices)
- Sufficient CPU for video processing

## Installation

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install build-essential pkg-config libv4l-dev v4l-utils

# CentOS/RHEL/Fedora
sudo yum install gcc make pkgconfig libv4l-devel v4l-utils
# or for newer versions:
sudo dnf install gcc make pkgconfig libv4l-devel v4l-utils
```

### 2. Check Video Devices

```bash
# List video devices
ls -la /dev/video*

# Get device information
v4l2-ctl --list-devices

# Test specific device
v4l2-ctl --device=/dev/video0 --info
v4l2-ctl --device=/dev/video0 --list-formats
```

### 3. Build JetKVM

```bash
# Clone repository
git clone <repository-url>
cd kvm

# Build with hardware support
./build_x86_hardware.sh
```

### 4. Run JetKVM

```bash
# Run with root privileges (required for video device access)
sudo ./bin/jetkvm_x86_hardware

# Or add your user to video group (requires logout/login)
sudo usermod -a -G video $USER
# Then run without sudo:
./bin/jetkvm_x86_hardware
```

## Configuration

### Video Device Selection

JetKVM automatically scans for video devices in this order:
1. `/dev/video0`
2. `/dev/video1`
3. `/dev/video2`
4. `/dev/video3`

To force a specific device, set the environment variable:
```bash
export JETKVM_VIDEO_DEVICE=/dev/video1
sudo -E ./bin/jetkvm_x86_hardware
```

### Video Format

JetKVM attempts to configure the video device with:
- **Resolution**: 1920x1080 (falls back to device default)
- **Format**: YUYV (falls back to MJPEG)
- **Frame Rate**: 30 FPS

### Quality Settings

Adjust video quality through the web interface or API:
- **Quality Factor**: 0.1 to 2.0 (1.0 = default)
- **Bitrate**: Automatically calculated based on resolution and quality

## Troubleshooting

### No Video Devices Found

```bash
# Check if device is recognized
lsusb  # For USB devices
lspci  # For PCIe devices

# Check kernel messages
dmesg | grep -i video
dmesg | grep -i uvc

# Load USB Video Class driver
sudo modprobe uvcvideo
```

### Permission Denied

```bash
# Check device permissions
ls -la /dev/video*

# Add user to video group
sudo usermod -a -G video $USER

# Or run with sudo
sudo ./bin/jetkvm_x86_hardware
```

### Video Format Not Supported

```bash
# Check supported formats
v4l2-ctl --device=/dev/video0 --list-formats-ext

# Test with different resolution
v4l2-ctl --device=/dev/video0 --set-fmt-video=width=1280,height=720,pixelformat=YUYV
```

### Poor Video Quality

1. **Check USB connection**: Use USB 3.0 port for USB capture devices
2. **Adjust quality**: Increase quality factor in web interface
3. **Check CPU usage**: High CPU usage may cause frame drops
4. **Update drivers**: Ensure latest drivers for capture device

### Audio Issues

This implementation focuses on video capture only. For audio:
1. Use separate audio capture (ALSA/PulseAudio)
2. Consider capture devices with audio support
3. Implement audio streaming separately

## Supported Capture Devices

### Tested Devices

| Device | USB/PCIe | Max Resolution | Notes |
|--------|----------|----------------|-------|
| Elgato Cam Link 4K | USB 3.0 | 3840x2160@30fps | Excellent compatibility |
| AVerMedia Live Gamer Ultra | USB 3.0 | 4096x2160@30fps | Good performance |
| Generic USB 3.0 HDMI | USB 3.0 | 1920x1080@60fps | Basic functionality |

### Device-Specific Notes

**Elgato Cam Link 4K**:
- Appears as `/dev/video0`
- Supports multiple formats
- No additional drivers needed on modern Linux

**AVerMedia Devices**:
- May require proprietary drivers
- Check manufacturer's Linux support

**Generic USB Devices**:
- Usually work with UVC (USB Video Class) driver
- Quality varies significantly
- Some may have resolution limitations

## Performance Optimization

### CPU Usage
- **Hardware Encoding**: Use capture devices with hardware encoding
- **Resolution**: Lower resolution reduces CPU load
- **Frame Rate**: 30fps is usually sufficient for KVM usage

### Network Bandwidth
- **Quality Factor**: Adjust based on network capacity
- **Compression**: MJPEG format may reduce CPU load but increase bandwidth

### Memory Usage
- **Buffer Count**: Default 4 buffers, increase for high frame rates
- **Resolution**: Higher resolution requires more memory

## Development

### Build Tags

The hardware version uses the `hardware` build tag:
```go
//go:build linux && amd64 && hardware
```

### Adding New Devices

To add support for new capture devices:

1. **Update device list** in `x86_video_capture.c`:
```c
static const char* video_devices[] = {
    "/dev/video0",
    "/dev/video1",
    "/dev/video2",
    "/dev/video3",
    "/dev/video4",  // Add new device
    NULL
};
```

2. **Add device-specific initialization** if needed
3. **Test with various formats and resolutions**

### Debugging

Enable debug logging:
```bash
export JETKVM_LOG_DEBUG=all
./bin/jetkvm_x86_hardware
```

Check video capture logs:
```bash
# Monitor kernel messages
sudo dmesg -w

# Check V4L2 debug info
echo 1 | sudo tee /sys/module/videobuf2_core/parameters/debug
```

## Comparison with ARM Version

| Feature | ARM (Original) | X86_64 Hardware | X86_64 Simulation |
|---------|----------------|-----------------|-------------------|
| Video Capture | Rockchip MPP | V4L2 | Mock/Simulated |
| Performance | Optimized HW | CPU-dependent | Minimal CPU |
| HDMI Input | Native | USB/PCIe device | Simulated |
| USB Gadget | Hardware | Software | Mock |
| Display | Physical LCD | Web interface | Web interface |

## Future Enhancements

- [ ] Audio capture support
- [ ] Hardware-accelerated encoding (VAAPI/NVENC)
- [ ] Multiple video input support
- [ ] Hot-plug device detection
- [ ] Advanced video processing (deinterlacing, scaling)
- [ ] EDID emulation for capture devices

## Support

For hardware-specific issues:
1. Check device compatibility list
2. Verify V4L2 support: `v4l2-ctl --list-devices`
3. Test with standard tools: `ffmpeg`, `vlc`
4. Check manufacturer's Linux support documentation

For software issues:
1. Enable debug logging
2. Check system logs: `journalctl -f`
3. Verify build dependencies
4. Test with simulation version first