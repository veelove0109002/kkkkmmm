//go:build linux && amd64 && hardware

package native

/*
#cgo CFLAGS: -I. -std=c99
#cgo LDFLAGS: -lpthread

#include "x86_video_capture.h"
*/
import "C"

import (
	"fmt"
	"sync"
	"unsafe"
)

var cgoLock sync.Mutex

// Hardware implementations for X86_64 architecture with real HDMI capture
// These provide actual video capture functionality using V4L2

func setUpNativeHandlers() {
	nativeLogger.Info().Msg("Setting up hardware native handlers for X86_64")
	C.x86_video_init()
}

func uiInit(rotation uint16) {
	nativeLogger.Info().Uint16("rotation", rotation).Msg("Hardware UI init for X86_64")
	// For X86_64, we don't have a physical display, so this is minimal
}

func uiTick() {
	// Minimal UI tick for X86_64
}

func videoInit() error {
	nativeLogger.Info().Msg("Initializing hardware video capture for X86_64")
	result := C.x86_video_capture_init()
	if result != 0 {
		return fmt.Errorf("failed to initialize video capture: %d", result)
	}
	return nil
}

func videoShutdown() {
	nativeLogger.Info().Msg("Shutting down hardware video capture for X86_64")
	C.x86_video_capture_shutdown()
}

func videoStart() {
	nativeLogger.Info().Msg("Starting hardware video capture for X86_64")
	C.x86_video_capture_start()
}

func videoStop() {
	nativeLogger.Info().Msg("Stopping hardware video capture for X86_64")
	C.x86_video_capture_stop()
}

func videoLogStatus() string {
	status := C.x86_video_get_status()
	return C.GoString(status)
}

// UI functions - minimal implementations for X86_64
func uiSetVar(name string, value string) {
	nativeLogger.Debug().Str("name", name).Str("value", value).Msg("Hardware UI set var")
}

func uiGetVar(name string) string {
	return ""
}

func uiSwitchToScreen(screen string) {
	nativeLogger.Info().Str("screen", screen).Msg("Hardware UI switch to screen")
}

func uiGetCurrentScreen() string {
	return "main"
}

func uiObjAddState(objName string, state string) (bool, error) {
	return true, nil
}

func uiObjClearState(objName string, state string) (bool, error) {
	return true, nil
}

func uiGetLVGLVersion() string {
	return "8.3.0-x86-hardware"
}

func uiObjAddFlag(objName string, flag string) (bool, error) {
	return true, nil
}

func uiObjClearFlag(objName string, flag string) (bool, error) {
	return true, nil
}

func uiObjHide(objName string) (bool, error) {
	return uiObjAddFlag(objName, "LV_OBJ_FLAG_HIDDEN")
}

func uiObjShow(objName string) (bool, error) {
	return uiObjClearFlag(objName, "LV_OBJ_FLAG_HIDDEN")
}

func uiObjSetOpacity(objName string, opacity int) (bool, error) {
	return true, nil
}

func uiObjFadeIn(objName string, duration uint32) (bool, error) {
	return true, nil
}

func uiObjFadeOut(objName string, duration uint32) (bool, error) {
	return true, nil
}

func uiLabelSetText(objName string, text string) (bool, error) {
	return true, nil
}

func uiImgSetSrc(objName string, src string) (bool, error) {
	return true, nil
}

func uiDispSetRotation(rotation uint16) (bool, error) {
	return true, nil
}

func videoGetStreamQualityFactor() (float64, error) {
	factor := C.x86_video_get_quality_factor()
	return float64(factor), nil
}

func videoSetStreamQualityFactor(factor float64) error {
	C.x86_video_set_quality_factor(C.float(factor))
	return nil
}

func videoGetEDID() (string, error) {
	edid := C.x86_video_get_edid()
	return C.GoString(edid), nil
}

func videoSetEDID(edid string) error {
	cEdid := C.CString(edid)
	defer C.free(unsafe.Pointer(cEdid))
	result := C.x86_video_set_edid(cEdid)
	if result != 0 {
		return fmt.Errorf("failed to set EDID: %d", result)
	}
	return nil
}

func uiEventCodeToName(code int) string {
	return fmt.Sprintf("X86_EVENT_%d", code)
}

func crash() {
	panic("Hardware crash for X86_64")
}

// Callback functions called from C code
//export go_video_frame_callback
func go_video_frame_callback(data unsafe.Pointer, size C.int, width C.int, height C.int) {
	if nativeInstance != nil {
		frameData := C.GoBytes(data, size)
		nativeInstance.onVideoFrameReceived(frameData, 0)
	}
}

//export go_video_state_callback
func go_video_state_callback(ready C.int, width C.int, height C.int, fps C.float, errorMsg *C.char) {
	if nativeInstance != nil {
		state := VideoState{
			Ready:          ready != 0,
			Width:          int(width),
			Height:         int(height),
			FramePerSecond: float64(fps),
		}
		if errorMsg != nil {
			state.Error = C.GoString(errorMsg)
		}
		nativeInstance.onVideoStateChange(state)
	}
}

