# Put the console back in its pane after a restore.
#
# Installed to /etc/bash.bashrc.d/ (or appended to /etc/bash.bashrc where that
# directory is not read), because this has to run in a *pane*, and a pane is not
# a login shell — tuios spawns a plain interactive bash, so nothing in
# /etc/profile.d is read there.
#
# ## The problem
#
# Resurrection brings back a session's structure and not its processes. That is
# documented and deliberate: every window gets a fresh shell in its saved
# working directory, and the daemon has no memory of what was running in it. So
# after a reboot the pane that held the console comes back as a bash prompt
# still carrying the console's name — worse than either a console or an honest
# shell, because the name says one thing and the pane does another.
#
# ## How the pane knows it is the console
#
# By the directory it is standing in. A restored shell's environment carries
# TUIOS_RESTORED and the socket and nothing else; the window's name is a hook
# variable and never reaches the pane. The working directory, though, *is*
# restored — so the console's window is opened in a marker directory and
# recognises itself by being there.
#
# That is also why the marker is a directory of its own rather than, say,
# /var/lib/furcate-tui: it has to be a path no other pane would plausibly be
# sitting in when the daemon went away.

case $- in
    # Non-interactive shells run this file too on some configurations, and a
    # scp or an rsync that suddenly exec'd a full-screen console would be a
    # transfer that never completes.
    *i*) ;;
    *) return 0 ;;
esac

if [ "${TUIOS_RESTORED-}" = 1 ] &&
   [ "$PWD" = /var/lib/furcate-tui/console ] &&
   [ "${FURCATE_TUI-1}" != 0 ] &&
   [ -x /usr/bin/furcate-console ]; then
    # The machine's own environment first.
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
    # exec, so the pane is the console rather than a shell with a console in
    # front of it — and so quitting closes the pane the way it does on a first
    # login rather than dropping to a prompt in a marker directory.
    exec /usr/bin/furcate-console
fi
