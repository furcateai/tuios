package theme

import (
	"math"
	"strconv"
	"strings"
	"testing"
)

// sRGB -> OKLCH, the inverse of the transform furcate-cli's make-palette.sh
// uses to generate the brand.
//
// It lives in the test rather than beside the palette because nothing that
// runs needs it: the colours are constants by the time they reach a screen.
// What needs it is the assertion that they are still the colours the brand
// generated, and that a "brighter" amber is the same hue with more light in it
// rather than a different colour — which is a claim about hue, and hue is not
// visible in a hex string.
func oklchOf(t *testing.T, hex string) (l, c, h float64) {
	t.Helper()
	r, g, b := parseHex(t, hex)

	lin := func(c float64) float64 {
		if c <= 0.04045 {
			return c / 12.92
		}
		return math.Pow((c+0.055)/1.055, 2.4)
	}
	r, g, b = lin(r), lin(g), lin(b)

	lms := func(a, bb, cc float64) float64 { return math.Cbrt(a*r + bb*g + cc*b) }
	L_ := lms(0.4122214708, 0.5363325363, 0.0514459929)
	M_ := lms(0.2119034982, 0.6806995451, 0.1073969566)
	S_ := lms(0.0883024619, 0.2817188376, 0.6299787005)

	l = 0.2104542553*L_ + 0.7936177850*M_ - 0.0040720468*S_
	A := 1.9779984951*L_ - 2.4285922050*M_ + 0.4505937099*S_
	B := 0.0259040371*L_ + 0.7827717662*M_ - 0.8086757660*S_

	c = math.Hypot(A, B)
	h = math.Mod(math.Atan2(B, A)*180/math.Pi+360, 360)
	return l, c, h
}

func parseHex(t *testing.T, hex string) (r, g, b float64) {
	t.Helper()
	s := strings.TrimPrefix(hex, "#")
	if len(s) != 6 {
		t.Fatalf("not a six-digit hex colour: %q", hex)
	}
	v := func(i int) float64 {
		n, err := strconv.ParseUint(s[i:i+2], 16, 8)
		if err != nil {
			t.Fatalf("bad hex %q: %v", hex, err)
		}
		return float64(n) / 255
	}
	return v(0), v(2), v(4)
}

// The helper has to agree with the generator, or every assertion built on it is
// measuring something else. palette.json declares amber at hue 76.0 and fault
// at 28.0; round-tripping the generated hex must land back on those.
func TestOklchHelperAgreesWithTheBrandSpec(t *testing.T) {
	// Tolerances differ per colour because sRGB's gamut does. amber.base and
	// fault.base sit inside it and round-trip almost exactly. amber.bright
	// (L0.871 C0.128 H76) does not: the red channel clips, and clipping moves
	// hue, so the generated #ffc96e measures 78.9. That is the value the Linux
	// console's slot 11 already carries, so it is the brand as it reaches a
	// screen rather than an error.
	for _, c := range []struct {
		name    string
		hex     string
		wantL   float64
		wantHue float64
		hueTol  float64
	}{
		{"amber.base", "#ffaf03", 0.811, 76.0, 1.5},
		{"amber.bright", "#ffc96e", 0.871, 76.0, 4.0},
		{"fault.base", "#d42320", 0.560, 28.0, 1.5},
	} {
		l, _, h := oklchOf(t, c.hex)
		// The generated hex is quantised to 8 bits per channel, so the round
		// trip cannot be exact. Tight enough to catch a wrong transform.
		if math.Abs(l-c.wantL) > 0.01 {
			t.Errorf("%s lightness = %.3f, want %.3f", c.name, l, c.wantL)
		}
		if math.Abs(h-c.wantHue) > c.hueTol {
			t.Errorf("%s hue = %.1f, want %.1f (+/- %.1f)", c.name, h, c.wantHue, c.hueTol)
		}
	}
}
