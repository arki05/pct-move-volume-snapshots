# Design: `pct move-volume <vmid> <mp> <storage> --with-snapshots`

## Core loop

```
validate:
    - container stopped (v1; live pre-sync is a later refinement)
    - every snapshot of the source volume is mountable
      (PVE::LXC::mountpoint_mount with snapname: subvol -> ro bind mount,
       raw -> ro loop mount, zfs -> zfs snapshot mount)
    - target storage supports the 'snapshot' feature for the volume type
      it will allocate

allocate target volume once (alloc_disk semantics: folder subvol / raw)

for each snapshot, oldest -> newest (order from config parent-chain):
    mount source@snap read-only
    copy_volume into EXISTING target volume (update mode, rsync --delete)
    PVE::Storage::volume_snapshot(target, snapname)

copy_volume current source state -> target (update mode)

config rewrite:
    - volid in the live section (move_volume already does this)
    - volid in EVERY snapshot section (new)
    - snapshot names/descriptions/times/parents untouched -> history intact

source volume -> unused0 (or delete with --delete like plain move-volume)
```

Efficiency falls out naturally: rsync against the target (which holds the
previous snapshot's state) only writes deltas, and the COW target stores each
snapshot as its delta. No send/receive needed anywhere.

## Required pve-container changes

1. `PVE::LXC::copy_volume`: an *update-into-existing-volume* mode — skip
   allocation, rsync with `--delete` into the mounted target. Small, clean
   extension (today it always allocates a fresh volume).
2. `PVE::API2::LXC::move_volume`: new boolean param `with-snapshots`,
   validation, the replay loop, snapshot-section config rewrite.
3. (later, pve-manager) GUI checkbox on the Move Volume dialog, shown only
   when source volume has snapshots and target storage reports the snapshot
   feature.

## Edge cases

- **Multiple mountpoints**: per-volume operation, exactly like move-volume
  today; each volume replays its own snapshot subset (snapshot sections list
  which volumes they cover).
- **Unprivileged containers**: copy_volume already preserves shifted uids
  (numeric-ids rsync); nothing new.
- **Fidelity**: rsync-level (same mechanism PVE uses for CT full clones and
  plain move-volume), not block-identical. Acceptable and precedented.
- **Snapshot config metadata** (descriptions, snaptime, parent chain) lives in
  the CT config and is deliberately not touched — only volids are rewritten.
- **Failure mid-replay**: target volume is new and unreferenced until the
  final config rewrite; abort = free target volume, source untouched.

## Prototype plan

- Exact-match patch script against pve-container 6.1.10 (same approach as
  pve-bcachefs/patches/patch-pve-container.pl, which is proven).
- Test in the pve-lab nested VM (10.10.10.178):
  - CT on local-btrfs with a 3-snapshot chain -> move to bcachefs ct-fast,
    verify each snapshot's content by mounting/rolling back
  - bcachefs -> bcachefs (cross-storage same-type)
  - negative: target without snapshot feature must refuse cleanly
- Then: RFC to pve-devel proposing the copy_volume extension + API param
  (CLA required; frame as generalization, zero behavior change without the
  flag).

## Open questions

- Live migration variant: pre-sync snapshots while CT runs, stop, final
  current-state delta pass (downtime ~ one rsync delta). v2.
- VM disks (`qm move-disk`): same idea, but block-level; would want
  `qemu-img convert` per snapshot or bitmap-based dirty tracking. Out of
  scope here — containers first, where file-level replay is natural.
