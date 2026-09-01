#!/bin/sh
# Paint the Linux console's sixteen slots in Furcate's palette.
#
# Run once per virtual console, before anything is drawn in it.
#
# ## Why all sixteen and not the four the branding remaps
#
# palette.sh's fur_console_palette exists for the shell prompt and the login
# banner, which only ever use amber, dim, fault and bright amber. The interface
# draws its borders, title bars and dock out of the rest, so leaving those at
# the kernel's defaults is what put green borders around salmon bars on a blue
# ground.
#
# ## Why a unit and not a line in the profile
#
# A profile script paints the console it happens to be attached to, which is
# right for a login and wrong for everything else: a machine that reboots into
# the interface, a second tty, a getty restarted on its own. Doing it per
# console, before the getty starts, means the palette is a property of the
# screen rather than of whoever logged into it.
#
# The values are the ones internal/theme/furcate.go ships, so the machine's own
# screen and a terminal over SSH show the same brand rather than two readings
# of it. Regenerate both from deploy/os/branding/palette.json.
set -eu

tty=${1:-/dev/tty1}
[ -w "$tty" ] || exit 0

{
    printf '\033]P016120c\033]P1d42320\033]P26b8f3a\033]P3ffaf03'
    printf '\033]P44a6b8a\033]P57a5c8a\033]P64a8a8a\033]P7868686'
    printf '\033]P8747474\033]P9d4594e\033]PA8fb35a\033]PBffc96e'
    printf '\033]PC6a8bad\033]PD9a7cad\033]PE6aadad\033]PFf0e6d2'
} > "$tty"
