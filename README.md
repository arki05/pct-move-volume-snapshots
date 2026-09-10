# pct-move-volume-snapshots

Prototype for a `--with-snapshots` flag on `pct move-volume`: move a container
volume to another storage **without losing its snapshot history**, by
replaying snapshots oldest-to-newest through Proxmox's own copy machinery.

Storage-agnostic by construction — any source whose snapshots PVE can mount,
any target that supports snapshots (zfs → bcachefs, btrfs → zfs, ...).

**Status: prototype complete and integration-tested** (lvmthin -> bcachefs and bcachefs -> bcachefs with 3-snapshot replay, content-verified via rollbacks; clean refusal on snapshot-incapable targets). See [DESIGN.md](DESIGN.md) and `patches/

Mounting snapshots of a subvolume-storage *source* is a hard prerequisite, and
lives in
[pve-lxc-snapshot-mount](https://github.com/arki05/pve-lxc-snapshot-mount) —
depended on, not duplicated. That fix is generic (it repairs the same gap for
btrfs) and was previously carried here as patch 1 and in
[pve-bcachefs](https://github.com/arki05/pve-bcachefs) as its patch 2, with
nothing but a matching comment string keeping the two from both applying.

This feature is intended as an upstream RFC to pve-devel, not a permanent
out-of-tree patch.

## Install

```
apt install pct-move-volume-snapshots
```

from [apt.arki05.com](https://apt.arki05.com). The package applies the series
to the installed `pve-container` and re-applies it after every upgrade via a
dpkg trigger; removing it reverses the patches.

Patching semantics, deliberately:

- **all-or-nothing** — every patch is dry-run first, and if any would fail
  nothing is touched. A partially patched `pve-container` is a state nobody
  designed and no revert path knows about
- **`patch -R`** to revert, rather than a hand-written inverse that can drift
  from the forward direction
- **zero fuzz (`-F0`)** — a hunk that no longer matches fails loudly instead of
  landing somewhere merely plausible. Offsets are still allowed, which is how
  the series survived 6.1.10 → 6.1.14 unchanged
- **syntax-checked afterwards**, with automatic rollback of the whole series if
  any touched file fails
- `apply-patches.sh --status` reports whether it is currently applied

The shipped patches are the canonical series with the upstream test-harness
hunks (`src/test/`) filtered out at build time, since no installed system has
them. `patches/` keeps the full series for submission.

## Why

Today Proxmox refuses `pct move-volume` whenever snapshots exist, vzdump
restore silently drops snapshot history, and the only snapshot-preserving
paths are same-type node migrations (`zfs send`, `btrfs send`). There is no
cross-storage-type story at all.

## Workflow

- `pve-container/` (git-ignored) is a clone of the upstream repo
  (github.com/proxmox/pve-container mirror), branch
  `move-volume-with-snapshots`, currently at 6.1.10 — identical to the
  version deployed on both the lab VM and production.
- Feature is developed as real commits on that branch, tests added to the
  upstream harness (`src/test/run_snapshot_tests.pl`).
- Testing: build the .deb from the branch, install in the pve-lab VM
  (10.10.10.178), run the replay matrix from DESIGN.md.
- Submission: `git format-patch` (kept in `patches/` for visibility) →
  pve-devel RFC.

## License

AGPL-3.0-or-later (see [LICENSE](LICENSE) and [NOTICE](NOTICE)). The patches are
derivative works of Proxmox's AGPL-3.0+ pve-container.
