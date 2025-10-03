 //go:build linux && amd64 && !hardware

package native

import (
	"fmt"
	"sync"
)

var cgoLock sync.Mutex

// Mock implementations for X86_64 architecture
// These provide basic functionality without hardware-specific dependencies

func setUpNativeHandlers() {
	// Mock setup - no actual hardware handlers needed for X86
	nativeLogger.Info().Msg("Setting up mock native handlers for X86_64")
}

func uiInit(rotation uint16) {
	nativeLogger.Info().Uint16("rotation", rotation).Msg("Mock UI init for X86_64")
}

func uiTick() {
	// Mock UI tick - no actual UI processing needed
}

func videoInit() error {
	nativeLogger.Info().Msg("Mock video init for X86_64")
	return nil
}

func videoShutdown() {
	nativeLogger.Info().Msg("Mock video shutdown for X86_64")
}

func videoStart() {
	nativeLogger.Info().Msg("Mock video start for X86_64")
	// Simulate video state change
	go func() {
		videoState := VideoState{
			Ready:          true,
			Error:          "",
			Width:          1920,
			Height:         1080,
			FramePerSecond: 60.0,
		}
		select {
		case videoStateChan <- videoState:
		default:
		}
	}()
}

func videoStop() {
	nativeLogger.Info().Msg("Mock video stop for X86_64")
}

func videoLogStatus() string {
	return "Mock video status: Running on X86_64"
}

func uiSetVar(name string, value string) {
	nativeLogger.Debug().Str("name", name).Str("value", value).Msg("Mock UI set var")
}

func uiGetVar(name string) string {
	nativeLogger.Debug().Str("name", name).Msg("Mock UI get var")
	return ""
}

func uiSwitchToScreen(screen string) {
	nativeLogger.Info().Str("screen", screen).Msg("Mock UI switch to screen")
}

func uiGetCurrentScreen() string {
	return "main"
}

func uiObjAddState(objName string, state string) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Str("state", state).Msg("Mock UI add state")
	return true, nil
}

func uiObjClearState(objName string, state string) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Str("state", state).Msg("Mock UI clear state")
	return true, nil
}

func uiGetLVGLVersion() string {
	return "8.3.0-mock"
}

func uiObjAddFlag(objName string, flag string) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Str("flag", flag).Msg("Mock UI add flag")
	return true, nil
}

func uiObjClearFlag(objName string, flag string) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Str("flag", flag).Msg("Mock UI clear flag")
	return true, nil
}

func uiObjHide(objName string) (bool, error) {
	return uiObjAddFlag(objName, "LV_OBJ_FLAG_HIDDEN")
}

func uiObjShow(objName string) (bool, error) {
	return uiObjClearFlag(objName, "LV_OBJ_FLAG_HIDDEN")
}

func uiObjSetOpacity(objName string, opacity int) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Int("opacity", opacity).Msg("Mock UI set opacity")
	return true, nil
}

func uiObjFadeIn(objName string, duration uint32) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Uint32("duration", duration).Msg("Mock UI fade in")
	return true, nil
}

func uiObjFadeOut(objName string, duration uint32) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Uint32("duration", duration).Msg("Mock UI fade out")
	return true, nil
}

func uiLabelSetText(objName string, text string) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Str("text", text).Msg("Mock UI set text")
	return true, nil
}

func uiImgSetSrc(objName string, src string) (bool, error) {
	nativeLogger.Debug().Str("obj", objName).Str("src", src).Msg("Mock UI set image")
	return true, nil
}

func uiDispSetRotation(rotation uint16) (bool, error) {
	nativeLogger.Info().Uint16("rotation", rotation).Msg("Mock UI set rotation")
	return true, nil
}

func videoGetStreamQualityFactor() (float64, error) {
	return 1.0, nil
}

func videoSetStreamQualityFactor(factor float64) error {
	nativeLogger.Info().Float64("factor", factor).Msg("Mock video set quality factor")
	return nil
}

func videoGetEDID() (string, error) {
	// Return a mock EDID for 1920x1080 display
	return "00ffffffffffff0010ac72404c384145" +
		"2e120103802f1e78eaee95a3544c9926" +
		"0f5054a54b00b300d100714fa9408180" +
		"8140010101011d007251d01e206e2855" +
		"00d9281100001e8c0ad08a20e02d1010" +
		"3e9600138e2100001e023a8018713827" +
		"40582c4500d9281100001e011d80d072" +
		"1c1620102c2580d9281100009e000000", nil
}

func videoSetEDID(edid string) error {
	nativeLogger.Info().Str("edid", edid).Msg("Mock video set EDID")
	return nil
}

func uiEventCodeToName(code int) string {
	return fmt.Sprintf("MOCK_EVENT_%d", code)
}

func crash() {
	panic("Mock crash for X86_64")
}

// Additional methods needed by display.go
func (n *Native) SwitchToScreenIfDifferent(screen string) {
	if uiGetCurrentScreen() != screen {
		uiSwitchToScreen(screen)
	}
}

func (n *Native) UpdateLabelIfChanged(objName string, text string) {
	// In a real implementation, we would check if the text has changed
	// For mock, we just set it directly
	uiLabelSetText(objName, text)
}

func (n *Native) UpdateLabelAndChangeVisibility(objName string, text string, visible bool) {
	if text != "" {
		uiLabelSetText(objName, text)
		if visible {
			uiObjShow(objName)
		} else {
			uiObjHide(objName)
		}
	} else {
		uiObjHide(objName)
	}
}

func (n *Native) UIObjHide(objName string) (bool, error) {
	return uiObjHide(objName)
}

func (n *Native) UIObjShow(objName string) (bool, error) {
	return uiObjShow(objName)
}

func (n *Native) UIObjAddState(objName string, state string) (bool, error) {
	return uiObjAddState(objName, state)
}

func (n *Native) UIObjClearState(objName string, state string) (bool, error) {
	return uiObjClearState(objName, state)
}

func (n *Native) UISetVar(name string, value string) {
	uiSetVar(name, value)
}

func (n *Native) SwitchToScreenIf(screen string, fromScreens []string) {
	currentScreen := uiGetCurrentScreen()
	for _, fromScreen := range fromScreens {
		if currentScreen == fromScreen {
			uiSwitchToScreen(screen)
			break
		}
	}
}

func (n *Native) UIObjSetImageSrc(objName string, src string) (bool, error) {
	return uiImgSetSrc(objName, src)
}

func (n *Native) UIObjFadeOut(objName string, duration uint32) (bool, error) {
	return uiObjFadeOut(objName, duration)
}

func (n *Native) UIObjFadeIn(objName string, duration uint32) (bool, error) {
	return uiObjFadeIn(objName, duration)
}

func (n *Native) DisplaySetRotation(rotation uint16) (bool, error) {
	return uiDispSetRotation(rotation)
}