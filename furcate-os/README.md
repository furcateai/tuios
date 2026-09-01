# Furcate OS

What makes this fork the distribution's interface rather than a terminal
multiplexer somebody installed.

Furcate is an operating system for running clusters of machines — for AI,
physical AI, and data. Its interface is a terminal, so the terminal is not
somewhere you go to administer the machine: it is what the machine shows you.
tuios is that layer. Every box running the full OS gets it; less capable
machines run the smaller Furcate and are rendered as objects in the console of
one that does.

## What is here

| file | installed to | what it does |
|---|---|---|
| `config.toml` | `/etc/xdg/tuios/config.toml` | the interface as the distribution ships it |
| `profile-tuios.sh` | `/etc/profile.d/` | logging in puts you in the interface |

Both are defaults, not policy. `/etc/xdg` is the system config directory
`XDG_CONFIG_DIRS` names on this distribution, so an operator's own
`~/.config/tuios/config.toml` overrides it key by key, and `FURCATE_TUI=0` opts
out of the interface entirely.

## The palette is generated, not chosen

`internal/theme/furcate.go` carries the sixteen colours, and none of them was
picked. They are what `furcate-cli`'s `deploy/os/branding/palette.json` produces:
three roles defined once in OKLCH — amber at hue 76, fault at hue 28, neutral at
chroma zero — with four steps that move lightness and chroma. The same file
already generates the shell's escape codes, the login banner and the Linux
console's slot remaps, and says in its own comments that further surfaces should
read it rather than re-deriving values by eye, "which is how the same brand ends
up three slightly different colours".

Regenerate with `deploy/os/branding/make-palette.sh` in furcate-cli, then update
the constants in `internal/theme/furcate.go` to match.

The tests in `internal/theme/furcate_test.go` do not freeze the hex values.
They assert what the design language means: weights ordered so a measured figure
reads brighter than the label beside it, both ambers still amber, a fault plainly
not amber, guest colours quieter than the brand, and everything legible on the
ground it is drawn on. Choosing a better amber is a design decision and does not
fail the build; choosing one nobody can read does.

## Login

`profile-tuios.sh` replaces the block in `furcate-cli`'s
`deploy/os/branding/profile.sh` that ran `furcate-console` directly. The console
still runs — it is the program in the first pane — but it now has somewhere to
sit beside a shell, a log, or another machine, and the session survives the
connection that started it.

One session per machine, named `furcate`. First login since boot creates it and
`exec`s the console into the window the daemon makes; every login after that
attaches to what is already there. It does not `exec` tuios, so quitting drops to
a shell rather than logging you out, and a missing or broken binary falls back to
the one-screen summary — a machine somebody walked up to must never be left with
nothing.

## The dock

Three cells, each a `furcatectl dock` subcommand whose first line of stdout
becomes the cell: what the machine is drawing and whether it is being held below
its rating, what it has concluded about itself and cannot act on alone, and which
machine this is and which site administers it.

They are read-only, and deliberately so. Every Furcate action needs an operator
signature over a nonced order, and a status bar with a lever on it would be a
hole in the authority model wearing a convenient shape. The console reads;
`furcatectl` acts.

A cell with nothing to say prints nothing and no cell is drawn, so the bar is
short when the machine is fine and grows when it is not — which makes a cell
appearing the signal. Each one distinguishes "nothing is wrong" from "I could not
tell", because a reassuring blank printed by an unreachable agent is the one
failure that would make the bar worse than no bar.

## Keeping up with upstream

```sh
git remote add upstream https://github.com/Gaurav-Gosain/tuios.git   # once
git fetch upstream && git rebase upstream/main
```

Furcate's changes are deliberately small and mostly additive — a theme
registered as a built-in, a default, a config, a profile script — so a rebase
should stay cheap. The exception is `internal/session/theme_palette.go`, which
fixes a bug in the daemon rather than adding to it; if upstream takes that fix,
drop ours.
