# Claude Desktop Integration (Linux, macOS, Windows)

How to point Claude Desktop at a running Basalt deployment, so it can
drive the Emacs and Common Lisp images as MCP tools.

This lives in the Basalt repo rather than in `readymacs` because the
config being generated registers **every** server on the roster — the
deployment's services: `console`, `engine-ccl`, `engine-sbcl`, and
whatever services the stack repositories add (an ingress, licensed
engine variants, ...). No single service's repo can write that file,
because none of them knows what else is deployed.

## Prerequisites

- Docker running (Docker Desktop on macOS/Windows, Docker Engine on Linux)
- [Claude Desktop](https://claude.ai/download) installed
- Basalt cloned and a deployment started at least once (see the main README)
- Windows only: [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install)
  with Docker Desktop using the WSL2 backend

## Setup

1. **Start the stack** (if not already running):

   ```bash
   cd ~/projects/basalt
   ./basalt up
   ```

   Wait for the `[SUCCESS] Claude Desktop config ready` message.
   `basalt` detects your platform and writes the appropriate config to
   `mcp/claude_desktop_config.json` — on Linux and macOS it invokes
   `mcp/mcp-exec` directly; on Windows it goes through `wsl`.

2. **Splice the generated config into Claude Desktop's config file:**

   ```bash
   mcp/install-claude-desktop-config
   ```

   It finds the file by platform — Linux `~/.config/Claude/`, macOS
   `~/Library/Application Support/Claude/`, Windows `%APPDATA%\Claude\`
   (reached from WSL as `~/Claude` if you keep such a link, else
   `/mnt/c/Users/YOUR_USERNAME/AppData/Roaming/Claude/`) — or takes the
   path as its one argument. It replaces only this deployment's
   servers: other MCP servers you have registered there, and the
   servers of another deployment on the same host, stay. A backup is
   kept beside the file.

   To do it by hand instead, copy `mcp/claude_desktop_config.json` over
   the file at that location. A copy replaces the whole file, so it
   erases any other servers registered there. From Windows Explorer:
   - Source: `\\wsl$\Ubuntu\home\YOUR_WSL_USER\projects\basalt\mcp\claude_desktop_config.json`
   - Destination: `%APPDATA%\Claude\claude_desktop_config.json`

3. **Restart Claude Desktop** — you should see the roster's MCP servers
   connect, named for the deployment's services:
   - `console` — Emacs Lisp evaluation (the interactive control surface)
   - `engine-ccl` — Common Lisp (CCL) with Gendl
   - `engine-sbcl` — Common Lisp (SBCL) with Gendl

   (Plus any additional services from stack repositories you have
   installed.)

4. **Optional — prime your first session**: paste the contents of
   [`mcp/opening-prompt.md`](../mcp/opening-prompt.md) as your first
   message so the agent bootstraps itself with the environment.

## Daily Usage

The stack must be running for Claude Desktop to use the MCP servers:

```bash
cd ~/projects/basalt
./basalt up -d   # -d for daemon mode (no interactive shell)
```

To stop it:

```bash
cd ~/projects/basalt
./basalt down
```

## What You Can Do

With these MCP servers, Claude Desktop can:

- Evaluate Emacs Lisp code and interact with the Emacs environment
- Evaluate Common Lisp code in SBCL or CCL
- Work with the Gendl geometry kernel for CAD/knowledge-based engineering
- Access documentation and run HTTP requests against the backend services

## Bootstrapping a Session

Optional but recommended: create a Claude Desktop Project and paste
[`PROJECT_INSTRUCTIONS.md`](https://gitlab.genworks.com/genworks/readymacs/-/blob/devo/docs/PROJECT_INSTRUCTIONS.md)
into its custom instructions, so every session starts with the
dashboard/daily-focus routine and safe editing conventions. The same text
works in a Claude Code `CLAUDE.md` or Codex `AGENTS.md`. For a one-shot
alternative, paste [`../mcp/opening-prompt.md`](../mcp/opening-prompt.md)
as your first message.

## Other MCP Clients

Claude Desktop is just one consumer. The same generated configs work for:

- **Claude Code** on the host: `mcp/install-claude-code-config` splices
  `mcp/claude-code-mcp.json` into `~/.claude.json` (restart Claude Code
  afterwards); or copy that file's `mcpServers` block into a `.mcp.json`
  in your project
- **Codex CLI**: `./basalt up` maintains `~/.codex/config.toml` inside
  the container automatically; for a host-side Codex, adapt `mcp/mcp.toml`
- **Grok Build CLI**: the same merged TOML is written into
  `~/.grok/config.toml` (`[mcp_servers.*]`); launch with `grokly` from a
  shell inside the full/aituis image
- **Any MCP-capable client**: point it at `mcp/mcp-exec` with the args
  shown in `mcp/claude_desktop_config.json`

## Merging with Existing MCP Configuration

`mcp/install-claude-desktop-config` merges rather than replaces: it
touches only the `mcpServers` key, and within it only the entries
launched through this clone's `mcp/mcp-exec`. Your other MCP servers
stay, and so do the servers of a second deployment on the same host, as
long as that deployment's `mcp/mcp-exec` still exists on disk — an entry
whose launcher is gone is dropped as stale. Two deployments on one host
therefore each run their own installer once, in either order.

## Cloning to a Different Location

The generated `claude_desktop_config.json` contains the absolute path to
your **Basalt** clone, determined at `./basalt up` time from where you
run the command, so a non-default clone location works automatically. If
you move the clone, regenerate (`./basalt up`) and run
`mcp/install-claude-desktop-config` again: it drops the entries whose
launcher is no longer there and adds the new ones. A config still
pointing at a vanished `mcp-exec` fails quietly, with nothing obviously
wrong in Claude Desktop's UI.

## Troubleshooting

**MCP servers not connecting:**
- Ensure the stack is running (`docker ps` should show the containers)
- Check that the paths in `claude_desktop_config.json` match your Basalt
  clone location
- Restart Claude Desktop after installing the config

**`mcp/claude_desktop_config.json` missing or stale:**
- It is generated; run `./basalt up` and wait for the
  `[SUCCESS] Claude Desktop config ready` message
- If the message doesn't appear, the Emacs daemon may still be starting —
  run `./basalt up` again

**"emacsclient not ready" warning on first start:**
- This is normal — the Emacs daemon takes a few seconds to initialize
- Run `./basalt up` again and the MCP config will generate successfully
