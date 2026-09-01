#!/bin/sh
# Paint the Linux console's sixteen slots in Furcate's palette.
#
# Run once per virtual console, before anything is drawn in it.
#
# ## Why an ioctl and not the OSC escapes
#
# The obvious way is `printf '\033]P3ffaf03' > /dev/tty1`, which is what
# /etc/issue does and what this script did first. It is silent when it fails,
# and it failed here: the sequence is interpreted by whatever is *reading* the
# terminal, so it reaches the kernel's console driver only while nothing else
# has the tty. Once a full-screen program is attached, the escapes go into that
# program's own emulator and the console's palette is never touched. Reading
# /dev/tty1 back with GIO_CMAP showed sixteen stock colours after every apply —
# slot 14 still #00ffff — while the screen showed cyan borders nobody had asked
# for.
#
# PIO_CMAP sets the console's colour map directly. It is not a byte stream, so
# there is nothing between the request and the driver, and it works whether or
# not something is attached to the tty.
#
# ## Why all sixteen
#
# palette.sh's fur_console_palette remaps four — amber, its bright step, the
# dim neutral and the fault — because the shell prompt and the login banner use
# only those. The interface draws its borders, title bars and dock out of the
# rest, so leaving them stock is what framed amber content in green and cyan.
#
# The values are the ones internal/theme/furcate.go ships, so the machine's own
# screen and a terminal over SSH show the same brand rather than two readings
# of it. Change them together.
#
# ## Why slot 9 is amber and not the bright fault
#
# Because that is where the brand arrives. A sixteen-colour terminal is sent an
# index, and the index is chosen by matching the theme's RGB against *xterm's
# defaults* — the converter has no idea this console was repainted. Every amber
# in the palette (#ffaf03, #ffc96e, #c99a30, #d8a840) is nearest to xterm's
# bright red, so all of them are drawn on slot 9.
#
# Painting slot 9 the fault colour therefore did not make faults visible: it
# made the entire interface look like one. Reading /dev/vcsa1 back is what
# settled it — the amber slots held nothing at all and slot 9 held the screen.
#
# So slot 9 carries the measured amber, and the fault keeps slot 1, which is
# where the fault red still resolves. The brand is correct at the cost of the
# bright-fault step, which nothing on this screen was using.
set -eu

tty=${1:-/dev/tty1}
[ -c "$tty" ] || exit 0

exec python3 - "$tty" <<'PY'
import fcntl, os, sys

# From linux/kd.h. PIO_CMAP takes 48 bytes: sixteen RGB triples in slot order.
PIO_CMAP = 0x4B71

PALETTE = (
    # Slot 0 is the ground the whole screen sits on.
    #
    # It is also where window titles and border glyphs quantise, which was
    # tempting to fix by lifting it — and lifting it turned the entire display
    # pale brown, because 6100 of the 6144 cells on this screen have slot 0 as
    # their background. A slot cannot be the ground and the ink on it at once.
    #
    # So the ground stays the ground, and the titles are dealt with where they
    # are chosen rather than here: window_title_position = "hidden" in the
    # config, since the pane's name is already in the rail and the dock.
    "0d0b08"  # 0  the ground
    "d42320"  # 1  fault
    "8a6a1e"  # 2  chrome (terminal-mode border comes from its bright step)
    "ffaf03"  # 3  amber: the system's own voice
    "7a5f1a"  # 4  chrome
    "8a6a2a"  # 5  chrome
    "9a7a2a"  # 6  chrome
    "868686"  # 7  ordinary text
    "747474"  # 8  context: units, labels
    "ffc96e"  # 9  where the brand actually lands — see the note below
    "c99a30"  # 10 focused border, terminal mode
    "ffc96e"  # 11 measured: a figure that came off an instrument
    "d8a840"  # 12 dock mode indicator
    "c99a50"  # 13 chrome
    "ffc96e"  # 14 focused border, window mode — where you are
    "f0e6d2"  # 15 brightest text
)

fd = os.open(sys.argv[1], os.O_RDWR)
try:
    fcntl.ioctl(fd, PIO_CMAP, bytes.fromhex(PALETTE))
except OSError:
    # Not a virtual console — a serial console, or a pty someone pointed this
    # at. Nothing to repaint and nothing worth failing a boot over.
    pass
finally:
    os.close(fd)
PY
