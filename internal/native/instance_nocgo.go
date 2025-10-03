//go:build !cgo

package native

// instance_nocgo.go: no-op instance setter for non-cgo builds (e.g., ARM simplified CI build)

// SetInstance is a no-op when cgo is disabled
func SetInstance(_ *Native) {}