---
name: figma-mcp
description: Enable and use the Figma MCP server (figma-developer-mcp / Framelink) PER PROJECT — never globally. Use when the user asks to use Figma MCP, enable figma for this project, connect a Figma design/file/frame URL, read Figma design data, generate UI code from a Figma frame, or download Figma image assets.
---

# Figma MCP — Per-Project Enablement

## Hard rule

**Never set `enabled: true` on the `figma` MCP server in the global config**
(`~/.config/opencode/opencode.jsonc`). It must stay `enabled: false` globally.

Enable it only inside the project that needs it, via a project-level `opencode.json`.

Reason: the figma MCP spawns `npx` on every host start and injects its tools into
every session. Global enable = slow startup + figma tool noise in unrelated projects.

## Global config (canonical, keep as-is)

`~/.config/opencode/opencode.jsonc` holds the server definition with `enabled: false`:

```jsonc
{
  "mcp": {
    "figma": {
      "type": "local",
      "command": ["npx", "-y", "figma-developer-mcp", "--stdio"],
      "environment": { "FIGMA_API_KEY": "{env:FIGMA_API_KEY}" },
      "enabled": false,
      "timeout": 15000
    }
  }
}
```

Do not delete the entry — project configs inherit `command` / `environment` / `timeout` from it.

## Enable for a project

Create `opencode.json` at the **project root**:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "figma": {
      "enabled": true
    }
  }
}
```

That is the whole file. Global `command`, `environment`, `timeout` are deep-merged in;
project `enabled: true` overrides global `enabled: false`.

Equivalent one-liner:

```bash
cat > opencode.json <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": { "figma": { "enabled": true } }
}
EOF
```

### Where the file can live

Accepted project-scoped locations (highest precedence first):

1. `<project>/opencode.json` or `opencode.jsonc` (found walking up from cwd)
2. `<project>/.opencode/opencode.json(c)`

Precedence overall: **project > `OPENCODE_CONFIG` > global > remote**. Project config is
**deep-merged** with global, not replaced.

### One-off / ad-hoc instead of a project file

Put the override in a scratch config and point OpenCode at it (higher precedence than global,
lower than project):

```bash
OPENCODE_CONFIG=/tmp/opencode-figma.json opencode
```

```json
{ "mcp": { "figma": { "enabled": true } } }
```

Other knobs: `OPENCODE_CONFIG_CONTENT` (inline JSON), `OPENCODE_CONFIG_DIR`,
`OPENCODE_DISABLE_PROJECT_CONFIG=1` (ignore project configs entirely).
There is **no `--config` CLI flag**.

### Do not commit secrets

Use `{env:FIGMA_API_KEY}` — never paste a raw `figd_...` token into a project file.
`FIGMA_API_KEY` must be present in the environment that launches OpenCode
(user's shell profile sets it).

## Disable again for a project

Delete the `mcp.figma` block from the project `opencode.json` (or set `"enabled": false`),
then restart OpenCode.

## Restart required

MCP servers are wired up at host start. After adding/changing the project config,
**restart OpenCode fully** (not just a new session), then verify.

## Verify it loaded

Call `list_mcp_resources({ server: "figma" })` — or check that these tools exist:

- `figma_get_figma_data`
- `figma_download_figma_images`

Tool name prefix comes from the server key (`figma`). Remote tools may be namespaced
as `mcp__figma__get_figma_data` in some clients.

## Using it

Pass a Figma URL; the server extracts `fileKey` and `nodeId` itself.

URL forms accepted:

- `https://www.figma.com/design/<fileKey>/<name>?node-id=12-345`
- `https://www.figma.com/file/<fileKey>/<name>?node-id=12-345`
- `https://www.figma.com/board/<fileKey>/<name>?...`

Tools:

- **get_figma_data** — args: `fileKey` (required), `nodeId` (optional), `depth` (optional).
  Returns simplified layout + style data, not raw Figma JSON.
- **download_figma_images** — args: `fileKey`, `nodes` (list of `{ nodeId, imageRef }`),
  `localPath`. Renders PNG/SVG assets to disk.

**Gotcha:** in the URL, `node-id` uses a dash (`12-345`). The API expects a colon
(`12:345`). The MCP server normalizes this — but if a node lookup returns empty,
convert the dash to a colon manually.

## Env vars understood by the server

| Var | Purpose |
|-----|---------|
| `FIGMA_API_KEY` | Figma personal access token (required) |
| `OUTPUT_FORMAT` | `yaml` (default) or `json` |
| `PORT` | only for HTTP transport, unused with `--stdio` |

## Gotchas

- `timeout: 15000` (15s) is short. Very large files/frames can time out — raise it in the
  project config (`"timeout": 60000`) if `get_figma_data` dies on big nodes.
- Install is `npx -y figma-developer-mcp` — first run downloads the package; add time on
  a cold cache.
- This is **Framelink / figma-developer-mcp** (REST API + token). It is *not* Figma's
  official Dev Mode MCP server (which requires the Figma desktop app).
- Large frames blow up context. Fetch a specific frame/node, not the whole file.
- Per-agent restriction is possible instead of project scoping, but is coarser — prefer
  project files. If needed: agent `permission` rules keyed on `figma_<tool>`.

## Source of truth

- OpenCode config: https://opencode.ai/docs/config/#precedence-order
- OpenCode MCP: https://opencode.ai/docs/mcp-servers/
- Framelink: https://github.com/GLips/Figma-Context-MCP
