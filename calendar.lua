return {
  {
    "mattn/calendar-vim",
    cmd = { "Calendar", "CalendarH", "CalendarVR", "CalendarT" }, -- load only when needed
    keys = {
      { "<leader>oc", "<cmd>Calendar<cr>", desc = "Open Calendar" },
      { "<leader>oh", "<cmd>CalendarH<cr>", desc = "Horizontal Calendar" },
      { "<leader>ov", "<cmd>CalendarVR<cr>", desc = "Vertical Calendar" },
      { "<leader>ot", "<cmd>CalendarT<cr>", desc = "Calendar in Tab" },
    },
    init = function()
      -- optional settings for appearance
      vim.g.calendar_frame = "topleft" -- "rightbelow" -- or "topleft" / "botright"
      vim.g.calendar_width = 40
      vim.g.calendar_height = 15
      -- if you want Monday as the first day:
      vim.g.calendar_week_number = 1
      vim.g.calendar_weeknm = 1
    end,
  },
}
