package session

import (
	"image/color"

	"github.com/Gaurav-Gosain/tuios/internal/theme"
	"github.com/Gaurav-Gosain/tuios/internal/vt"
)

// applyThemePalette gives a daemon-side emulator the palette the client will
// read its cells back with.
//
// A cell the guest wrote as SGR 31 crosses the wire as the palette entry it
// asked for ("a1") rather than as the shade it resolves to, and each side reads
// that back through its own emulator. That is deliberate — it is what keeps a
// theme's red a theme's red instead of the fixed maroon a flattened hex would
// give — but it only holds while both emulators answer PaletteColor the same
// way.
//
// The daemon has no display and used to carry no palette at all. With a theme
// active the client resolved a1 to the theme's red while the daemon left it an
// index, so the two sides held genuinely different cells: every rehydration
// route compared unequal, and the pen a pane was about to print its next line
// with disagreed. On a machine where no theme was ever set both sides were
// unthemed and it never showed.
//
// The arguments mirror internal/terminal/window.go exactly, including the
// foreground and background. Those are not decoration here: SetThemeColors
// reads a nil fg and bg as "no theme is active" and clears the sixteen, so a
// daemon that passed nil for the colours it does not draw with would silently
// get no palette — which is the bug this exists to fix, wearing the shape of a
// fix.
//
// Kept beside the daemon rather than inside vt.New because an emulator is not
// always a themed thing: the differential harness builds bare ones on purpose,
// and a constructor reaching for global theme state would make those tests
// depend on whatever the last one happened to set.
func applyThemePalette(t vt.Terminal) {
	if !theme.IsEnabled() {
		// Explicit rather than skipped. This is how the emulator is told to put
		// the sixteen back; a daemon that merely returned here would keep a
		// palette from a theme that had since been turned off, which is the
		// "going back to none messes up the ANSI 16" report from the other
		// direction.
		t.SetThemeColors(nil, nil, nil, [16]color.Color{})
		return
	}
	t.SetThemeColors(
		theme.TerminalFg(),
		theme.TerminalBg(),
		theme.TerminalCursor(),
		theme.GetANSIPalette(),
	)
}
