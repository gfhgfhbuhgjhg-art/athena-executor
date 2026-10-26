# Athena Explorer

A Studio-style DataModel explorer for Roblox executors, plus a self-contained
copy of the `roblox-executor-mcp` client so an AI agent (OpenCode / Claude /
Cursor) can read and run code in the same game.

```
athena-explorer/
  Athena.lua           ONE FILE - explorer + MCP connector, paste this
  AthenaExplorer.lua   explorer only (loads MCP by itself)
  connector.luau       roblox-executor-mcp client, offline build
  loader.lua           loads connector + explorer from disk
  LuaEncode.lua        helper library used by the connector (MIT)
  push.ps1             push this folder to GitHub once you have a token
```

## Already installed on this PC

Copied to the Athena workspace (`C:\Users\bob\AppData\Local\athena\workspace\Athena\`):

```
Athena.lua  connector.luau  loader.lua
```

and `autoexec\zz_openCode_mcp.lua` now starts it on every inject and writes a
log to `workspace\Athena\diag.txt`. So after the next inject you can just read
that file to see exactly what happened.

## The 3 ways to run it

### A. Paste (no loadstring, no http, nothing to break)

Open `Athena.lua` in a text editor, select all, paste into the executor's
script box, press Execute. Done. This is the version to use if `loadstring`
has been failing - it does not load anything from anywhere.

### B. One line, from the Athena workspace

```lua
loadstring(readfile("Athena/Athena.lua"))()
```

`readfile` paths are relative to the executor workspace
(`C:\Users\bob\AppData\Local\athena\workspace`), so this is the short form.
Absolute paths also work in `loader.lua`, which tries the workspace first.

### C. From GitHub (after you push)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/Athena.lua"))()
```

## Explorer features

- Full `game` tree, lazy expansion, 1500 row cap
- Search by name or class
- Property + attribute inspector (click a value to copy it)
- Copy path / name / source, teleport to a selected BasePart
- **Highlight** - select a Folder / Model / Part in Workspace and click
  Highlight to outline every part inside (through walls, 200 object cap)
- **Open GUI** - select any ScreenGui, Frame, TextLabel or a folder of GUIs and
  click Open GUI. Live GUIs are enabled, non-live ones are cloned into
  PlayerGui, bare frames get a preview ScreenGui, hidden parents are revealed.
  Close GUI removes the clones and restores the previous state.
- Drag the title bar, resize from the bottom-right corner, RightShift toggles

## MCP

`Athena.lua` starts the connector in a spawned thread, so a missing bridge can
never block the UI. Check <http://localhost:16384/> - the "clients" list should
show this game. Then an agent can run code here.

## Why `loadstring(game:HttpGet("http://localhost:16384/script.luau"))()` fails

The official snippet is fine, but it fails silently:

1. The connector sets `getgenv().MCP_Loaded = true` **before** it connects.
   The official loader loops `while not getgenv().MCP_Loaded`, so it stops
   looping even when the connection later fails. Nothing is retried and
   nothing is printed.
2. The connector downloads `LuaEncode.lua` from
   `raw.githubusercontent.com` at startup. If that request is blocked, the
   chunk aborts after `MCP_Loaded` is already true.
3. The connector requires a real `WebSocket` global and connects to
   `ws://localhost:16384` with a 5 second timeout. If the executor has no
   WebSocket, it throws at that point.
4. `getgenv().BridgeURL` may already be set to a value with a path or scheme;
   naive `"http://" .. BridgeURL` concatenation then produces a bad URL.

This repo removes cause 2 (LuaEncode is embedded in both `connector.luau` and
`Athena.lua`), reports causes 1 and 3 (`loader.lua` resets `MCP_Loaded`, wraps
every step in `pcall` and prints the real error), and tries both `127.0.0.1`
and `localhost` (cause 4).

## If it still does not connect

Run `loader.lua` and read the `[athena]` lines in the executor console:

| Line | Meaning |
| --- | --- |
| `connector runtime error: WebSocket connection timed out` | executor has no WebSocket support, or something blocks loopback |
| `connector runtime error: Failed to connect to bridge server after 10 attempts` | the bridge is not listening on 16384 |
| `HttpGet 127.0.0.1:16384 failed` | loopback HTTP is blocked; the disk connector still works |
| `bridge clients now: 0` | connector started but never registered |

If loopback HTTP is blocked but WebSocket works, the disk connector still
works because it never fetches the script over HTTP.

## Pushing to GitHub

```powershell
cd C:\Users\bob\Documents\athena-explorer
.\push.ps1 -Token ghp_xxxxxxxx -Repo athena-explorer
```

The script creates the repo with the GitHub API, adds the remote and pushes.
A token with `repo` scope is enough. Nothing is uploaded until you run it.

## Credits

- `connector.luau` comes from
  [roblox-executor-mcp](https://github.com/dissering/roblox-executor-mcp) by
  dissering / upio (notpoiu), MIT.
- `LuaEncode.lua` by Chad Hyatt, MIT.
