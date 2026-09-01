# Furcate's fork of tuios

This is the interface a Furcate machine shows you.

Furcate is an operating system for running clusters of machines — for AI,
physical AI, and data. Its interface is a terminal, so the terminal is not
somewhere an operator goes to administer the machine: it is what the machine
*is*, from the login prompt onward. tuios is that layer. Every box running the
full OS carries it; less capable machines run the smaller Furcate and appear as
objects in the console of one that does.

Upstream is [Gaurav-Gosain/tuios](https://github.com/Gaurav-Gosain/tuios), MIT.
This fork adds a palette, a default, two config files and a package, and fixes
four bugs it found on the way.

## What changed

| | |
|---|---|
| `internal/theme/furcate.go` | the distribution's palette, compiled in |
| `internal/config/` | that palette as the default |
| `furcate-os/` | the config and the login hook |
| `packaging/` | `.deb` per architecture, and the installer |

Everything else is upstream. The changes are deliberately small and mostly
additive so a rebase stays cheap:

```sh
git fetch upstream && git rebase upstream/main
```

The exception is `internal/session/theme_palette.go`, which fixes a daemon bug
rather than adding to it. If upstream takes that fix, drop ours.

## The palette is generated, not chosen

None of the sixteen colours was picked. They are what `furcate-cli`'s
`deploy/os/branding/palette.json` produces: three roles defined once in OKLCH —
amber at hue 76, fault at hue 28, neutral at chroma zero — with four steps that
move lightness and chroma. The same file already generates the shell's escape
codes, the login banner and the Linux console's slot remaps, and says in its own
comments that further surfaces should read it rather than re-deriving values by
eye, "which is how the same brand ends up three slightly different colours".

To change the brand, change `palette.json`, run
`deploy/os/branding/make-palette.sh`, and update the constants in
`internal/theme/furcate.go` to match.

The tests do not freeze the hex values. They assert what the language *means*:
weights ordered so a measured figure reads brighter than the label beside it,
both ambers still amber, a fault plainly not amber, guest colours quieter than
the brand so somebody else's `ls` cannot be the loudest thing on a screen whose
job is showing which machine needs attention, and everything legible on the
ground it is drawn on. Choosing a better amber is a design decision and passes;
choosing one nobody can read does not.

One thing a plausible edit breaks: `amber.bright` is outside sRGB. The red
channel clips and the hue lands at 78.9 rather than 76.0. That is the brand as
it reaches a screen — the Linux console's slot 11 already carries exactly that
value — not a rounding error to be tightened away.

## Logging in

`furcate-os/profile-tuios.sh` replaces the block in `furcate-cli`'s
`branding/profile.sh` that ran `furcate-console` directly. The console still
runs; it is the program in the first pane rather than the whole of the screen.
That is the point — it now has somewhere to sit beside a shell, a log, or
another machine, and the session outlives the connection it was started over,
which matters most on the machines this is reached over.

One session per machine, named `furcate`. The first login since boot creates it
and `exec`s the console into the window the daemon makes; every login after
attaches to what is there. `exec` rather than a second window because a detached
session always gets an initial one, so adding the console beside it would land
the operator on a bare shell with the interface behind it.

Nothing `exec`s tuios, so quitting drops to a shell rather than logging you out,
and a missing binary falls back to the one-screen summary. A machine somebody
walked up to must never be left with nothing.

`FURCATE_TUI=0` opts out entirely.

## The bar

Three cells, each a `furcatectl dock` subcommand
([furcate-cli#2](https://github.com/furcateai/furcate-cli/pull/2)) whose first
line of stdout becomes the cell.

They are read-only. Every Furcate action needs an operator signature over a
nonced order, and a status bar with a lever on it would be a hole in the
authority model wearing a convenient shape. The console reads; `furcatectl`
acts.

A cell with nothing to say prints nothing and none is drawn, so the bar is short
when the machine is fine and a cell appearing is itself the signal.

## Building

```sh
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dist/tuios-linux-amd64 ./cmd/tuios
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o dist/tuios-linux-arm64 ./cmd/tuios
# and tuios-web the same way
packaging/build-deb.sh 1.0.0
packaging/deploy.sh --stage server1 server2 spark
```

Static on both architectures, so the packages carry no runtime dependency and
drop into a sysext cleanly. `packaging/README.md` covers why everything ships
under `/usr` and how the config is adopted into `/etc` without ever writing over
an operator's edit.

## Running the tests on a Mac

```sh
TMPDIR=/tmp/tt go test ./...
```

The short `TMPDIR` is not optional. macOS puts temporary directories under
`/var/folders/...`, and with a test's name appended the Unix socket path passes
darwin's 104-byte limit — which fails 293 tests with `bind: invalid argument`
and looks like the tree is broken. It is not; the paths are just too long.
