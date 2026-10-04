# Session Start - Bootstrap with Context

Suggested opening prompt for an AI agent connected to a Basilisk over
MCP. Paste this (or adapt it) into a fresh session with Claude Desktop,
Claude Code, Codex, or any MCP-capable client.

The MCP servers are named for the ship's rooms: `ready-room` (Emacs —
the ship's console), `bridge` and `engine-room` (Common Lisp
with Gendl), plus whatever extra rooms this ship carries
(`transporter-room`, `guild-workshop`, ...).

## Step 1: Read the Primer
**First, read the ready room's short guide:**

Call: `ready-room:ready-room__get_docs(id="primer")`

It says how to work through the ready room's Emacs -- which is the
house's tool for reading, searching and editing workspace files, not
only Lisp -- and the few rules that keep the daemon answering.  Then
evaluate `(lisply-help)` once to see the file helpers you will use in
place of cat, grep and sed.

## Step 2: Review the Dashboard
**Now use your basic elisp skills to check current context:**

**Dashboard** (shows environment status, services, recent activity):
```elisp
(with-current-buffer "*dashboard*" (buffer-string))
```

**Daily Focus** (org-mode agenda of priorities, if the user has set it up
with `M-x skewed-daily-focus-init`):
```elisp
(progn
  (org-agenda nil "d")
  (with-current-buffer "*Org Agenda*" (buffer-string)))
```

The Daily Focus shows Must/Should/Could priorities. This tells you
what's in flight. If it is empty or errors, the user hasn't set it up —
that's fine; skip it.

## Step 3: The References, When You Need Them
The primer covers everyday work.  The longer ready-room references are
for cases it does not: `ready-room:ready-room__get_docs(id="claude-md")`
(paredit, structural editing in depth, recovering an unbalanced file)
and `id="main-claude-md"` (the room itself, its images, recovery
runbooks).

**If working with Gendl/Common Lisp backends, also read the docs for
that backend** (the Dashboard lists the Lisply backends aboard — the
bridge and the engine room in the standard rig, plus any rooms
an overlay adds):
```
bridge:bridge__get_docs(id="claude-md")
```

## Step 4: Present Options to the User
Based on the Dashboard (and Daily Focus if present), present:

1. **Current state** - which services/backends are up and healthy
2. **Suggested next steps** - informed by any priorities you found
3. **Questions** - anything unclear before starting work

## Quick Reference
- **Org files (if Daily Focus is set up)**: `/projects/org/projects.org` in-container
  (`~/projects/org/projects.org` on the host)
- **Navigate via agenda**: use `org-agenda-goto` from the *Org Agenda*
  buffer to jump to a task's full entry (look for :HOST:, :NOTES:, or
  LOGBOOK context)
