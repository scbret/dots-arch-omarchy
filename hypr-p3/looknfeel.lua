-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- Terminal transparency
 hl.window_rule({
  match = { tag = "terminal" },
  opacity = "0.90 0.75",
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Quake console (Super + grave) size: 65% of usable width, 70% of height.
-- Omarchy's default sizes it with local variables, so this re-applies the same
-- workspace rule after the defaults on the same events. A second window on the
-- console gets the full width back, like the default.
local console_ws = "special:qconsole"
local console_w, console_h = 0.65, 0.70

local function console_fit(monitor)
  if not monitor or not monitor.scale or monitor.scale <= 0 then return end
  local width, height = monitor.width, monitor.height
  if monitor.transform % 2 == 1 then width, height = height, width end
  local r = monitor.reserved
  height = height / monitor.scale - r.top - r.bottom
  width = width / monitor.scale - r.left - r.right

  local tiled = 0
  for _, w in ipairs(hl.get_workspace_windows(console_ws)) do
    if not w.floating then tiled = tiled + 1 end
  end
  local wide = (tiled <= 1) and width * console_w or width
  local tall = height * console_h

  hl.workspace_rule({
    workspace = console_ws,
    gaps_in = 0,
    gaps_out = {
      top = 0,
      right = math.floor((width - wide) / 2),
      bottom = math.floor(height - tall),
      left = math.floor((width - wide) / 2),
    },
    no_border = true,
  })
  hl.exec_scheduled_prop_refresh_immediately()
end

local function console_refit(monitor)
  local ws = hl.get_workspace(console_ws)
  local mon = monitor or (ws and ws.visible and ws.monitor) or hl.get_active_monitor()
  console_fit(mon)
end

console_refit()
hl.on("monitor.layout_changed", function() console_refit() end)
hl.on("monitor.focused", function() console_refit() end)
hl.on("workspace.special_active", function(ws, mon)
  if ws and ws.name == console_ws then console_refit(mon) end
end)
hl.on("workspace.move_to_monitor", function(ws, mon)
  if ws and ws.name == console_ws then console_refit(mon) end
end)
for _, ev in ipairs({ "window.open", "window.destroy", "window.move_to_workspace", "window.update_rules" }) do
  hl.on(ev, function()
    local ws = hl.get_workspace(console_ws)
    if ws and ws.visible then console_refit() end
  end)
end
