# furcate --pane VIEW — open one part of the system in its own window.
#
# This is the case block the front door (`/usr/bin/furcate`) is missing. The
# desktop entries generated from arms.toml have named it since they were
# written — every one of them is `Exec=furcate --pane <view>` — and nothing
# implemented it, so the launcher's rows all failed with "unknown command".
#
# ## Why a window and not a screen
#
# The console used to answer this by drawing its whole screen and opening on
# the named section. That made every part of the system the same program in a
# different mood: one view at a time, one machine at a time, and a window
# manager underneath with nothing to manage.
#
# A pane is the honest unit. `furcate --pane power` opens power in a window; run
# it again with another name and the two sit beside each other, tiled by tuios,
# on a workspace the operator chose. That is what makes the launcher worth
# having — the parts compose instead of replacing each other.
#
# ## Why it goes through the daemon
#
# Asking tuios to open the window, rather than drawing in the terminal this was
# typed into, is what lets the launcher work from anywhere: a row picked in the
# app launcher, a hook, `ssh host furcate --pane fleet`. The window lands in the
# session that is already on the machine's screen, which is where the operator
# is looking.
#
# Outside a session it falls back to running the view directly, because a
# machine with no session yet still has to be able to show one thing.

pane_cmd() {
    _view=$1
    case $_view in
        # The subjects that have a view of their own. Named here rather than
        # passed through, so a typo in a desktop file fails with a list instead
        # of spawning a process that exits immediately.
        machine | power | workloads | fleet)
            printf '%s view %s' "$CTL" "$_view"
            ;;
        *)
            return 1
            ;;
    esac
}

furcate_pane() {
    _view=${1:-}
    [ -n "$_view" ] || {
        echo "furcate --pane: which part? machine, power, workloads, fleet" >&2
        return 2
    }

    _cmd=$(pane_cmd "$_view") || {
        echo "furcate --pane: no view called '$_view'" >&2
        echo "  try: machine, power, workloads, fleet" >&2
        return 2
    }

    TUI=${FURCATE_TUI_BIN:-/opt/furcate/tui/bin/tuios}

    # Inside a session already, or one is running on this machine: put the
    # window there. The operator is looking at that screen, and a second
    # interface started beside it would be a window nobody sees.
    if [ -x "$TUI" ] && "$TUI" ls >/dev/null 2>&1; then
        # -- so the view's own arguments are not read as tuios flags. Without
        # it a `-c` in the command line is taken as tuios's own and the window
        # never opens, which is a failure that looks like the program crashing.
        # shellcheck disable=SC2086
        "$TUI" new-window -s furcate "$_view" -- /bin/sh -c "exec $_cmd"
        return $?
    fi

    # No session. Run it here rather than starting one: somebody who typed this
    # in a plain terminal asked to see the thing, not to be moved into an
    # interface they did not ask for.
    # shellcheck disable=SC2086
    exec $_cmd
}
