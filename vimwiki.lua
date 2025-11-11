return {
  {
    "vimwiki/vimwiki",
    cmd = { "VimwikiIndex", "VimwikiTabIndex", "VimwikiDiaryIndex", "VimwikiMakeDiaryNote", "VimwikiUISelect" },
    init = function()
      -- use Markdown-based wiki
      vim.g.vimwiki_list = {
        { path = "~/repos/vimwiki", syntax = "markdown", ext = ".md" },
      }
      vim.g.vimwiki_global_ext = 0 -- only treat files under listed paths as wiki
    end,
    keys = {
      { "<leader>ww", "<cmd>VimwikiIndex<cr>", desc = "Vimwiki index" },
      { "<leader>wt", "<cmd>VimwikiTabIndex<cr>", desc = "Vimwiki index (tab)" },
    },
  },
}
