# Basilisk

This scroll chest is ship's blueprints for laying down, fitting out,
and mustering a Basilisk-class space ship. More detail about what a
Basilisk *is* can be found in the overview scroll,
[BASILISK.md](BASILISK.md). This scroll is both the fabrication and
operating manual: raising the ship, standing him down, securing
passage for your desired passengers, both biological and cyborg.

A standard rig flies with five residential modules plugged into the
hull, each arriving pre-staffed: a **Ready Room** with the Captain at
the ship's console, a **Bridge** run by the First Officer, an
**Engine Room** with the Ship's Engineer, a **Sick Bay** whence the
Doctor does his rounds, and a filtered **Museum Chamber** kept by the
Museum Curator, a museum 'bot. Crew answer to personal names minted
fresh at every muster, and each room is known by its resident —
"Thweed's ready room" — while the ship's lines also answer to a
room's plain *type* (`bridge`, `museum-chamber`), whoever keeps it
this tour. Human and cyborg visitors may hail any hand by name or
any room by type — and even the chamber's founding exhibit itself:
**the museum terminal** (`telnet museum-chamber 1052`, from any
berth aboard) seats one visitor at a time at the antique machine's
own console, the recent record replayed on connect. The exhibit
keeps its own **placard** — what it is, how it is worked, and how
the game is flown: ask the muster (`./basilisk status`) who keeps
the chamber this tour, then `docker exec <his-name> cat
/museum/PLACARD.md`; the machine-room record announces it at every
power-up. A **Navigator** for the chartroom is on the books but
elective — his residence runs heavy, so he signs on by stack pouch,
like the Transporter Chief. The whole outfitting is stated in one
scroll, `basilisk.sexp`, and every other document the ship needs is
drawn from this `basilisk.sexp`.


## Raising a ship

Requirements: You'll need this Scroll to guide you, and then your
bio-vat must be equipped with a working _blueprint receiver_ and one
of the newer "dock-style" vats for growing the hull in.

Incantations for raising a ship:

```bash
git clone https://github.com/gornskew/basilisk
cd basilisk
./basilisk up
```

The **vatcycle** runs its course: the hull forms, the residential
modules are plugged in pre-staffed, the muster reads their papers,
and finally the ship (a "he") engages its innate anti-gravity
properties and floats out from the vat. He will have been christened
with a name the yard bestows — minted fresh at this raising, kept in
a scroll named `.ship` — and he will be known by that name for the
whole of his life, which runs exactly one commission: **every
raising is a new ship**. The ship standing before him, if any, is
stood down first and buried under his own name in the yard's **log
of ships** (`.ships-log`) — his working logs die with him, but the
name and his dates are kept there, unique forever in this galaxy,
for some names go down famous. His crew answer to personal names
minted for them at muster, each room known by its resident's name,
and the ship's lines answer to the plain room types as well.


If you (ship's owner/commissioner) have a personal scroll chest named
`~/projects/` it will be requisitioned to appear in the ship as
`/projects/`, and curiously, will remain in your possession wherever
you brought it from. To have a different scroll chest appearing aboard,
call out `PROJECTS_DIR=` with its name just before you utter the
`./basilisk up` incantation --- e.g:

```bash
PROJECTS_DIR=/path/to/projects ./basilisk up
```

A first `up` also leaves a few deliberate marks in the galaxy:

- `rmax` and `grmax` suddenly become powerful incantations in this
  galaxy --- anyone uttering them gets connected directly and
  immediately to the Captain's scroll.
  
- Cyborg wormholes are placed both inside and outside the ship:
  `~/.claude/`, `~/.gemini/`, `~/.codex/` and `~/.grok/` that appear
  onboard, and `claude_desktop_config.json` that gives wormhole access
  to cyborgs from across not only this galaxy but from alien galaxies
  as well.

- If your galaxy already carries a `~/.claude.json` scroll that
  routes through some `mcp/mcp-exec` whose pouch has since vanished
  (moved, or deleted), that entry is gently re-pointed at this
  pouch's copy; entries routing through another living pouch are
  left to that ship, so two ships can share one scroll (a backup
  scroll is kept; nothing else in it is touched).


## The orders

```bash
./basilisk <command>
```

| command | what it does |
|---|---|
| `up [module...]` | bare: raise a **new ship** (standing down and burying the old); with modules named: rouse those rooms of the standing ship; `--pull` fetches fresh residences from the catalogs |
| `down` | stand the whole ship down |
| `restart [module...]` | a watch change — one room, or all; ship and crew keep their names |
| `stop [module...]` | stop without striking the berths |
| `status`, `ps` | which rooms are aboard and how their residents fare |
| `logs [module]` | a room's smoke, read back — the tale of every fire that burned there |
| `emacs` | step straight into the ready room, to the Captain's console |
| `pull` | fetch missing residences (`PULL_ALWAYS=1` for fresh ones) |
| `config` | the vat's merged instructions, as they would run |
| `install-shell-functions` | (re)write the `rmax`/`grmax` hailing calls ashore |
| `clean` | break the ship down to nothing — asks first |

Variant switches (`--lite`, `--default`, `--tui`, `--gui`, `--full`)
pick the ready room's strain for the invocation, from efficient to
luxurious; the dev stack defaults to `full` — the luxurious one,
which includes that magic glass.

For a ship that should keep station unattended even if its galaxy
glitches momentarily out & back into existence, hand the watch
out to the galaxy itself:

```bash
cd systemd && sudo ./install
sudo systemctl start basilisk     # likewise stop, restart
```

### Hailing fresh blueprints from Gornskew

Stand the ship down first, in case the hail changes papers a running
ship would refuse to stand down against:

```bash
cd ~/projects/basilisk
./basilisk down
git pull
./basilisk up --pull
```

### Several ships in one galaxy

```bash
BASILISK_INSTANCE=alpha BASILISK_PORT_OFFSET=100 ./basilisk up
```

Each ship gets his own name and his own waters — the type-hails
(`bridge`, `ready-room`) carry only on a ship's own lines, so no two
ships' bridges ever answer to one hail. Ashore, where the galaxy sees
every crew member of every ship at once, the second ship's crew wear
the instance label as a prefix on their minted names (`alpha-`). To
reach the second ship's Captain from ashore, name the instance with
a leading @-arg: `rmax @alpha`.

Two ships of different yards (this one and a fork of it, each in its
own pouch) need no instance label — each pouch is its own compose
project — only distinct published ports. The offset is read from the
environment at every `up` and written into `.env` afresh, so pin it
in `systemd/host.env` (`BASILISK_PORT_OFFSET=100`) to make it stick.
Each ship's `mcp/install-claude-code-config` and
`mcp/install-claude-desktop-config` add only that ship's rooms to the
cyborg scrolls and leave the other ship's in place.

## Coming aboard

Some ways in for human passengers:

| way aboard | how |
|---|---|
| `rmax` | the Captain's scroll, remote-viewed from your own scroll chest |
| `grmax` | a more resplendent version of the above |
| the gangway | another version of the Captain's scroll appearing inside one of your own. Utter this directly from inside your remote-viewing-capable scroll: `http://localhost:6942` |
| `./basilisk emacs` | Captain's scroll appears and now you are transported into the ready room itself (useful sometimes) |

Detach from `rmax`/`grmax` with `ctrl-^`. 


## Cyborg visitors

Every cyborg aboard presents himself at the **greeting hall**
adjoining the ready room, where the Protocol Officer receives,
decodes, and directs him, under the Captain's command. `./basilisk up`
drafts the cyborg checklists into `mcp/`:

| scroll | for |
|---|---|
| `mcp/claude_desktop_config.json` | For cyborgs based outside the ship and maybe outside the galaxy (`mcp/install-claude-desktop-config` splices it into the Claude Desktop scroll, leaving any other ship's rooms in place) |
| `mcp/claude-code-mcp.json` | For so-called "claude-class" cyborgs and interested passengers to interact, once they are both already onboard (spliced into `~/.claude.json`) |
| `mcp/mcp.toml`, `mcp/mcp-container.json`, `mcp/mcp-windows.json` | checklists for other types of cyborgs |

**Cyborg Scrolls Aboard.** The luxurious `full` strain of the ready
room carries _cyborg scrolls_ — Claude Code, Gemini CLI, Codex,
Grok — these allow passengers to share thoughts with any onboard
cyborgs, without having to sit in the same room with them (cyborgs
can be a bit loud & clanky).

Once a visitor is aboard, [`mcp/opening-prompt.md`](mcp/opening-prompt.md) is a suitable
ready-made first hail.

**A password at the doors.** Put a passphrase in `.secrets/lisply-secret`
in the galaxy's projects directory (beside the yard, mode 600) before
`./basilisk up`, and the Gendl rooms open their doors only to a cyborg
who speaks it; the greeting hall hands it to every cyborg it admits,
and a changed passphrase is heard at the next knock, with no raise.
Without the file the doors stand open as before -- fit only while no
room's port reaches past your own machine.


## The articles, and the yard's paperwork

The ship's articles are `basilisk.sexp` — the one scroll which is
often written by hand. They list the ship's residential modules by
**module-sku** — the catalog make and strain of each room to plug
in — and the posting its resident crew are to stand. The yard reads
the scroll named for itself (e.g. `basilisk`) and **no other**:
articles written for a differently-named yard are neither noticed
nor acknowledged, and the articles named `obelisk.sexp` ought to
live in the yard named `obelisk/`, if you want smooth vat-growings
and operations.

After editing the articles, have the yard draw up the various
departmental paperworks fresh from them:

```elisp
(load-file "/projects/basilisk/generate-configs.el")
(skewed-generate-configs "/projects/basilisk/")
```

Note that the above paperwork dance is often done with the help of a
captain on one ship, in preparation for the growth & mustering of
another.

These drawn-up departmental paperworks include, among others:

| drawn document | what it is |
|---|---|
| `docker-compose.yml` | guidance for the vat & yard for hull-growing, outfitting, and mustering |
| `mcp/mcp*.json`, `mcp/mcp.toml` | hailing directories and checklists for cyborg visitors |
| `generated/services-generated.el` | the Captain's reference copy of the outfitting |
| `generated/crew.env` | the **crew ledger**: each room aboard, its posting, and the minted names of the crew residing there — the one authority on who is who |

The drawn documents are etched permanently into scale tablets
harvested from shed reptilian skins, and for all practical purposes
are unchangeable. Although in theory these reptilian scales can be
sanded down and redrawn, in reality, the yard is the only one who purports
to understand the detailed rune arrangements required for the ship's
paperworks to pass muster. So hands & claws off of these while a ship
is in-voyage.


## Plugging in more modules

Everything beyond the standard rig — a **Guild Workshop** (its Guild
engineer arriving with his famous shirt-pocket sliderule), a
**Transporter Room** (with its Chief), a **Radio Shack** (its Comms
Officer feeding the bridge viewscreen from his own room) — arrives by
**stack pouch**: a pouch beside this one, carrying its own "stack" of
extra modules and possibly other adjustments. Stack pouch articles
are **sparse**: they almost never repeat what is already in the base
basilisk pouch.

```bash
mkdir ~/projects/obelisk-stack && cd ~/projects/obelisk-stack
$EDITOR basilisk.sexp               # your deviations and additions
```

A stack pouch may be named anything you like; its articles are
always named for the yard they feed — hence `basilisk.sexp` here.

Have the yard draw the stack pouch's paperwork, then carry it in and
raise the ship:

```elisp
(load-file "/projects/basilisk/generate-configs.el")
(skewed-generate-configs "/projects/obelisk-stack/")
```

```bash
./install  # copies & carries the paperworks into ../basilisk/
cd ../basilisk && ./basilisk up
```
Set `BASILISK_DIR=` if your Basilisk scroll chest is elsewhere.

Always re-utter _both_ the `skewed-generate-configs` (elisp) _and_ the
`./install` (shell) after every tampering attempt. 

**Bringing your own residence** is not a special case: a stack pouch
whose articles plug in one more module. It comes pre-staffed from its
catalog, and its crew are minted names at muster like anyone else's —
the room thereafter known by its resident. A module aboard whose crew
stand no posting musters as a presumed **stowaway residence** — its
watch column empty for all to see — and its residents may or may not
serve in an ad-hoc posting; random residences plugged into these
ships have been known to cause trouble. Any post-vat-separation
postings for such crews are usually decided in consultation with the
captain.


## A class of your own

A stack pouch can only **add**. To raise a ship that carries *only*
what you declare and may well deviate from the Basilisk class
standard, the top vatwrights' best practice is "fork & gut." Basically
that means you should engage scribes to copy all scrolls in this
certified-genuine Basilisk pouch into your own pouch, then gut the
articles and reconstruct them as you wish.

By crafty rubbing-out and rewriting of certain scrolls, you can also
bring new affectations to the ship's onboard language and indeed, to
that of these very documentation scrolls.

Unless you bribe him, the muster officer will **grumble and proceed
anyway** for every standard Basilisk posting that you omit.



## License

Copyright © 2026 Gornskew Enterprises.

Basilisk is free ship's blueprints, released under the **GNU Affero
General Public License, version 3 or later** — the full license scroll
is in [LICENSE](LICENSE). The residential modules that a Basilisk
stack pulls aboard carry their own licenses and terms, legible at
their respective provenances.

## Origin of record

The origin of record for these ship's blueprints is maintained at the
lair of **Gornskew Enterprises**, and real-time mirrored to
[github.com/gornskew/basilisk](https://github.com/gornskew/basilisk).
Public Complaints, Observations, and Blueprint Contributions may be
lodged against the github mirror.
