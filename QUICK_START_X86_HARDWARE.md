# JetKVM X86_64 硬件版本快速开始指南

## 概述

JetKVM X86_64 硬件版本支持在 X86_64 Linux 系统上使用真实的 HDMI 捕获设备，而不是模拟模式。

## 硬件要求

### HDMI 捕获设备
您需要一个兼容 V4L2 的 HDMI 捕获设备：

**推荐的 USB 捕获卡**：
- Elgato Cam Link 4K
- AVerMedia Live Gamer Ultra  
- EVGA XR1 Lite
- 通用 USB 3.0 HDMI 捕获卡

**PCIe 捕获卡**：
- Blackmagic DeckLink 系列
- AVerMedia Live Gamer HD 2
- Magewell Pro Capture 系列

### 系统要求
- Linux 系统（推荐 Ubuntu 20.04+）
- USB 3.0 接口（用于 USB 捕获设备）
- 足够的 CPU 处理视频流

## 快速安装

### 1. 检查视频设备

```bash
# 列出视频设备
ls -la /dev/video*

# 获取设备信息（需要安装 v4l-utils）
sudo apt-get install v4l-utils
v4l2-ctl --list-devices
```

### 2. 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install libv4l-dev v4l-utils

# CentOS/RHEL/Fedora
sudo yum install libv4l-devel v4l-utils
# 或者新版本：
sudo dnf install libv4l-devel v4l-utils
```

### 3. 下载并运行

```bash
# 下载硬件版本
wget https://github.com/jetkvm/kvm/releases/latest/download/jetkvm-x86_64-hardware-linux

# 设置执行权限
chmod +x jetkvm-x86_64-hardware-linux

# 运行（需要 root 权限访问视频设备）
sudo ./jetkvm-x86_64-hardware-linux
```

### 4. 访问 Web 界面

打开浏览器访问：`http://localhost:8080`

## 配置

### 指定视频设备

如果有多个视频设备，可以指定使用哪个：

```bash
export JETKVM_VIDEO_DEVICE=/dev/video1
sudo -E ./jetkvm-x86_64-hardware-linux
```

### 用户权限设置

避免每次都使用 sudo：

```bash
# 将用户添加到 video 组
sudo usermod -a -G video $USER

# 注销并重新登录，然后可以直接运行：
./jetkvm-x86_64-hardware-linux
```

## 故障排除

### 找不到视频设备

```bash
# 检查设备是否被识别
lsusb  # USB 设备
lspci  # PCIe 设备

# 检查内核消息
dmesg | grep -i video
dmesg | grep -i uvc

# 加载 USB Video Class 驱动
sudo modprobe uvcvideo
```

### 权限被拒绝

```bash
# 检查设备权限
ls -la /dev/video*

# 临时修改权限
sudo chmod 666 /dev/video0

# 或者使用 sudo 运行
sudo ./jetkvm-x86_64-hardware-linux
```

### 视频格式不支持

```bash
# 检查支持的格式
v4l2-ctl --device=/dev/video0 --list-formats-ext

# 测试不同分辨率
v4l2-ctl --device=/dev/video0 --set-fmt-video=width=1280,height=720,pixelformat=YUYV
```

## 性能优化

### CPU 使用率
- 使用硬件编码的捕获设备
- 降低分辨率到 1280x720 如果 CPU 不足
- 调整质量因子（通过 Web 界面）

### 网络带宽
- 根据网络容量调整质量设置
- MJPEG 格式可能减少 CPU 负载但增加带宽

## 与模拟版本的区别

| 功能 | 硬件版本 | 模拟版本 |
|------|----------|----------|
| 视频捕获 | 真实 HDMI 输入 | 模拟视频 |
| 性能 | 取决于硬件 | 最小 CPU 使用 |
| 设备要求 | 需要捕获设备 | 无特殊要求 |
| 用途 | 生产环境 | 开发测试 |

## 支持的捕获设备

### 已测试设备

| 设备 | 接口 | 最大分辨率 | 状态 |
|------|------|------------|------|
| Elgato Cam Link 4K | USB 3.0 | 3840x2160@30fps | ✅ 完全支持 |
| AVerMedia Live Gamer Ultra | USB 3.0 | 4096x2160@30fps | ✅ 良好性能 |
| 通用 USB 3.0 HDMI | USB 3.0 | 1920x1080@60fps | ✅ 基本功能 |

### 兼容性说明

**Elgato Cam Link 4K**：
- 在现代 Linux 上无需额外驱动
- 支持多种格式
- 出现为 `/dev/video0`

**AVerMedia 设备**：
- 可能需要专有驱动
- 检查制造商的 Linux 支持

**通用 USB 设备**：
- 通常使用 UVC (USB Video Class) 驱动
- 质量差异很大
- 某些设备可能有分辨率限制

## 常见问题

**Q: 为什么需要 root 权限？**
A: 访问视频设备通常需要特殊权限。可以通过将用户添加到 video 组来避免。

**Q: 支持音频捕获吗？**
A: 当前版本专注于视频捕获。音频需要单独处理。

**Q: 可以同时使用多个捕获设备吗？**
A: 当前版本支持单个设备。多设备支持在开发计划中。

**Q: 与 ARM 版本有什么区别？**
A: ARM 版本针对嵌入式硬件优化，X86_64 版本使用标准 V4L2 接口。

## 获取帮助

如果遇到问题：
1. 检查设备兼容性列表
2. 验证 V4L2 支持：`v4l2-ctl --list-devices`
3. 使用标准工具测试：`ffmpeg`, `vlc`
4. 查看制造商的 Linux 支持文档

更多详细信息请参考 [README_X86_HARDWARE.md](README_X86_HARDWARE.md)。