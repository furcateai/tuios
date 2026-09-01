package config

// SetMacOSHostForTest puts a platform under the key normalizer for the duration
// of a test, and returns a function restoring the real one.
//
// Exported because the test that needs it lives in internal/input: the
// Option-chord reading and the binding-key registration are gated by two
// different copies of "is this macOS", in two packages, and a test that moves
// only its own copy is not describing either platform. It moves both or it
// proves nothing.
//
// Not for use outside tests. The platform does not change while a process runs.
func SetMacOSHostForTest(mac bool) func() {
	prev := macOSHost
	macOSHost = mac
	return func() { macOSHost = prev }
}
