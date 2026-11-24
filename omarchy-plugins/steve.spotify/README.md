# steve.spotify

Lightweight Spotify-only "Now Playing" bar widget for the Omarchy shell, shared across PCs via `~/dots-arch-omarchy/omarchy-plugins/steve.spotify`.

## Features

- Displays a Spotify icon plus `Track · Artist` in the Omarchy status bar whenever Spotify has an active MPRIS track (auto-hides when Spotify is closed or idle).
- Dims the Spotify icon when paused.
- Collapses to the icon on vertical bars.

## Controls

| Action | Behavior |
|---|---|
| Left-click | Play / Pause |
| Middle-click | Next track |
| Right-click | Launch / focus Spotify |
| Scroll up / down | Previous / Next track |
| Hover | Tooltip with full `Title — Artist` |

## Set up on another Omarchy PC

```bash
# 1. Get or update the dots-arch-omarchy repo
[ -d ~/dots-arch-omarchy ] || git clone https://github.com/scbret/dots-arch-omarchy.git ~/dots-arch-omarchy
git -C ~/dots-arch-omarchy pull --ff-only

# 2. Ensure the Omarchy plugins directory exists
mkdir -p ~/.config/omarchy/plugins

# 3. Link steve.spotify (back up any existing non-symlink directory first)
[ -e ~/.config/omarchy/plugins/steve.spotify ] && [ ! -L ~/.config/omarchy/plugins/steve.spotify ] && mv ~/.config/omarchy/plugins/steve.spotify ~/.config/omarchy/plugins/steve.spotify.bak
ln -sfn ~/dots-arch-omarchy/omarchy-plugins/steve.spotify ~/.config/omarchy/plugins/steve.spotify

# 4. Discover and enable the plugin (defaults to the left bar section)
omarchy-shell shell rescanPlugins
omarchy plugin enable steve.spotify
```

## Updating on other PCs

```bash
git -C ~/dots-arch-omarchy pull --ff-only
omarchy-shell shell rescanPlugins
```

If QML changes do not hot-reload across the symlink, run `omarchy restart shell`.

## Disabling / Validation

```bash
# Disable from the bar (keeps the plugin installed)
omarchy plugin disable steve.spotify

# Validate manifest and plugin folder
omarchy plugin validate ~/dots-arch-omarchy/omarchy-plugins/steve.spotify
```
