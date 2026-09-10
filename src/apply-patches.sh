#!/bin/sh
#
# Apply (or revert) the move-volume --with-snapshots patch series against an
# installed pve-container.
#
#   apply-patches.sh [--revert|--status]
#
# The series is applied all-or-nothing: every patch is dry-run first, and if any
# would fail, nothing is touched. Partially patching pve-container would leave
# it in a state nobody designed and no revert path knows about.
#
# Zero fuzz (-F0) on purpose: a hunk that no longer matches should fail loudly
# rather than land somewhere merely plausible.

set -eu

PATCHDIR=${PATCHDIR:-/usr/share/pct-move-volume-snapshots/patches}
ROOT=${ROOT:-/usr/share/perl5}
MARKER='with-snapshots'
SENTINEL="$ROOT/PVE/API2/LXC.pm"

patches() { ls "$PATCHDIR"/*.patch 2>/dev/null | sort; }
applied() { grep -q -- "$MARKER" "$SENTINEL" 2>/dev/null; }

# Patches are generated against the pve-container source tree, so paths look
# like a/src/PVE/LXC.pm; -p2 strips 'a/src/' leaving PVE/LXC.pm, which is what
# an installed tree looks like under /usr/share/perl5.
#
# Hunks may land at an offset - pve-container moves code around between
# releases - which -F0 still permits; it forbids fuzz, not offset. The shipped
# patches have already had the upstream test-harness hunks filtered out at
# build time, since no installed system has src/test/.
PFLAGS='-p2 -F0'
try()       { patch $PFLAGS -d "$ROOT" --dry-run       < "$1" >/dev/null 2>&1; }
do_apply()  { patch $PFLAGS -d "$ROOT"                 < "$1" >/dev/null; }
try_rev()   { patch $PFLAGS -d "$ROOT" -R --dry-run    < "$1" >/dev/null 2>&1; }
do_rev()    { patch $PFLAGS -d "$ROOT" -R              < "$1" >/dev/null; }

case "${1:-}" in
--status)
    applied && echo "with-snapshots: applied" || echo "with-snapshots: not applied"
    ;;
--revert)
    applied || { echo "with-snapshots: already reverted"; exit 0; }
    for p in $(patches | sort -r); do
        try_rev "$p" || { echo "cannot cleanly revert $(basename "$p") - leaving pve-container alone" >&2; exit 1; }
    done
    for p in $(patches | sort -r); do do_rev "$p"; done
    echo "with-snapshots: reverted"
    ;;
*)
    applied && { echo "with-snapshots: already applied"; exit 0; }
    for p in $(patches); do
        try "$p" || {
            echo "cannot apply $(basename "$p") - pve-container has changed" >&2
            echo "  nothing was modified; the series needs rebasing" >&2
            exit 1
        }
    done
    for p in $(patches); do do_apply "$p"; done
    for f in "$ROOT/PVE/LXC.pm" "$ROOT/PVE/API2/LXC.pm" "$ROOT/PVE/LXC/Config.pm"; do
        perl -c "$f" >/dev/null 2>&1 || {
            echo "patched $f fails its syntax check - reverting the series" >&2
            for p in $(patches | sort -r); do do_rev "$p" 2>/dev/null || true; done
            exit 1
        }
    done
    echo "with-snapshots: applied"
    echo "restart container-related services or reboot to take effect"
    ;;
esac
