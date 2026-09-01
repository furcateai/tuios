#!/bin/sh
# Build furcate-tui .deb packages from the binaries in dist/.
#
# Written as `ar` and two tarballs rather than as a debhelper rules file,
# because the binaries are cross-compiled Go and there is nothing for
# dpkg-buildpackage to do that this does not: no compilation, no shared library
# to scan, no debug symbols to split. It runs anywhere with ar and tar, which
# includes the Mac these are built on. A machine with dpkg-deb can use that
# instead and get a byte-identical result.
#
# Usage: packaging/build-deb.sh [version]
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")
dist="$root/dist"
version="${1:-1.0.0}"

[ -d "$dist" ] || { echo "no dist/ — run the go builds first" >&2; exit 1; }

# Refuse to package a binary older than the source it claims to be.
#
# This shipped a stale tuios four times running: the theme was edited, the .deb
# rebuilt, the version bumped, the package installed — and the binary inside it
# was the one from before the edit, because building the .deb never rebuilt the
# Go. Every symptom pointed at the palette and the palette was already right.
#
# Comparing mtimes is cruder than asking the compiler, and it is enough: the
# failure was never a subtle staleness, it was a binary from an hour earlier.
newest_src=$(find "$root/internal" "$root/cmd" -name '*.go' -newer "$dist/tuios-linux-amd64" -print -quit 2>/dev/null || true)
if [ -n "$newest_src" ]; then
    echo "REFUSING: $newest_src is newer than dist/tuios-linux-amd64" >&2
    echo "The package would carry a binary built before that change. Rebuild:" >&2
    echo "  for a in amd64 arm64; do" >&2
    echo "    CGO_ENABLED=0 GOOS=linux GOARCH=\$a go build -trimpath \\" >&2
    echo "      -o dist/tuios-linux-\$a ./cmd/tuios" >&2
    echo "  done" >&2
    exit 1
fi

# A .deb is an ar archive of three members in a fixed order. mkar.py writes it
# directly: macOS ships BSD ar, which emits a symbol table and a header variant
# dpkg refuses, and requiring GNU binutils just to concatenate three files would
# put a toolchain between the build and the package for no reason.
MKAR="$here/mkar.py"
[ -x "$MKAR" ] || { echo "missing $MKAR" >&2; exit 1; }

# GNU tar, for --sort and --mtime. Those are what make the package
# reproducible: without a fixed order and a fixed timestamp two builds of the
# same tree differ, and then a checksum cannot answer whether a machine is
# running what was built. BSD tar (macOS's default) has neither flag, so it is
# named rather than assumed.
TAR=$(command -v gtar || command -v tar)
case $($TAR --version 2>/dev/null | head -1) in
    *GNU*) : ;;
    *) echo "GNU tar required (brew install gnu-tar gives gtar)" >&2; exit 1 ;;
esac

for arch in amd64 arm64; do
    bin="$dist/tuios-linux-$arch"
    web="$dist/tuios-web-linux-$arch"
    [ -f "$bin" ] || { echo "missing $bin" >&2; exit 1; }

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    # --- the filesystem the package lays down ---------------------------------
    # /opt, not /usr.
    #
    # A Furcate machine's /usr is a merged sysext — a signed verity image the
    # host mounts read-only — so a package writing there fails with EROFS, and
    # getting a binary in means rebuilding and re-signing the whole
    # distribution image. /opt is the other hierarchy a sysext may carry, it is
    # real writable disk on these machines, and nothing is merged over it.
    #
    # That makes the interface installable on its own schedule instead of on
    # the distribution's, which is the right shape for it: tuios is a layer on
    # Furcate, not part of the base.
    install -d "$work/root/opt/furcate/tui/bin"
    install -m755 "$bin" "$work/root/opt/furcate/tui/bin/tuios"
    [ -f "$web" ] && install -m755 "$web" "$work/root/opt/furcate/tui/bin/tuios-web"

    # On PATH without writing to /usr/bin. /etc is writable on these machines
    # even when /usr is not, and profile.d is already how the distribution puts
    # its own things in front of a login shell.

    # Both configuration files ship under /usr/share as candidates, and the
    # postinst puts them where they take effect.
    #
    # This is not indirection for its own sake: deploy/build-sysext.sh refuses
    # any package carrying /etc, and it is right to. A sysext is replaced
    # wholesale on every update, so an /etc shipped inside one would take an
    # operator's edits with it. The distribution already handles its own
    # branding this way — /usr/share/furcate/profile.sh is adopted into
    # /etc/profile.d by deploy/os/adopt — and this follows it rather than
    # inventing a second convention.
    # furcatectl, beside the interface it draws.
    #
    # /usr/bin is read-only on a Furcate machine, so the system copy cannot be
    # replaced without rebuilding the signed distribution image — and the views
    # the interface is made of live in that binary. Shipping it here lets the
    # interface and the views it calls move together, which is what they are:
    # one thing. The system copy stays where it is and keeps working for
    # everything else.
    ctl="$dist/bin/furcatectl-linux-$arch"
    [ -f "$ctl" ] && install -m755 "$ctl" "$work/root/opt/furcate/tui/bin/furcatectl"

    # gpm, so the machine's own screen has a mouse.
    #
    # Carried rather than depended on: /usr is read-only here, so `apt install
    # gpm` fails with EROFS and the package cannot be installed at all. It
    # links only libc and libm, so nothing else has to come with it.
    gpm="$dist/bin/gpm-linux-$arch"
    [ -f "$gpm" ] && install -m755 "$gpm" "$work/root/opt/furcate/tui/bin/gpm"

    # The console's palette, as a program the getty runs before it starts.
    install -m755 "$root/furcate-os/vtpalette.sh" \
        "$work/root/opt/furcate/tui/bin/vtpalette"

    install -d "$work/root/opt/furcate/tui/share"
    install -m644 "$root/furcate-os/config.toml" \
        "$work/root/opt/furcate/tui/share/config.toml"
    install -m644 "$root/furcate-os/profile-tuios.sh" \
        "$work/root/opt/furcate/tui/share/profile.sh"
    install -m644 "$root/furcate-os/restore-console.sh" \
        "$work/root/opt/furcate/tui/share/restore-console.sh"
    install -m644 "$root/furcate-os/furcate-vtpalette@.service" \
        "$work/root/opt/furcate/tui/share/furcate-vtpalette@.service"
    install -m644 "$root/furcate-os/furcate-mouse.service" \
        "$work/root/opt/furcate/tui/share/furcate-mouse.service"

    size=$(du -ks "$work/root" | cut -f1)

    # --- control -------------------------------------------------------------
    install -d "$work/ctl"
    cat > "$work/ctl/control" <<EOF
Package: furcate-tui
Version: $version
Section: admin
Priority: optional
Architecture: $arch
Maintainer: Furcate <eng@tenzro.com>
Installed-Size: $size
Recommends: furcate-cli, gpm
Homepage: https://github.com/furcateai/tuios
Description: The interface a Furcate machine shows you
 Furcate's interface is a terminal, so the terminal is not somewhere an
 operator goes to administer the machine: it is what the machine shows them.
 This package is that layer - a window manager, workspaces, a command palette
 and sessions that outlive the connection they were started over, which is the
 property that matters on machines reached over links that drop.
 .
 The operator console runs inside it rather than instead of it. Logging in
 lands in the interface with the console in the first pane, and quitting drops
 to a shell rather than logging out: a machine somebody walked up to must never
 be left with nothing.
EOF

    # No conffiles. Nothing under /etc is shipped — see above — so dpkg has
    # no operator-owned file here to protect. The copy the postinst lays down
    # is protected by the postinst itself, which never overwrites one that has
    # been edited.

# A running daemon keeps serving the build it started from, so an upgrade
    # that only replaces the binary leaves the old code running with no sign of
    # it. Saying so beats restarting somebody's session out from under them.
    # Put the shipped candidates where they take effect, and say when a
    # running daemon means the new binary is not what is being served yet.
    cat > "$work/ctl/postinst" <<'EOF'
#!/bin/sh
set -e
[ "$1" = configure ] || exit 0

# Adopt the candidates into /etc.
#
# Never over an edited copy. A file the operator has changed is a decision they
# made, and an upgrade that silently reverted it would be the package deciding
# it knows better. Both are compared against the copy adopted last time, which
# is what makes "unchanged" answerable at all: comparing against the new
# candidate would call every upgrade an edit.
adopt() {
    src=$1 dest=$2 stamp=/var/lib/furcate-tui/$(basename "$dest")
    [ -f "$src" ] || return 0
    mkdir -p "$(dirname "$dest")" /var/lib/furcate-tui
    if [ -f "$dest" ] && [ -f "$stamp" ] && ! cmp -s "$dest" "$stamp"; then
        if ! cmp -s "$dest" "$src"; then
            echo "furcate-tui: keeping your edited $dest"
            echo "  the new default is $src"
        fi
        return 0
    fi
    install -m644 "$src" "$dest"
    cp "$src" "$stamp"
}

# /etc/xdg is what XDG_CONFIG_DIRS names on this distribution, so an operator's
# ~/.config/tuios/config.toml still overrides this key by key.
adopt /opt/furcate/tui/share/config.toml /etc/xdg/tuios/config.toml

# 95- so it runs after the branding script that sets the palette and the
# prompt: this clears the banner that one draws, and clearing it first would
# leave the interface underneath a screen nobody asked for.
adopt /opt/furcate/tui/share/profile.sh /etc/profile.d/95-furcate-tui.sh

# The marker directory the console pane recognises itself by after a restore.
#
# Resurrection gives every window a fresh shell and no memory of what was
# running in it, so the console's pane comes back as a bash prompt wearing the
# console's name. The one thing a restored pane does keep is its working
# directory, so the console window is opened standing in this one and the
# profile script reads $PWD to know which pane it is in.
#
# World-writable with the sticky bit, like /tmp: any operator may be the one who
# logs in first and creates the session, and none of them should need root to do
# it.
install -d -m1777 /var/lib/furcate-tui/view
for _v in machine power workloads fleet; do
    install -d -m1777 "/var/lib/furcate-tui/view/$_v"
done

# On PATH.
#
# /usr/bin is read-only on a Furcate machine, so a symlink there is not
# available. profile.d is, and it is already how the distribution puts its own
# things in front of a login shell. Written here rather than shipped so that
# removing the package takes the PATH entry with it.
#
# Prepended rather than appended: a tuios earlier on PATH from somewhere else
# would keep being the one that runs, and the daemon and the client have to be
# the same build.
cat > /etc/profile.d/94-furcate-tui-path.sh <<'PATHEOF'
case ":$PATH:" in
    *:/opt/furcate/tui/bin:*) ;;
    *) PATH="/opt/furcate/tui/bin:$PATH" ;;
esac
PATHEOF
chmod 644 /etc/profile.d/94-furcate-tui-path.sh

# The pane hook, sourced from /etc/bash.bashrc.
#
# It has to run in a pane, and a pane is not a login shell — tuios spawns a
# plain interactive bash, so /etc/profile.d is never read there. Ubuntu's
# bash.bashrc has no drop-in directory, so this appends one guarded line rather
# than editing the file's contents, which is what makes it removable again.
marker="# furcate-tui: restore the console pane"
if ! grep -qF "$marker" /etc/bash.bashrc 2>/dev/null; then
    {
        echo ""
        echo "$marker"
        echo '[ -r /opt/furcate/tui/share/restore-console.sh ] && . /opt/furcate/tui/share/restore-console.sh'
    } >> /etc/bash.bashrc
fi

# The palette on the machine's own screens.
#
# A unit rather than a line in the profile: a profile script paints the console
# it happens to be attached to, which is right for a login and wrong for a
# machine that reboots into the interface or has a getty restarted under it.
# Per console, before the getty, makes the palette a property of the screen.
if [ -d /etc/systemd/system ]; then
    install -m644 /opt/furcate/tui/share/furcate-vtpalette@.service \
        /etc/systemd/system/furcate-vtpalette@.service
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable furcate-vtpalette@tty1.service >/dev/null 2>&1 || true
    systemctl start furcate-vtpalette@tty1.service >/dev/null 2>&1 || true
fi

# The console's mouse.
#
# A Linux VT has no mouse of its own: tuios supports one and receives nothing
# unless gpm is translating the device into console events. The binary ships
# with the interface because /usr is read-only here and the package cannot be
# installed. Over SSH from a real terminal none of this applies.
if [ -x /opt/furcate/tui/bin/gpm ] && [ -d /etc/systemd/system ]; then
    install -m644 /opt/furcate/tui/share/furcate-mouse.service \
        /etc/systemd/system/furcate-mouse.service
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable furcate-mouse.service >/dev/null 2>&1 || true
    systemctl restart furcate-mouse.service >/dev/null 2>&1 || true
fi

# A running daemon keeps serving the build it started from, so an upgrade that
# only replaced the binary would leave the old code running with no sign of it.
# Saying so beats restarting somebody's session out from under them.
if command -v tuios >/dev/null 2>&1 && tuios ls >/dev/null 2>&1; then
    echo "furcate-tui: a session daemon is running the previous build."
    echo "  Sessions are saved and restored across a restart:"
    echo "    tuios kill-server && tuios attach furcate -c"
fi
exit 0
EOF
    chmod 755 "$work/ctl/postinst"

    # Removal takes back only what was never edited, by the same rule the
    # postinst adopts by. A file the operator changed outlives the package.
    cat > "$work/ctl/postrm" <<'EOF'
#!/bin/sh
set -e
[ "$1" = purge ] || exit 0
systemctl disable --now furcate-mouse.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/furcate-mouse.service
systemctl disable furcate-vtpalette@tty1.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/furcate-vtpalette@.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -f /etc/profile.d/94-furcate-tui-path.sh
# Take the bash.bashrc hook back out, both lines and the blank one before them.
if [ -f /etc/bash.bashrc ]; then
    sed -i '/# furcate-tui: restore the console pane/,+1d' /etc/bash.bashrc
fi
for f in /etc/xdg/tuios/config.toml /etc/profile.d/95-furcate-tui.sh; do
    stamp=/var/lib/furcate-tui/$(basename "$f")
    if [ -f "$f" ] && [ -f "$stamp" ] && cmp -s "$f" "$stamp"; then
        rm -f "$f"
    fi
    rm -f "$stamp"
done
rmdir --ignore-fail-on-non-empty /var/lib/furcate-tui /etc/xdg/tuios 2>/dev/null || true
exit 0
EOF
    chmod 755 "$work/ctl/postrm"

    # --- assemble ------------------------------------------------------------
    # Reproducible: a fixed mtime and a sorted member order, so the same inputs
    # give the same bytes and two builds can be compared by checksum.
    stamp=${SOURCE_DATE_EPOCH:-1767225600}
    tarflags="--sort=name --owner=0 --group=0 --numeric-owner --mtime=@$stamp"

    ( cd "$work/ctl"  && $TAR $tarflags -czf "$work/control.tar.gz" . )
    ( cd "$work/root" && $TAR $tarflags -czf "$work/data.tar.gz" . )
    printf '2.0\n' > "$work/debian-binary"

    out="$dist/furcate-tui_${version}_${arch}.deb"
    rm -f "$out"
    ( cd "$work" && "$MKAR" "$out" debian-binary control.tar.gz data.tar.gz )

    rm -rf "$work"
    trap - EXIT
    echo "built $out"
done
