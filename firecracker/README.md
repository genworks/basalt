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
exec`), cgroup limits on CPU, and de-duplicating what a restored clone
replicates (hostname, any token the Lisp minted before the snapshot;
the kernel's random pool is reseeded by Firecracker's VMGenID).
Each of these is a later phase once the numbers are in.  The data
disk and the application inside the VM are the hangar's, below.

## The hangar: a hosted application in a VM of its own

The second question, answered on the same kit: can one application
that a visitor built and deployed in the prompt lab run in a microVM
of its own, behind the ship's reverse proxy, with its CPU, memory and
disk capped and its lifetime tied to whether its author's hosting is
paid -- while the author's deploy flow stays what it was?  `hosted`
is that: a hangar that boots one VM per deployment.

The hangar is a container on the ship's network (`hangar/Dockerfile`:
Debian with iproute2, iptables, curl, e2fsprogs, jq) that is given
the KVM and TUN devices and `NET_ADMIN`, with IP forwarding on and
its own CPU and memory caps as the outer limit on every VM it flies:

```bash
H=/path/to/basilisk/firecracker
docker build -t hangar:phase0 $H/hangar
docker run -d --init --name hangar --network <ship network> --network-alias hangar \
    --device /dev/kvm --device /dev/net/tun --cap-add NET_ADMIN \
    --sysctl net.ipv4.ip_forward=1 --cpus 2 --memory 1536m \
    -v $FC_DIR:/fc -v $H:/hangar:ro \
    -v /projects/.state/prompt-lab-deployed:/deployments:ro \
    hangar:phase0 sleep infinity
```

Firecracker runs inside it as root, which is what Phase 0 accepts; the
jailer is a later phase.  `--init` so a VM that is taken down is
reaped (a bare `sleep` as PID 1 leaves zombies).  The host needs no sudo and nobody in the
`kvm` group: Docker hands the devices over.  Nested virtualization
suffices (the kit was proven on a WSL2 host).

**The root filesystem** is the Phase 0 one plus the hosted runtime:
the demos tree (the prompt lab) and monocle at `/opt/hosted`, and
`hosted-services-init.cl` as the image's services-init hook, which
loads the lab, points it at `/data`, shuts its own doors behind a
password, names the gate and publishes.  `guest-init` mounts a second
virtio disk at `/data` when there is one, and holds the Lisp's stdin
open on a pipe: the image's REPL reads end-of-file otherwise and the
service quits a second after it is up (a container's tty hid this).
Build it with the image's export and checkouts of the two
repositories (fasl files removed):

```bash
cid=$(docker create genworks/gendl:devo-ccl); docker export $cid -o $FC_DIR/gendl.tar; docker rm $cid
mkdir -p $FC_DIR/hosted && cp -r /path/to/demos /path/to/monocle $FC_DIR/hosted/
docker run --rm -v $FC_DIR:/work -v $H:/hangar:ro -v $FC_DIR/hosted:/hosted:ro \
    debian:13-slim bash /hangar/hangar/build-rootfs hosted 4G
```

**The deployment's disk** (`hosted disk NAME`) is a 64 MiB ext4
holding the lab's record and model file for NAME, copied from the
lab's deployed root (mounted read-only at `/deployments`), owned by
the image's user; grants and purses the runtime writes land there and
survive the VM's restarts.  `up` makes it when it is missing.

**Boot** (`hosted up NAME [PORT]`): the VM gets a tap of its own on a
/30 (`172.16.N.0`, N from the name), NAT out through the hangar's
address so the guest reaches the gate, and a DNAT from the hangar's
PORT to the guest's 9080 so the proxy reaches the application; the
kernel command line carries `hosted.gate` (the gate's Messages door),
`hosted.lab` (the lab's name at the gate, so the VM's meter reports
land on the author's hosting ledger, not a ledger of their own) and
`hosted.lock`.  `VCPUS` and `MEM_MIB` are the VM's caps (1 and 512
are enough for one application); the disks are the third cap.  The
proxy's rule for the deployment names the hangar and the port, with
`:affinity` and an alias so the instance's minted session URLs stay
on the VM:

```lisp
("vm-NAME" :host "hangar" :port 9080)                     ; :backend-aliases
(:path "/prompt-lab/d/NAME" :host "hangar" :port 9080 :affinity t :preserve-host? t)
```

**The lifetime** (`hosted watch NAME`): every few seconds the watcher
asks the gate's `/host-balance` for the deployment; while the gate
says `stopped` (its hosting allowance and what was bought for it are
spent, `stopped_since` set) the VM is taken down, and when a report
fits again it is brought back.  The proxy answers its own 404 in
between; a paused page there is a later rung.

**Measured on the kit's first host** (a 2-vCPU VM at 1024 MiB, then
1 vCPU at 512 MiB; the gendl-ccl image): lisply answers 1.6-3.7 s
after `InstanceStart`, the hosted runtime (the lab compiled from
source inside the VM) 10-15 s after it; one VM costs the host about
266 MiB resident (RSS and PSS alike with one VM up); the deployment
served through the proxy with its session on the VM; the VM's compile
and run reports booked at the gate under the lab's key; the lab's own
doors 403 inside the VM; the watcher taking the VM down within its
interval of the gate's stop and bringing it back on the next fitting
report.

**Not here yet:** the application's side doors (tollbooths, hosting
top-up, the app's files) are published at the lab's prefix, so the
proxy sends them to the lab, not the VM -- a deployment's doors under
its own address is the next rung; the VM books nothing (the lab's
sweep books what the gate settled); a snapshot after the runtime is
up, restored per deployment, in place of the 10 s compile; the jailer;
a paused page from the proxy while the VM is down.
