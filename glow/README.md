# Glow config

Shared Glow (terminal Markdown renderer) configuration, used across my Omarchy PCs via `~/dots-arch-omarchy`.

| File in this repo | Where it goes on each PC | How |
|---|---|---|
| `glow/glow.yml` | `~/.config/glow/glow.yml` | Symlink, so `git pull` updates it |

## Settings

- `style: "auto"` picks a light or dark style to match the terminal.
- `pager: true` pages through a file by default, so `-p` is not needed.
- `mouse: true` enables the mouse in the file browser (run `glow` alone in a folder).
- `width: 80` word-wraps at 80 columns.
- `all: false` hides hidden and ignored files in the browser.

## Set up on an Omarchy PC

```bash
# 1. Install Glow if needed
omarchy pkg present glow || omarchy pkg add glow

# 2. Get or update the dots-arch-omarchy repo
[ -d ~/dots-arch-omarchy ] || git clone https://github.com/scbret/dots-arch-omarchy.git ~/dots-arch-omarchy
git -C ~/dots-arch-omarchy pull --ff-only

# 3. Link the config (back up any existing non-symlink file first)
mkdir -p ~/.config/glow
[ -e ~/.config/glow/glow.yml ] && [ ! -L ~/.config/glow/glow.yml ] && mv ~/.config/glow/glow.yml ~/.config/glow/glow.yml.bak
ln -sfn ~/dots-arch-omarchy/glow/glow.yml ~/.config/glow/glow.yml

# 4. Verify
ls -l ~/.config/glow/glow.yml
```

## Updating

Edit `~/dots-arch-omarchy/glow/glow.yml` on any PC, commit and push to `main`, then `git pull` in `~/dots-arch-omarchy` on the other PCs. No re-linking needed.
