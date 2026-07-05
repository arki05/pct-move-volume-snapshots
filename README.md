# pct-move-volume-snapshots

Prototype for a `--with-snapshots` flag on `pct move-volume`: move a container
volume to another storage **without losing its snapshot history**, by
replaying snapshots oldest-to-newest through Proxmox's own copy machinery.

Storage-agnostic by construction — any source whose snapshots PVE can mount,
any target that supports snapshots (zfs → bcachefs, btrfs → zfs, ...).

**Status: design phase.** See [DESIGN.md](DESIGN.md).

Sibling project of [pve-bcachefs](../pve-bcachefs/) (bcachefs storage plugin);
its LXC.pm patch 2 (generic mounting of path-backed subvolume snapshots) is a
soft prerequisite for subvolume-storage *sources* here. This feature is
intended as an upstream RFC to pve-devel, not a permanent out-of-tree patch.

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
