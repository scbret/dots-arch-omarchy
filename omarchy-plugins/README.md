# Omarchy Plugins

Personal Omarchy shell plugins shared across my Omarchy PCs via `~/dots-arch-omarchy`.

| Plugin folder | Plugin ID | Where it goes on each PC | How |
|---|---|---|---|
| `steve.ai-usage/` | `steve.ai-usage` | `~/.config/omarchy/plugins/steve.ai-usage` | Symlink, so `git pull` updates it |
| `steve.spotify/` | `steve.spotify` | `~/.config/omarchy/plugins/steve.spotify` | Symlink, so `git pull` updates it |

## Included Plugins

### `steve.ai-usage`

ClaudeBar-style bar widget and dropdown popover for monitoring **Antigravity** (`agy`) and **Claude Code** (`claude`) subscription quotas.

- **Bar readout**: Inline color-coded 5-hour session and 7-day weekly `% remaining` (`AG 100/100% · CL 98/74%`), with a compact vertical-bar fallback.
- **Health colors**: Green (`> 40%` remaining), yellow (`16–40%` remaining), red (`<= 15%` remaining), derived from the active Omarchy theme's ANSI colors (`color2`, `color3`, `color1`).
- **Popover**: Left-click opens a native Omarchy `KeyboardPanel` with plan tier badges, animated remaining-quota fuel bars, exact `% remaining`, reset countdowns, model-scoped sub-limits when present, last-updated time, and a manual refresh button (`R`).
- **Refresh & network access**: Runs `steve.ai-usage/refresh-quotas.py` automatically every hour (`refreshIntervalSec: 3600`, configurable in `shell.json`). Claude refreshes via Omarchy's built-in `omarchy-agent-usage-update --limits-only claude`; Antigravity queries `https://daily-cloudcode-pa.googleapis.com/v1internal:loadCodeAssist` and `retrieveUserQuotaSummary` (with an 8-second timeout, 512 KB response cap, and `User-Agent: antigravity/hub/2.24.0` so Google includes the `Gemini Models` 5-hour and weekly buckets) and writes `~/.local/state/omarchy/steve-ai-usage/agy.json`. Right-click or middle-click the bar widget (or press `R` inside the popover) to force an immediate refresh.
- **Default placement**: Left bar section, after `omarchy.workspaces`.

### `steve.spotify`

Lightweight Spotify-only "Now Playing" bar widget driven by MPRIS. See [steve.spotify/README.md](steve.spotify/README.md) for controls and plugin-specific details.

- **Bar readout**: Spotify icon + `Title · Artist` (auto-hides when Spotify is not playing a track; icon dims when paused).
- **Controls**: Left-click play/pause, middle-click next track, right-click Spotify, scroll up/down prev/next.
- **Default placement**: Left bar section.

## Set up on an Omarchy PC

```bash
# 1. Get or update the dots-arch-omarchy repo
[ -d ~/dots-arch-omarchy ] || git clone https://github.com/scbret/dots-arch-omarchy.git ~/dots-arch-omarchy
git -C ~/dots-arch-omarchy pull --ff-only

# 2. Ensure the Omarchy plugins directory exists
mkdir -p ~/.config/omarchy/plugins

# 3. Link plugins (back up any existing non-symlink directories first)
for plugin in steve.ai-usage steve.spotify; do
  target="$HOME/.config/omarchy/plugins/$plugin"
  [ -e "$target" ] && [ ! -L "$target" ] && mv "$target" "$target.bak"
  ln -sfn "$HOME/dots-arch-omarchy/omarchy-plugins/$plugin" "$target"
done

# 4. Discover and enable the plugins you want on the bar
omarchy-shell shell rescanPlugins
omarchy plugin enable steve.ai-usage
omarchy plugin enable steve.spotify
```

## Updating

Edit any plugin under `~/dots-arch-omarchy/omarchy-plugins/`, commit and push to `main`, then `git pull` in `~/dots-arch-omarchy` on your other PCs. Because `~/.config/omarchy/plugins/<id>` is a symlink, run:

```bash
omarchy-shell shell rescanPlugins
```

(or `omarchy restart shell` if QML changes inside a symlinked folder need a full reload).

## Validation and Tests

```bash
# Validate plugin manifests and folders against Omarchy's schema
omarchy plugin validate ~/dots-arch-omarchy/omarchy-plugins/steve.ai-usage
omarchy plugin validate ~/dots-arch-omarchy/omarchy-plugins/steve.spotify

# Run unit and UI-safety regression tests
python3 -B -m unittest discover -s ~/dots-arch-omarchy/omarchy-plugins/tests -v
```

## Adding More Plugins Later

Create a new sibling folder `steve.<name>/` with a `manifest.json`, add a row to the table above, validate it with `omarchy plugin validate`, and symlink it into `~/.config/omarchy/plugins/steve.<name>`.
