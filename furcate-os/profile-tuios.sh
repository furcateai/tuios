# Furcate: logging in puts you in the interface.
#
# Replaces the block in deploy/os/branding/profile.sh that ran
# /usr/bin/furcate-console directly. The difference is what the operator lands
# in: not one screen, but the environment the screen lives in — panes they can
# split, a session that outlives the connection, and the console occupying the
# first window rather than being the whole of it.
#
# ## Why this is the login shell's job and not a display manager's
#
# This distribution's interface is a terminal. There is no X session to start
# and no greeter to configure, so the place where "somebody has just logged in"
# is known is the profile — the same place the banner and the prompt are
# already decided. Putting it here also means it works identically for a person
# standing at the machine and a person arriving over SSH, which is the property
# that matters: an operator should not have to remember which way in they took.
#
# ## What it does not do
#
# It does not exec. `Ctrl+B q` returns here and drops to the shell, which is
# where somebody who wants a plain terminal needs to end up, and where the
# fallback lands if tuios is missing or refuses to start. A machine somebody
# walked up to must never be left with nothing — that rule is inherited from
# the console block this replaces and is the reason for every `|| true` below.
#
# Set FURCATE_TUI=0 to log in to a plain shell.

# --- the interface, once, in the right place ---------------------------------
# Where the interface is installed.
#
# /opt rather than /usr/bin: a Furcate machine's /usr is a merged sysext, a
# signed verity image mounted read-only, so nothing can be installed there
# without rebuilding and re-signing the distribution image. /opt is the other
# hierarchy a sysext may carry and is real writable disk on these machines,
# which lets the interface be updated on its own schedule rather than the
# distribution's.
FURCATE_TUI_BIN=${FURCATE_TUI_BIN:-/opt/furcate/tui/bin/tuios}

# The furcatectl the views live in.
#
# Beside the interface rather than /usr/bin: /usr is read-only on a
# Furcate machine, so the system copy cannot be updated without
# rebuilding the signed image, and the views are part of the interface
# rather than of the base. Falls back to the system one, which is right
# for a machine where only the base is installed.
FURCATE_CTL=${FURCATE_CTL:-/opt/furcate/tui/bin/furcatectl}
[ -x "$FURCATE_CTL" ] || FURCATE_CTL=/usr/bin/furcatectl

# The machine's own environment, before anything is started in it.
#
# furcated binds the address in FURCATE_LISTEN — the tailnet address, not
# loopback — while furcatectl and the console both default to 127.0.0.1:7616.
# Without it every pane draws a machine that looks dead.
#
# /etc/furcate/env is the canonical source and is root-only (0640 root:root),
# so an operator's shell cannot read it and zz-furcate-env.sh silently does
# nothing for them. systemd will say what it gave the unit, though, and that
# needs no privilege — so the file is preferred when it is readable and the
# unit is asked when it is not.
furcate_env() {
    if [ -r /etc/furcate/env ]; then
        set -a
        . /etc/furcate/env
        set +a
        return 0
    fi
    [ -n "${FURCATE_LISTEN-}" ] && return 0

    # Ask the socket, not the configuration.
    #
    # systemd will report the unit's Environment= without privilege, but the
    # real address comes from the EnvironmentFile it cannot show — so on this
    # fleet it answers 127.0.0.1:7616 while the agent is actually bound to the
    # tailnet address, which is a wrong answer rather than no answer. What the
    # agent is listening on is visible to anyone in `ss`, and it is the thing
    # that is true rather than the thing that was asked for.
    command -v ss >/dev/null 2>&1 || return 0
    _listen=$(ss -ltn 2>/dev/null |
        sed -n 's/.*LISTEN[[:space:]]\+[0-9]\+[[:space:]]\+[0-9]\+[[:space:]]\+\([^[:space:]]*:7616\).*/\1/p' |
        head -1)
    # A wildcard bind is reachable on loopback, and loopback is the shorter
    # path to the same process.
    case $_listen in
        '0.0.0.0:7616' | '*:7616' | '[::]:7616') _listen=127.0.0.1:7616 ;;
    esac
    # Both names. The console reads FURCATE_NODE_ADDR and furcatectl reads
    # FURCATE_NODE; FURCATE_LISTEN is what the agent itself is configured with.
    # Setting one and not the others is how a screen ends up half answering.
    if [ -n "$_listen" ]; then
        export FURCATE_LISTEN="$_listen"
        : "${FURCATE_NODE_ADDR:=$_listen}"; export FURCATE_NODE_ADDR
        : "${FURCATE_NODE:=$_listen}"; export FURCATE_NODE
    fi
    unset _listen
}
furcate_env

if [ -z "${FURCATE_GREETED-}" ] && [ -t 1 ]; then
    FURCATE_GREETED=1
    export FURCATE_GREETED

    # Already inside it. tuios runs the login shell in its own panes, so
    # without this every pane would try to open another tuios inside itself.
    # $TUIOS_SESSION is set by the daemon in the environment it gives a pane.
    if [ -n "${TUIOS_SESSION-}" ] || [ -n "${TUIOS_SOCKET-}" ]; then
        :
    elif [ "${FURCATE_TUI-1}" != 0 ] && [ -x "$FURCATE_TUI_BIN" ]; then
        # The console's own sixteen, before anything is drawn in them.
        #
        # TERM=linux is a sixteen-colour terminal whose slots are the kernel's
        # defaults, so an RGB theme has nothing to land in: tuios falls back to
        # those defaults and the screen comes up in the VT's green, red and
        # blue rather than in Furcate's amber.
        #
        # All sixteen, not the four palette.sh remaps. That function exists for
        # the shell prompt and the login banner, which only ever use amber,
        # dim, fault and the bright amber — but tuios draws its borders, its
        # title bars and its dock out of the rest, and leaving those at the
        # kernel's palette is exactly why the interface came up with green
        # borders around salmon bars on a blue ground.
        #
        # The values are the ones internal/theme/furcate.go ships, so the
        # machine's own screen and a terminal over SSH are the same brand
        # rather than two readings of it. Regenerate both from
        # deploy/os/branding/palette.json.
        # Sixteen colours, because the console has sixteen.
        #
        # Ubuntu's `linux` terminfo entry declares colors#8. That is what
        # decides how far a palette is degraded before it is drawn, so the
        # theme was being folded down to eight and the bright half — every
        # measured figure, every focused border — was landing on the wrong
        # slot. The remap below was correct and could not be seen.
        #
        # `linux-16color` describes the same terminal with colors#16, which is
        # what a Linux VT has actually had since it gained the OSC P sequences
        # this file uses to repaint them.
        case "${TERM:-}" in
            linux)
                if infocmp linux-16color >/dev/null 2>&1; then
                    TERM=linux-16color
                    export TERM
                fi
                ;;
        esac

        case "${TERM:-}" in
            linux | linux-*)
                printf '\033]P016120c\033]P1d42320\033]P26b8f3a\033]P3ffaf03'
                printf '\033]P44a6b8a\033]P57a5c8a\033]P64a8a8a\033]P7868686'
                printf '\033]P8747474\033]P9d4594e\033]PA8fb35a\033]PBffc96e'
                printf '\033]PC6a8bad\033]PD9a7cad\033]PE6aadad\033]PFf0e6d2'
                ;;
        esac

        # The banner is cleared so the interface takes its place rather than
        # queueing underneath it. On a local console agetty has already painted
        # the pre-login screen; over SSH this is the first thing drawn.
        printf '\033[H\033[2J'

        # One session per machine, created on the first login since boot and
        # attached to on every one after it.
        #
        # This is the whole reason the daemon is worth having: an operator whose
        # link drops reattaches to the panes they left, on a machine they were
        # in the middle of working on. The name is fixed rather than generated
        # so that reconnecting gets *the* session back instead of starting a
        # second one beside the first.
        #
        # The console goes in the first window, and only when the session is
        # being created. `startup.layout` cannot do this — it names a tiling
        # scheme, not what to run — and doing it on every login would open a
        # second console beside the one the operator left running.
        #
        # Asked as JSON rather than by grepping the table: the human listing is
        # for reading and its columns are free to change, and a session called
        # something like "furcate-old" would match a prefix on the text one.
        # `tuios ls` exits 3 when the daemon is not running, which is not an
        # error here — it means there is certainly no session yet.
        if ! "$FURCATE_TUI_BIN" ls --json 2>/dev/null |
            grep -q '"name"[[:space:]]*:[[:space:]]*"furcate"'; then
            # Detached, because the alternative does not work here: a plain
            # `tuios new` attaches, and there is no terminal to attach to at
            # this point in a login.
            # The marker the restored pane recognises itself by. Created
            # before the session so the window can be opened standing in it.
            mkdir -p /var/lib/furcate-tui/console 2>/dev/null || true

            "$FURCATE_TUI_BIN" new furcate --detach 2>/dev/null || true

            # The views go in panes; the old full-screen console does not.
            #
            # furcate-console drew its own screen — a rail down the left, one
            # detail pane, a footer, a fixed 78-column layout — and running it
            # here put that screen over the top of the window manager, so the
            # machine showed a program with tuios hidden behind it. That is the
            # UI this replaces rather than wraps.
            #
            # Each view is its own window. The daemon's initial window becomes
            # the first of them, and the rest are opened beside it; tuios tiles
            # them, titles them, and gives the operator the palette and the
            # launcher to reach everything else.
            first=$("$FURCATE_TUI_BIN" list-windows -s furcate --json 2>/dev/null |
                sed -n 's/.*"window_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
                head -1)
            if [ -n "$first" ]; then
                # cd first, so the window's saved working directory is the
                # marker that lets the pane recognise itself after a restore,
                # when its environment carries nothing else that would say so.
                # Double-quoted so the path expands here, in this shell,
                # rather than being sent literally for the pane's shell to
                # resolve — it has no such variable and would run nothing.
                "$FURCATE_TUI_BIN" send-text -s furcate -w "$first" \
                    "cd /var/lib/furcate-tui/console && exec $FURCATE_CTL view machine
" 2>/dev/null || true
                "$FURCATE_TUI_BIN" set-window -s furcate -w "$first" --name machine \
                    2>/dev/null || true
            fi

            # The rest of workspace 1: the machine, at a glance.
            #
            # Four subjects is what answers "is this all right" without anybody
            # pressing a key. Everything else lives on a page of its own.
            for _v in power workloads fleet; do
                "$FURCATE_TUI_BIN" new-window -s furcate "$_v" -- \
                    $FURCATE_CTL view "$_v" 2>/dev/null || true
            done
            unset _v

            # Tiled, so all four are visible at once rather than stacked with
            # three of them hidden.
            "$FURCATE_TUI_BIN" set-layout -s furcate bsp 2>/dev/null || true

            # The pages.
            #
            # Alt+1..9 switches between them, and the dock shows which is
            # current — so the subsystems are reachable by one key rather than
            # by knowing a command. This is the structure the ecosystem grows
            # into: a workspace per subject, and a new primitive lands on the
            # page it belongs to rather than crowding the overview.
            #
            # Opened with --no-focus so building them does not drag the screen
            # away from workspace 1, which is where the operator should arrive.
            _page() {
                "$FURCATE_TUI_BIN" new-window -s furcate "$2" \
                    --workspace "$1" --no-focus -- "$3" $4 2>/dev/null || true
            }

            # 2 — what is deployed, and what serves it.
            _page 2 sites      "$FURCATE_CTL" "deploy list"
            _page 2 cdn        "$FURCATE_CTL" "cdn list"

            # 3 — what this machine can be asked for.
            _page 3 resources  "$FURCATE_CTL" "resources"
            _page 3 admission  "$FURCATE_CTL" "admission"

            # 4 — who may change it, and what it has refused.
            _page 4 authority  "$FURCATE_CTL" "policy"
            _page 4 keys       "$FURCATE_CTL" "keys"
            _page 4 record     "$FURCATE_CTL" "ledger"

            # 5 — what it reasons with.
            _page 5 models     "$FURCATE_CTL" "model list"
            _page 5 advisor    "$FURCATE_CTL" "advisor show"

            # 6 — how the world reaches it.
            _page 6 network    "$FURCATE_CTL" "network show"
            _page 6 tunnels    "$FURCATE_CTL" "tunnels"
            _page 6 published  "$FURCATE_CTL" "published"

            unset -f _page
        fi

        # Land in window-management mode, not in a pane.
        #
        # `startup.start_in_terminal_mode = false` decides how a *new* session
        # starts and does not survive an attach: attaching focuses a window,
        # and a window running a program takes the keys. So the machine's own
        # screen came up with Tab, the arrows and the number keys all being
        # forwarded into a status view that has no use for them — the interface
        # looked frozen when it was simply listening somewhere else.
        #
        # Sent after the attach, in the background, because the attach does not
        # return until the operator leaves. A second is long enough for the
        # client to be reading keys and short enough that nobody sees it.
        (
            sleep 1
            "$FURCATE_TUI_BIN" send-keys -s furcate alt+esc >/dev/null 2>&1
        ) &

        # -c so that a daemon which died between the check above and here still
        # leaves the operator somewhere rather than at a bare shell.
        "$FURCATE_TUI_BIN" attach furcate -c 2>/dev/null || true

        # Whatever happened above, the operator is back at a shell now and the
        # screen still holds the interface's last frame.
        printf '\033[H\033[2J'
    fi

    # The one-screen summary, for a shell reached with the interface disabled,
    # missing, or exited. It is the fallback's whole content: a machine that
    # cannot draw its interface still has to say what it is.
    [ -x /usr/lib/update-motd.d/00-furcate ] && /usr/lib/update-motd.d/00-furcate
fi
