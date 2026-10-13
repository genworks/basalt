# Firecracker, Phase 0: one Lisp room as a microVM

The question this answers: what does a Gendl session cost as a
[Firecracker](https://firecracker-microvm.github.io/) microVM, restored
warm from a snapshot, and how many fit on one host?  The stack's rooms
are containers in a shared kernel; a session that evaluates a visitor's
code wants a kernel of its own.  Firecracker gives VM isolation at
container cost, and a snapshot taken after the Lisp has loaded its
world restores in well under a second, with the clones sharing the
pages they have not written.

Phase 0 is a measurement, not a service.  It boots the stock
`genworks/gendl:devo-ccl` image (and, separately, a GDL betatest
image) as a VM, waits for the lisply ping, snapshots it, restores
clones, and reports what each clone really costs.

## The host

A Linux box with KVM: `/dev/kvm` present, the user in the `kvm` group
(`newgrp kvm` in the shell that runs this, or log in again), `sudo`
for the network pieces, `docker` for building the root filesystem,
`curl`.  Cgroups v2 (any current distribution) keeps restores fast.
About 10 GB of disk under `$FC_DIR` (default `~/firecracker-phase0`).

## The run

```bash
F=/path/to/basilisk/firecracker/phase0
$F fetch                                    # firecracker v1.17.0 + the 6.1 CI kernel
$F rootfs genworks/gendl:devo-ccl gendl     # docker export -> gendl.ext4, a few minutes
$F net                                      # tap fctap0 172.16.0.1/30 (sudo)
$F boot gendl                               # boots, prints the time to the first ping
$F ping gendl                               # ping + (lisp-implementation-version)
$F measure                                  # RSS/PSS of the VM
$F snapshot gendl                           # pause, write vmstate + mem, copy the disk
$F restore gendl 1                          # clone 1 in netns fc1: disk copy, load, ping
$F restore gendl 2
$F restore gendl 3
$F measure                                  # the number Phase 0 is for
$F ping gendl 2                             # a clone answers
$F stop all; $F clean
```

Then the same with the solids engine:

```bash
$F rootfs genworks/gdl:devo-smp-betatest gdl
$F boot gdl && $F snapshot gdl && $F restore gdl 1 && $F ping gdl 1
```

`boot NAME -f` keeps the guest console in the terminal (and gives it a
shell, boot arg `phase0.shell`); run `phase0 configure NAME` from
another shell to start it.  Background boots log the console to
`$FC_DIR/run/NAME.console`.

## What to record

- **Time to first ping** on a cold boot (`boot` prints it), and on a
  restore (`restore` prints disk copy, load+resume, and ping).
- **The `measure` table with three clones up.**  RSS is what each
  process has mapped; PSS divides every shared page among the clones
  sharing it, so the *sum of PSS* is what the clones cost the host.
  PSS well under RSS means the snapshot's pages are being shared as
  hoped.  Divide the host's available memory by one clone's PSS, after
  the reservation for its other work, for the sessions-per-host figure.
- **For GDL:** that a clone restored from the snapshot still answers
  the ping and evaluates a form.  The betatest licenses are minted per
  gdl pipeline with a term of their own, not tied to a machine, so a
  clone should not care that it is a copy; this is the check.
- The `boot` time is what a cold start would cost; the `restore` time
  is what a session would wait for.

## How it is built

- **Root filesystem.** `docker export` of the image, unpacked and
  written with `mkfs.ext4 -d` inside a throwaway Debian container, so
  the tree keeps its ownership without root on the host.  The image
  has no init system; `guest-init` becomes `/sbin/init`: it mounts
  the pseudo filesystems, reads `/etc/phase0.env` (the image's user
  and HTTP port, chosen by `rootfs` from `/opt/gendl` or
  `/opt/genworks-gdl`), and runs the image's own `/etc/rc.local` as
  that user with `START_HTTP=true`.  Everything downstream is the
  image's, unchanged.
- **Kernel.** Firecracker's CI kernel (6.1) from the project's bucket,
  config saved beside it: `ip=` autoconfiguration, virtio block and
  net, ext4, cgroup v2, all built in.  The guest gets its address from
  the kernel command line, so the image needs no network tools.
- **Network.** One tap per VM at `172.16.0.1/30`, guest `172.16.0.2`,
  and nothing beyond it: Phase 0 needs no egress.  Clones keep the
  guest address the snapshot baked in, so each runs in a network
  namespace `fcN` holding a tap of the same name; `ping NAME N` goes
  through `ip netns exec`.  The production shape (a veth pair per
  namespace and NAT to a unique address per clone, or the jailer with
  `--netns`) is in Firecracker's `network-for-clones` document.
- **Paths.** The VM runs in its own directory with the rootfs and
  kernel at *relative* names; the snapshot records those, and a clone
  restored from another directory with its own copy of the disk finds
  it.  Clones share the memory file read-only (`MAP_PRIVATE`, copy on
  write), which is where the page sharing comes from.
- **Snapshot.** `PATCH /vm Paused`, `PUT /snapshot/create` (full), and
  a sparse copy of the paused disk.  Restore is `PUT /snapshot/load`
  with `resume_vm`.  The source VM stays paused; stop it when the
  clones are up.

## Not in Phase 0

Egress from the guest, the jailer (clones run as root under `ip netns
exec`), a per-session data disk, cgroup limits on CPU, the prompt lab
itself inside the VM, and de-duplicating what a restored clone
replicates (hostname, any token the Lisp minted before the snapshot;
the kernel's random pool is reseeded by Firecracker's VMGenID).
Each of these is a later phase once the numbers are in.
