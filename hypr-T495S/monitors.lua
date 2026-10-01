-- Display rules only apply while the corresponding monitor is connected.
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Dell U2415 displays: DP-3 above DP-4, aligned at the left edge.
-- At 1.25 scale each 1200-pixel display occupies 960 logical pixels vertically.
hl.monitor({ output = "DP-3", mode = "1920x1200@59.95", position = "0x0", scale = omarchy_monitor_scale })
hl.monitor({ output = "DP-4", mode = "1920x1200@59.95", position = "0x960", scale = omarchy_monitor_scale })

-- Automatically place the laptop panel when open, including when undocked.
-- Omarchy's default lid bindings and monitor watcher disable it while the
-- lid is closed with an external display active, and restore it on lid open.
-- Keep this rule enabled: the clamshell override is loaded after this file.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
