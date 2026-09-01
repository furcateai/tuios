package theme

import (
	"testing"

	tint "github.com/lrstanley/bubbletint/v2"
)

// The palette's roles are filled, and the slots the console remaps agree with
// the ones the branding already ships.
//
// This checks that every role a screen depends on has a colour, not that each
// is one exact value. The amber is a family rather than a single yellow: the
// login banner, the shell codes and this palette should look like one system,
// and the tests below say what "one system" means — ordered weights, a fault
// that is plainly not amber, context that stays readable. Picking a nicer amber
// is a design decision, not a regression, so it does not fail here.
func TestFurcateFillsEveryRole(t *testing.T) {
	for _, c := range []struct {
		role string
		got  *tint.Color
	}{
		{"Yellow (the system's voice)", furcateTint.Yellow},
		{"BrightYellow (measured)", furcateTint.BrightYellow},
		{"Red (fault)", furcateTint.Red},
		{"BrightBlack (context)", furcateTint.BrightBlack},
		{"Fg", furcateTint.Fg},
		{"Bg", furcateTint.Bg},
		{"Cursor", furcateTint.Cursor},
	} {
		if c.got == nil {
			t.Errorf("%s is unset", c.role)
		}
	}
}

// The ambers are a family: each weight is lighter than the one below it.
//
// This is what makes hierarchy readable — a measured figure has to sit above
// the system's own voice, which has to sit above context. Whether the family is
// this exact yellow is a matter of taste; that it is ordered is not.
func TestAmberWeightsAreOrdered(t *testing.T) {
	context, _, _ := oklchOf(t, furcateTint.BrightBlack.Hex())
	voice, _, _ := oklchOf(t, furcateTint.Yellow.Hex())
	measured, _, _ := oklchOf(t, furcateTint.BrightYellow.Hex())

	if !(context < voice && voice < measured) {
		t.Errorf("weights are not ordered: context L%.3f, voice L%.3f, measured L%.3f; "+
			"a measured figure must read as brighter than the label beside it",
			context, voice, measured)
	}
}

// Both amber weights are still amber.
//
// Shades of yellow are welcome — the family reads better with a little movement
// in it than locked to one value, and gamut clipping means the brightest amber
// cannot hold the base hue anyway. What must not happen is a "bright amber"
// that has wandered far enough to read as a second colour on the screen: two
// accents on a dark ground look like two designs sharing a window, which is the
// thing this palette was consolidated to fix.
//
// The window is wide on purpose. Warm yellow through orange all belong to the
// family; green-yellow and red do not.
func TestBothAmberWeightsAreStillAmber(t *testing.T) {
	const (
		amberHueMin = 60.0 // below this it turns green-yellow
		amberHueMax = 95.0 // above this it is no longer a yellow at all
	)
	for _, c := range []struct {
		name string
		hex  string
	}{
		{"Yellow", furcateTint.Yellow.Hex()},
		{"BrightYellow", furcateTint.BrightYellow.Hex()},
	} {
		_, chroma, hue := oklchOf(t, c.hex)
		if hue < amberHueMin || hue > amberHueMax {
			t.Errorf("%s hue %.1f is outside the amber family (%.0f-%.0f)",
				c.name, hue, amberHueMin, amberHueMax)
		}
		// A grey with a hue reading is still a grey. The ambers have to carry
		// enough colour to look like the brand rather than like unstyled text.
		if chroma < 0.05 {
			t.Errorf("%s has chroma %.3f — too washed out to read as amber", c.name, chroma)
		}
	}
}

// A fault has to be the one thing on screen that is not amber, so it must be a
// genuinely different hue rather than a deep orange that reads as a warning.
func TestFaultIsNotAnAmber(t *testing.T) {
	_, _, amberHue := oklchOf(t, furcateTint.Yellow.Hex())
	_, _, faultHue := oklchOf(t, furcateTint.Red.Hex())
	if d := abs(amberHue - faultHue); d < 30 {
		t.Errorf("fault hue %.1f is only %.1f degrees from amber %.1f; "+
			"a fault that reads as a warm amber is a fault nobody sees", faultHue, d, amberHue)
	}
}

// The rest of the wheel is the chrome, and the chrome is amber.
//
// theme.go derives the interface's frame from these slots: BrightCyan is the
// focused border in window mode, BrightGreen the focused border in terminal
// mode, BrightBlue the dock's mode indicator. They are not spare colours a
// guest program borrows — they are what the screen is drawn in — so a literal
// green or cyan here frames amber content in somebody else's palette.
//
// Held to the amber family for that reason, and still quieter than the voice
// so that a border never out-shouts the figure inside it. Red is exempt: it is
// the fault colour and has to be the one thing that is not amber.
func TestChromeStaysInTheAmberFamily(t *testing.T) {
	_, amberChroma, _ := oklchOf(t, furcateTint.Yellow.Hex())

	const (
		amberHueMin = 55.0
		amberHueMax = 100.0
	)
	for _, c := range []struct {
		name string
		hex  string
	}{
		{"BrightCyan (focused border, window mode)", furcateTint.BrightCyan.Hex()},
		{"BrightGreen (focused border, terminal mode)", furcateTint.BrightGreen.Hex()},
		{"BrightBlue (dock mode indicator)", furcateTint.BrightBlue.Hex()},
		{"Green", furcateTint.Green.Hex()},
		{"Blue", furcateTint.Blue.Hex()},
		{"Cyan", furcateTint.Cyan.Hex()},
		{"Purple", furcateTint.Purple.Hex()},
	} {
		_, chroma, hue := oklchOf(t, c.hex)
		if hue < amberHueMin || hue > amberHueMax {
			t.Errorf("%s is hue %.1f, outside the amber family (%.0f-%.0f): "+
				"the interface would be framed in a second colour",
				c.name, hue, amberHueMin, amberHueMax)
		}
		// Quieter than the voice. A border is a frame, and a frame that is
		// more saturated than what it contains is the loudest thing on screen.
		if chroma >= amberChroma {
			t.Errorf("%s has chroma %.3f, at or above the voice's %.3f; "+
				"the frame must not out-shout the figure inside it",
				c.name, chroma, amberChroma)
		}
	}
}

// Anything drawn on the background has to be legible against it.
//
// The palette is free to move, but a shade that looks good in a swatch and
// vanishes on the actual ground is the failure mode worth catching — most of
// all for context, which carries units and labels and is the first thing a
// redesign dims too far.
func TestEverythingIsLegibleOnTheBackground(t *testing.T) {
	bgL, _, _ := oklchOf(t, furcateTint.Bg.Hex())

	for _, c := range []struct {
		name    string
		hex     string
		minGap  float64
		purpose string
	}{
		{"BrightBlack", furcateTint.BrightBlack.Hex(), 0.25, "units and labels"},
		{"Yellow", furcateTint.Yellow.Hex(), 0.45, "the system's own voice"},
		{"BrightYellow", furcateTint.BrightYellow.Hex(), 0.50, "measured figures"},
		{"Red", furcateTint.Red.Hex(), 0.25, "faults"},
		{"Fg", furcateTint.Fg.Hex(), 0.45, "ordinary text"},
	} {
		l, _, _ := oklchOf(t, c.hex)
		if gap := l - bgL; gap < c.minGap {
			t.Errorf("%s (%s) is only L%.3f above the background; too dark to read %s",
				c.name, c.hex, gap, c.purpose)
		}
	}
}

// Registering must not depend on the operator's config directory existing.
func TestFurcateIsRegisteredAsABuiltin(t *testing.T) {
	// EnsureRegistry is behind a sync.Once and another test in this package may
	// already have spent it, so calling it here is not enough to guarantee the
	// registry exists in this process. Build one directly and register into it,
	// which is what EnsureRegistry does and is the thing under test: that the
	// palette is compiled in rather than loaded from the operator's themes
	// directory, which may not exist at all.
	tint.NewDefaultRegistry()
	registerFurcate()

	got, ok := tint.GetTint("furcate")
	if !ok || got == nil {
		t.Fatal("the distribution's own palette is not in the registry")
	}
	if got.DisplayName != "Furcate" {
		t.Errorf("DisplayName = %q, want %q", got.DisplayName, "Furcate")
	}
}

func abs(f float64) float64 {
	if f < 0 {
		return -f
	}
	return f
}
