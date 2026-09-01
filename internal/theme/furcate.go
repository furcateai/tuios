package theme

import (
	tint "github.com/lrstanley/bubbletint/v2"
)

// Furcate's palette, as the window manager draws it.
//
// The values here are NOT chosen. They are the ones
// `deploy/os/branding/palette.json` in furcate-cli generates: three roles
// defined once in OKLCH — amber at hue 76, fault at hue 28, neutral at chroma
// zero — with four steps that move lightness and chroma and never hue. The same
// file already emits the shell's escape codes, the login banner's colours and
// the Linux console's slot remaps, and it says in its own comments that further
// surfaces should read it rather than re-deriving values by eye, "which is how
// the same brand ends up three slightly different colours".
//
// This file is that promise kept for the window manager. Every hex below is
// reproduced by:
//
//	deploy/os/branding/make-palette.sh
//
// and TestFurcatePaletteMatchesBranding pins them, so a change to the brand
// fails here instead of drifting.
//
// ## Why hue never moves
//
// Amber's bright step is the same hue with more light in it, not a lighter
// yellow. The palette's own note records what happened every time it was picked
// by eye from a 256-colour chart instead: xterm 220 is 19 degrees off the amber
// and 215 is 12 the other way, and both were reported from across a room as
// "that is not the same colour". Bold resolves to the bright slot on a
// sixteen-colour console, so a stock bright yellow there paints every measured
// figure wrong. Yellow and BrightYellow below are therefore one hue by
// construction.
//
// ## Amber, not green
//
// Green phosphor is the cliché — every terminal in every film since 1983 — and
// it carries the wrong association: intrusion, other people's machines. Amber
// was what you got on the equipment that ran things, DEC's VT220 among them,
// and it reads as a control room rather than a break-in. This system's subject
// is a machine that belongs to somebody, so the palette says so.
//
// ## What the roles mean
//
// Amber is the system's own voice: structure, labels, the frame. Bright amber
// is measured — a figure that came off an instrument. Neutral is context: units
// and anything always present. Fault is the one thing on screen that is not
// amber, because a fault has to be findable before the screen has been read.
//
// Blue, cyan, purple and green are not spare slots. theme.go derives the whole
// chrome from them — the focused border is BrightCyan in window mode and
// BrightGreen in terminal mode, the dock's mode indicator is BrightBlue — so
// whatever goes in them is what the interface is framed in. A palette that left
// them as literal green and cyan drew a green and cyan frame around amber
// content, which read as somebody else's terminal with Furcate's text in it.
//
// They are therefore amber as well, separated from the voice by weight rather
// than by hue. Guest programs asking for green or cyan still get something
// legible; they simply do not get to put a second accent on a screen whose job
// is showing which machine needs attention.
var furcateTint = tint.Tint{
	ID:          "furcate",
	DisplayName: "Furcate",
	Dark:        true,

	// Not pure black. Amber on a true #000 rings on an LCD, and this is a
	// screen somebody reads for hours on a machine they are worried about.
	Bg: tint.FromHex("#0d0b08"),
	// The system's own voice is the default for unmarked text.
	Fg:     tint.FromHex(FurAmberBase),
	Cursor: tint.FromHex(FurAmberBase),
	// A highlight behind the text rather than a second background competing
	// with the first.
	SelectionBg: tint.FromHex("#3a2c10"),

	// Slot 0. What a filled bar draws its text in — stated black on colour,
	// never reverse video, which is what FUR_REV does in the shell palette.
	Black: tint.FromHex("#16120c"),
	// fault.base. Slot 1, matching the console remap.
	Red: tint.FromHex(FurFaultBase),
	// Green, blue, cyan and purple are not decoration here and they are not
	// free either: theme.go derives the chrome from them. A focused border in
	// window mode is BrightCyan, in terminal mode BrightGreen, an unfocused one
	// is Red, and the dock's mode indicator is BrightBlue or BrightGreen. A
	// palette that kept them as literal green and cyan therefore drew a green
	// and cyan frame around amber content — which is exactly how the first
	// screens looked, and why it read as somebody else's terminal with
	// Furcate's text in it.
	//
	// So they are amber too, separated by weight rather than by hue. The
	// interface is one colour, the way the console it replaces was, and the
	// three that carry meaning — measured, warning, fault — are still the only
	// things that differ from it.
	//
	// A guest program asking for green still gets something green-ish enough to
	// be legible; it simply does not get to put a second accent on the screen.
	Green: tint.FromHex("#8a6a1e"),
	// amber.base. Slot 3, matching the console remap.
	Yellow: tint.FromHex(FurAmberBase),
	Blue:   tint.FromHex("#7a5f1a"),
	Purple: tint.FromHex("#8a6a2a"),
	Cyan:   tint.FromHex("#9a7a2a"),
	// neutral.bright, so ordinary text sits above the dim slot without
	// reaching the brightness that means "measured".
	White: tint.FromHex(FurNeutralBright),

	// Slot 8 takes neutral.base rather than neutral.dim. palette.json is
	// explicit about why: dim is a step below the role's own lightness and at
	// L0.31 it is too dark to read on a black ground.
	BrightBlack: tint.FromHex(FurNeutralBase),
	BrightRed:   tint.FromHex(FurFaultBright),
	BrightGreen: tint.FromHex("#c99a30"),
	// amber.bright. Slot 11, matching the console remap. Same hue as Yellow —
	// see the note above before changing it.
	BrightYellow: tint.FromHex(FurAmberBright),
	BrightBlue:   tint.FromHex("#d8a840"),
	BrightPurple: tint.FromHex("#c99a50"),
	// The focused border in window mode. Brightest of the chrome, because it
	// is the one that says where you are.
	BrightCyan:   tint.FromHex("#ffc96e"),
	BrightWhite:  tint.FromHex("#f0e6d2"),
}

// The generated values, named so the test and the tint cannot disagree about
// what they are. Reproduced by deploy/os/branding/make-palette.sh in
// furcate-cli from deploy/os/branding/palette.json.
const (
	FurAmberBright = "#ffc96e" // amber.bright — measured
	FurAmberBase   = "#ffaf03" // amber.base   — the system's voice
	FurAmberWarn   = "#d18c00" // amber.warn   — moving the wrong way
	FurFaultBright = "#d4594e" // fault.bright
	FurFaultBase   = "#d42320" // fault.base   — needs a human

	FurNeutralBright = "#868686" // neutral.bright
	FurNeutralBase   = "#747474" // neutral.base — context
)

// registerFurcate adds Furcate's palette to the registry as a built-in.
//
// Compiled in rather than shipped as a JSON file in the themes directory. That
// directory belongs to the operator, and a distribution whose own palette could
// be removed by tidying a config folder would come up looking like a machine
// nobody had configured. A file there using the same id still wins, which is
// the right way round: the operator's copy overrides, and there is always one
// to fall back to.
func registerFurcate() {
	tint.Register(&furcateTint)
}
