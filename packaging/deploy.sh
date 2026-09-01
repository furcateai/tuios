#!/bin/sh
# Install the interface on a Furcate machine.
#
# Takes the .deb built for that machine's architecture, copies it over, and
# installs it. Nothing clever: dpkg does the work and this is the wrapper that
# picks the right package and says what happened.
#
# ## Why this does not restart anything
#
# A running session daemon keeps serving the build it started from, so the new
# binary is not what anybody is looking at until the daemon is restarted. That
# is deliberate on both sides: the package says so rather than restarting, and
# so does this. An operator in the middle of something on a machine they are
# worried about should be the one who decides when their panes go away —
# sessions are saved and restored across the restart, but the moment is theirs.
#
# The first install on a machine has nothing running and needs no restart at
# all; the interface is there at the next login.
#
# Usage:
#   packaging/deploy.sh HOST [HOST...]        install
#   packaging/deploy.sh --stage HOST [...]    copy only, install by hand later
#
# The staging form exists for machines carrying live work, where the copy and
# the install want to be separate decisions made at separate moments.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")
dist="$root/dist"
version="${FURCATE_TUI_VERSION:-1.0.0}"

stage_only=0
if [ "${1:-}" = --stage ]; then
    stage_only=1
    shift
fi

[ $# -ge 1 ] || { echo "usage: $0 [--stage] HOST [HOST...]" >&2; exit 2; }

for host in "$@"; do
    # The machine's own architecture, not an assumption. A fleet with both is
    # the ordinary case here — the accelerated node is aarch64 and the servers
    # are x86-64 — and installing the wrong one is a mistake dpkg would catch
    # but only after the copy.
    arch=$(ssh "$host" 'dpkg --print-architecture' 2>/dev/null) || {
        echo "$host: cannot reach it, or it is not a dpkg machine" >&2
        continue
    }

    deb="$dist/furcate-tui_${version}_${arch}.deb"
    [ -f "$deb" ] || {
        echo "$host: no package for $arch — run packaging/build-deb.sh" >&2
        continue
    }

    echo "==> $host ($arch)"
    scp -q "$deb" "$host:/tmp/" || { echo "$host: copy failed" >&2; continue; }

    # Checked after the copy rather than trusted. A truncated package installs
    # as a corrupt binary, and the machine this is going to is one somebody
    # needs to be able to reach.
    want=$(shasum -a 256 "$deb" | cut -d' ' -f1)
    got=$(ssh "$host" "sha256sum /tmp/$(basename "$deb") | cut -d' ' -f1")
    [ "$want" = "$got" ] || {
        echo "$host: the copy does not match what was built — not installing" >&2
        continue
    }
    echo "    copied, sha256 matches"

    if [ "$stage_only" = 1 ]; then
        echo "    staged at /tmp/$(basename "$deb"); install with:"
        echo "      ssh $host 'sudo dpkg -i /tmp/$(basename "$deb")'"
        continue
    fi

    ssh -t "$host" "sudo dpkg -i /tmp/$(basename "$deb")" || {
        echo "$host: install failed" >&2
        continue
    }

    # What the machine actually has now, read back rather than assumed.
    ssh "$host" 'tuios --version 2>/dev/null | head -1' || true
done
