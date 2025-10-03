#ifndef X86_VIDEO_CAPTURE_H
#define X86_VIDEO_CAPTURE_H
#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/time.h>
#include <time.h>
#include <linux/videodev2.h>
#include <pthread.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Video capture structure for X86_64
typedef struct {
    int fd;
    struct v4l2_buffer *buffers;
    void **buffer_start;
    size_t *buffer_length;
    int buffer_count;
    int width;
    int height;
    int fps;
    int capturing;
    pthread_t capture_thread;
    pthread_mutex_t mutex;
    char device_path[256];
    char status_message[512];
    float quality_factor;
    char edid_data[512];
} x86_video_capture_t;

// Function declarations
int x86_video_init(void);
int x86_video_capture_init(void);
void x86_video_capture_shutdown(void);
int x86_video_capture_start(void);
int x86_video_capture_stop(void);
const char* x86_video_get_status(void);
float x86_video_get_quality_factor(void);
void x86_video_set_quality_factor(float factor);
const char* x86_video_get_edid(void);
int x86_video_set_edid(const char* edid);

// Callback functions (implemented in Go)
extern void go_video_frame_callback(void* data, int size, int width, int height);
extern void go_video_state_callback(int ready, int width, int height, float fps, const char* error);

#ifdef __cplusplus
}
#endif

#endif // X86_VIDEO_CAPTURE_H