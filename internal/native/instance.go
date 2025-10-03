//go:build cgo

package native

// instance.go: provide a package-level native instance for cgo callbacks

var nativeInstance *Native

// SetInstance sets the package-level native instance, used by cgo callbacks
func SetInstance(n *Native) {
	nativeInstance = n
}

// GetInstance returns current package-level native instance
func GetInstance() *Native {
	return nativeInstance
}