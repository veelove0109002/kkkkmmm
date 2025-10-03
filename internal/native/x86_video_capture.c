#include "x86_video_capture.h"

static x86_video_capture_t video_capture = {0};
static int video_initialized = 0;

// Default video devices to try
static const char* video_devices[] = {
    "/dev/video0",
    "/dev/video1", 
    "/dev/video2",
    "/dev/video3",
    NULL
};

// Helper function to get current time in microseconds
static uint64_t get_time_us() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

// Video capture thread
static void* video_capture_thread(void* arg) {
    x86_video_capture_t* cap = (x86_video_capture_t*)arg;
    struct v4l2_buffer buf;
    fd_set fds;
    struct timeval tv;
    int r;
    
    printf("X86 Video capture thread started for device: %s\n", cap->device_path);
    
    while (cap->capturing) {
        FD_ZERO(&fds);
        FD_SET(cap->fd, &fds);
        
        tv.tv_sec = 1;
        tv.tv_usec = 0;
        
        r = select(cap->fd + 1, &fds, NULL, NULL, &tv);
        
        if (r == -1) {
            if (errno == EINTR) continue;
            printf("Error in select: %s\n", strerror(errno));
            break;
        }
        
        if (r == 0) {
            // Timeout - continue
            continue;
        }
        
        if (FD_ISSET(cap->fd, &fds)) {
            memset(&buf, 0, sizeof(buf));
            buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
            buf.memory = V4L2_MEMORY_MMAP;
            
            if (ioctl(cap->fd, VIDIOC_DQBUF, &buf) == -1) {
                if (errno == EAGAIN) continue;
                printf("Error dequeuing buffer: %s\n", strerror(errno));
                break;
            }
            
            // Send frame data to Go callback
            pthread_mutex_lock(&cap->mutex);
            if (cap->capturing && buf.index < cap->buffer_count) {
                go_video_frame_callback(
                    cap->buffer_start[buf.index],
                    cap->buffer_length[buf.index],
                    cap->width,
                    cap->height
                );
            }
            pthread_mutex_unlock(&cap->mutex);
            
            // Requeue the buffer
            if (ioctl(cap->fd, VIDIOC_QBUF, &buf) == -1) {
                printf("Error requeuing buffer: %s\n", strerror(errno));
                break;
            }
        }
    }
    
    printf("X86 Video capture thread stopped\n");
    return NULL;
}

// Initialize video system
int x86_video_init(void) {
    if (video_initialized) {
        return 0;
    }
    
    memset(&video_capture, 0, sizeof(video_capture));
    video_capture.fd = -1;
    video_capture.quality_factor = 1.0f;
    strcpy(video_capture.device_path, "/dev/video0");
    strcpy(video_capture.status_message, "Not initialized");
    
    // Initialize default EDID for 1920x1080
    strcpy(video_capture.edid_data, 
           "00ffffffffffff0010ac72404c384145"
           "2e120103802f1e78eaee95a3544c9926"
           "0f5054a54b00b300d100714fa9408180"
           "8140010101011d007251d01e206e2855"
           "00d9281100001e8c0ad08a20e02d1010"
           "3e9600138e2100001e023a8018713827"
           "40582c4500d9281100001e011d80d072"
           "1c1620102c2580d9281100009e000000");
    
    pthread_mutex_init(&video_capture.mutex, NULL);
    
    video_initialized = 1;
    printf("X86 Video system initialized\n");
    return 0;
}

// Find and open video device
static int find_video_device(x86_video_capture_t* cap) {
    struct v4l2_capability v4l2_cap;
    int i = 0;
    
    while (video_devices[i] != NULL) {
        cap->fd = open(video_devices[i], O_RDWR | O_NONBLOCK);
        if (cap->fd == -1) {
            printf("Cannot open video device %s: %s\n", video_devices[i], strerror(errno));
            i++;
            continue;
        }
        
        // Check if device supports video capture
        if (ioctl(cap->fd, VIDIOC_QUERYCAP, &v4l2_cap) == -1) {
            printf("Error querying capabilities for %s: %s\n", video_devices[i], strerror(errno));
            close(cap->fd);
            cap->fd = -1;
            i++;
            continue;
        }
        
        if (!(v4l2_cap.capabilities & V4L2_CAP_VIDEO_CAPTURE)) {
            printf("Device %s does not support video capture\n", video_devices[i]);
            close(cap->fd);
            cap->fd = -1;
            i++;
            continue;
        }
        
        if (!(v4l2_cap.capabilities & V4L2_CAP_STREAMING)) {
            printf("Device %s does not support streaming\n", video_devices[i]);
            close(cap->fd);
            cap->fd = -1;
            i++;
            continue;
        }
        
        // Found suitable device
        strcpy(cap->device_path, video_devices[i]);
        printf("Found video capture device: %s (%s)\n", video_devices[i], v4l2_cap.card);
        return 0;
        
        i++;
    }
    
    return -1;
}

// Setup video format
static int setup_video_format(x86_video_capture_t* cap) {
    struct v4l2_format fmt;
    struct v4l2_streamparm parm;
    
    // Try to get current format first
    memset(&fmt, 0, sizeof(fmt));
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    
    if (ioctl(cap->fd, VIDIOC_G_FMT, &fmt) == -1) {
        printf("Error getting video format: %s\n", strerror(errno));
        return -1;
    }
    
    // Set desired format
    fmt.fmt.pix.width = 1920;
    fmt.fmt.pix.height = 1080;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
    fmt.fmt.pix.field = V4L2_FIELD_INTERLACED;
    
    if (ioctl(cap->fd, VIDIOC_S_FMT, &fmt) == -1) {
        printf("Error setting video format: %s\n", strerror(errno));
        // Try with different format
        fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_MJPEG;
        if (ioctl(cap->fd, VIDIOC_S_FMT, &fmt) == -1) {
            printf("Error setting MJPEG format: %s\n", strerror(errno));
            return -1;
        }
    }
    
    cap->width = fmt.fmt.pix.width;
    cap->height = fmt.fmt.pix.height;
    
    printf("Video format set: %dx%d\n", cap->width, cap->height);
    
    // Set frame rate
    memset(&parm, 0, sizeof(parm));
    parm.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    parm.parm.capture.timeperframe.numerator = 1;
    parm.parm.capture.timeperframe.denominator = 30;
    
    if (ioctl(cap->fd, VIDIOC_S_PARM, &parm) == -1) {
        printf("Warning: Could not set frame rate: %s\n", strerror(errno));
        cap->fps = 30; // Default
    } else {
        cap->fps = parm.parm.capture.timeperframe.denominator / 
                   parm.parm.capture.timeperframe.numerator;
    }
    
    printf("Frame rate set to: %d fps\n", cap->fps);
    return 0;
}

// Setup memory mapping
static int setup_mmap(x86_video_capture_t* cap) {
    struct v4l2_requestbuffers req;
    
    memset(&req, 0, sizeof(req));
    req.count = 4;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    
    if (ioctl(cap->fd, VIDIOC_REQBUFS, &req) == -1) {
        printf("Error requesting buffers: %s\n", strerror(errno));
        return -1;
    }
    
    if (req.count < 2) {
        printf("Insufficient buffer memory\n");
        return -1;
    }
    
    cap->buffer_count = req.count;
    cap->buffers = calloc(req.count, sizeof(struct v4l2_buffer));
    cap->buffer_start = calloc(req.count, sizeof(void*));
    cap->buffer_length = calloc(req.count, sizeof(size_t));
    
    if (!cap->buffers || !cap->buffer_start || !cap->buffer_length) {
        printf("Out of memory\n");
        return -1;
    }
    
    for (int i = 0; i < cap->buffer_count; i++) {
        struct v4l2_buffer buf;
        
        memset(&buf, 0, sizeof(buf));
        buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        buf.memory = V4L2_MEMORY_MMAP;
        buf.index = i;
        
        if (ioctl(cap->fd, VIDIOC_QUERYBUF, &buf) == -1) {
            printf("Error querying buffer %d: %s\n", i, strerror(errno));
            return -1;
        }
        
        cap->buffer_length[i] = buf.length;
        cap->buffer_start[i] = mmap(NULL, buf.length,
                                   PROT_READ | PROT_WRITE,
                                   MAP_SHARED,
                                   cap->fd, buf.m.offset);
        
        if (cap->buffer_start[i] == MAP_FAILED) {
            printf("Error mapping buffer %d: %s\n", i, strerror(errno));
            return -1;
        }
        
        cap->buffers[i] = buf;
    }
    
    printf("Mapped %d buffers\n", cap->buffer_count);
    return 0;
}

// Initialize video capture
int x86_video_capture_init(void) {
    if (!video_initialized) {
        x86_video_init();
    }
    
    pthread_mutex_lock(&video_capture.mutex);
    
    if (video_capture.fd != -1) {
        pthread_mutex_unlock(&video_capture.mutex);
        return 0; // Already initialized
    }
    
    // Find video device
    if (find_video_device(&video_capture) != 0) {
        strcpy(video_capture.status_message, "No suitable video device found");
        pthread_mutex_unlock(&video_capture.mutex);
        return -1;
    }
    
    // Setup video format
    if (setup_video_format(&video_capture) != 0) {
        close(video_capture.fd);
        video_capture.fd = -1;
        strcpy(video_capture.status_message, "Failed to setup video format");
        pthread_mutex_unlock(&video_capture.mutex);
        return -1;
    }
    
    // Setup memory mapping
    if (setup_mmap(&video_capture) != 0) {
        close(video_capture.fd);
        video_capture.fd = -1;
        strcpy(video_capture.status_message, "Failed to setup memory mapping");
        pthread_mutex_unlock(&video_capture.mutex);
        return -1;
    }
    
    strcpy(video_capture.status_message, "Video capture initialized successfully");
    pthread_mutex_unlock(&video_capture.mutex);
    
    // Notify Go about video state
    go_video_state_callback(1, video_capture.width, video_capture.height, 
                           video_capture.fps, NULL);
    
    printf("X86 Video capture initialized: %dx%d@%dfps\n", 
           video_capture.width, video_capture.height, video_capture.fps);
    
    return 0;
}

// Start video capture
int x86_video_capture_start(void) {
    pthread_mutex_lock(&video_capture.mutex);
    
    if (video_capture.fd == -1) {
        pthread_mutex_unlock(&video_capture.mutex);
        return -1;
    }
    
    if (video_capture.capturing) {
        pthread_mutex_unlock(&video_capture.mutex);
        return 0; // Already capturing
    }
    
    // Queue all buffers
    for (int i = 0; i < video_capture.buffer_count; i++) {
        if (ioctl(video_capture.fd, VIDIOC_QBUF, &video_capture.buffers[i]) == -1) {
            printf("Error queuing buffer %d: %s\n", i, strerror(errno));
            pthread_mutex_unlock(&video_capture.mutex);
            return -1;
        }
    }
    
    // Start streaming
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (ioctl(video_capture.fd, VIDIOC_STREAMON, &type) == -1) {
        printf("Error starting stream: %s\n", strerror(errno));
        pthread_mutex_unlock(&video_capture.mutex);
        return -1;
    }
    
    video_capture.capturing = 1;
    
    // Start capture thread
    if (pthread_create(&video_capture.capture_thread, NULL, 
                      video_capture_thread, &video_capture) != 0) {
        printf("Error creating capture thread\n");
        video_capture.capturing = 0;
        pthread_mutex_unlock(&video_capture.mutex);
        return -1;
    }
    
    strcpy(video_capture.status_message, "Video capture started");
    pthread_mutex_unlock(&video_capture.mutex);
    
    printf("X86 Video capture started\n");
    return 0;
}

// Stop video capture
int x86_video_capture_stop(void) {
    pthread_mutex_lock(&video_capture.mutex);
    
    if (!video_capture.capturing) {
        pthread_mutex_unlock(&video_capture.mutex);
        return 0;
    }
    
    video_capture.capturing = 0;
    pthread_mutex_unlock(&video_capture.mutex);
    
    // Wait for thread to finish
    pthread_join(video_capture.capture_thread, NULL);
    
    pthread_mutex_lock(&video_capture.mutex);
    
    // Stop streaming
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (ioctl(video_capture.fd, VIDIOC_STREAMOFF, &type) == -1) {
        printf("Error stopping stream: %s\n", strerror(errno));
    }
    
    strcpy(video_capture.status_message, "Video capture stopped");
    pthread_mutex_unlock(&video_capture.mutex);
    
    printf("X86 Video capture stopped\n");
    return 0;
}

// Shutdown video capture
void x86_video_capture_shutdown(void) {
    x86_video_capture_stop();
    
    pthread_mutex_lock(&video_capture.mutex);
    
    // Unmap buffers
    if (video_capture.buffer_start) {
        for (int i = 0; i < video_capture.buffer_count; i++) {
            if (video_capture.buffer_start[i] != MAP_FAILED) {
                munmap(video_capture.buffer_start[i], video_capture.buffer_length[i]);
            }
        }
        free(video_capture.buffer_start);
        video_capture.buffer_start = NULL;
    }
    
    if (video_capture.buffer_length) {
        free(video_capture.buffer_length);
        video_capture.buffer_length = NULL;
    }
    
    if (video_capture.buffers) {
        free(video_capture.buffers);
        video_capture.buffers = NULL;
    }
    
    // Close device
    if (video_capture.fd != -1) {
        close(video_capture.fd);
        video_capture.fd = -1;
    }
    
    video_capture.buffer_count = 0;
    strcpy(video_capture.status_message, "Video capture shutdown");
    
    pthread_mutex_unlock(&video_capture.mutex);
    
    printf("X86 Video capture shutdown complete\n");
}

// Get status
const char* x86_video_get_status(void) {
    return video_capture.status_message;
}

// Get quality factor
float x86_video_get_quality_factor(void) {
    return video_capture.quality_factor;
}

// Set quality factor
void x86_video_set_quality_factor(float factor) {
    if (factor >= 0.1f && factor <= 2.0f) {
        video_capture.quality_factor = factor;
    }
}

// Get EDID
const char* x86_video_get_edid(void) {
    return video_capture.edid_data;
}

// Set EDID
int x86_video_set_edid(const char* edid) {
    if (edid && strlen(edid) < sizeof(video_capture.edid_data)) {
        strcpy(video_capture.edid_data, edid);
        return 0;
    }
    return -1;
}