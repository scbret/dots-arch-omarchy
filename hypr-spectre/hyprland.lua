-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
--
-- Place apps on a per-monitor workspace slot (1-10) so they match SUPER+<n>
-- on whichever monitor is active, whether docked or undocked.
_G._steve_app_workspace_slots = {
  ["Spotify"] = 9,
  ["org.mozilla.Thunderbird"] = 4,
}

if not _G._steve_app_workspace_hook then
  _G._steve_app_workspace_hook = true
  hl.on("window.open", function(window)
    if not window or not window.class then return end
    local slot = _G._steve_app_workspace_slots[window.class]
    if not slot then return end

    local monitor = window.monitor or hl.get_active_monitor()
    if not monitor then return end

    local id = o.workspaces.workspace_id(monitor, slot)
    if window.workspace and window.workspace.id == id then return end

    hl.dispatch(hl.dsp.window.move({
      workspace = tostring(id),
      follow = true,
      window = "address:" .. window.address,
    }))
  end)
end
