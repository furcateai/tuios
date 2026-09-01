package theme

import (
	"fmt"
	"testing"

	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/colorprofile"
	"github.com/charmbracelet/x/ansi"
	tint "github.com/lrstanley/bubbletint/v2"
)

// Every chrome surface has to land on the ground slot when the terminal has
// only sixteen colours.
//
// This is not a nicety. A Linux console has sixteen and no more, so the RGB the
// chrome is built from is quantised to whichever slot is nearest — and the
// nearest slot to a warm dark brown is, at the wrong lightness, the fault red.
// That is what happened: Card was #332507, it landed on slot 1, and every row
// of the sidebar was drawn on an alarm. The rail looked like a machine
// screaming while its own panes said everything was fine.
//
// The floor is the ground itself, so the assertion is simply that no surface
// walks off it. A surface that needs more separation than that has to get it
// from the ink on top rather than from a lighter fill.
func TestChromeSurfacesStayOnTheGroundSlot(t *testing.T) {
	tint.NewDefaultRegistry()
	registerFurcate()
	if !tint.SetTintID("furcate") {
		t.Fatal("the distribution's palette is not registered")
	}
	prev := enabled
	enabled = true
	t.Cleanup(func() { enabled = prev })

	ground := ansi16(t, furcateTint.Bg)

	p := UI()
	for _, c := range []struct {
		name string
		col  interface{ RGBA() (uint32, uint32, uint32, uint32) }
		what string
	}{
		{"Canvas", p.Canvas, "the ground everything else sits on"},
		{"Panel", p.Panel, "the dock and the rail's own fill"},
		{"Surface", p.Surface, "overlays and popups"},
		{"Card", p.Card, "a row in the rail"},
		{"RowSel", p.RowSel, "the row under the cursor"},
	} {
		if got := ansi16(t, c.col); got != ground {
			t.Errorf("%s (%s) quantises to slot %d, not the ground's %d — "+
				"on a sixteen-colour console %s would be drawn on the wrong colour",
				c.name, c.what, got, ground, c.what)
		}
	}
}

// ansi16 is the slot a colour reaches on a sixteen-colour terminal, which is
// what a Linux console shows regardless of the RGB it was given.
//
// Convert returns an ansi.BasicColor, which is the slot number itself. Reading
// it through fmt would work and would also quietly return the same answer for
// every input if the type ever changed — which is what the first version of
// this helper did, and it made the test pass while the bug was present.
func ansi16(t *testing.T, c interface{ RGBA() (uint32, uint32, uint32, uint32) }) int {
	t.Helper()
	r, g, b, _ := c.RGBA()
	hex := fmt.Sprintf("#%02x%02x%02x", r>>8, g>>8, b>>8)
	switch v := colorprofile.ANSI.Convert(lipgloss.Color(hex)).(type) {
	case ansi.BasicColor:
		return int(v)
	default:
		t.Fatalf("ANSI conversion of %s gave %T, not a basic colour", hex, v)
		return -1
	}
}
