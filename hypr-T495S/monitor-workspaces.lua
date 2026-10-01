-- Each output has ten independent workspace slots (shown as 1-10 in the bar).
-- Stable connector-based ranges survive reconnects: top 1-10, bottom 11-20,
-- laptop 21-30. Hyprland migrates existing windows when outputs disconnect.
local offsets = { ["DP-3"] = 0, ["DP-4"] = 10, ["eDP-1"] = 20 }
for output, offset in pairs(offsets) do
  for slot = 1, 10 do
    hl.workspace_rule({ workspace = tostring(offset + slot), monitor = output, default = slot == 1 })
  end
end

local function workspace_action(slot, move, silent)
  return function()
    local monitor = hl.get_active_monitor()
    if not monitor then return end
    local offset = offsets[monitor.name] or 0
    local target = tostring(offset + slot)
    if move then
      hl.dispatch(hl.dsp.window.move({ workspace = target, follow = not silent }))
    else
      hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
  end
end

-- Replace the stock global-number switch/move shortcuts with monitor-local slots.
for slot = 1, 10 do
  local key = "code:" .. tostring(slot + 9)
  for _, prefix in ipairs({ "SUPER + ", "SUPER + SHIFT + ", "SUPER + SHIFT + ALT + " }) do
    hl.unbind(prefix .. key)
  end
  o.bind("SUPER + " .. key, "Switch to local workspace " .. slot, workspace_action(slot, false, false))
  o.bind("SUPER + SHIFT + " .. key, "Move window to local workspace " .. slot, workspace_action(slot, true, false))
  o.bind("SUPER + SHIFT + ALT + " .. key, "Move window silently to local workspace " .. slot, workspace_action(slot, true, true))
end

-- Cycle only workspaces on the focused monitor, including migrated workspaces.
for _, binding in ipairs({
  { "SUPER + TAB", "Next workspace on this monitor", "m+1" },
  { "SUPER + SHIFT + TAB", "Previous workspace on this monitor", "m-1" },
  { "SUPER + CTRL + TAB", "Former workspace on this monitor", "previous_per_monitor" },
  { "SUPER + mouse_down", "Next workspace on this monitor", "m+1" },
  { "SUPER + mouse_up", "Previous workspace on this monitor", "m-1" },
}) do
  hl.unbind(binding[1])
  o.bind(binding[1], binding[2], hl.dsp.focus({ workspace = binding[3] }))
end
