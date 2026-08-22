-- Masks secrets in .env files: everything after `=` renders as `*`.
--
-- Display-only. The masking is drawn with extmarks over the real text, so the
-- buffer bytes are untouched and `:w` writes the file exactly as it was read.
--
-- Two ways back to the plaintext: <leader>tc flips the whole buffer, and
-- <leader>tv uncloaks only the line under the cursor until the cursor leaves it.
return {
  "laytan/cloak.nvim",
  event = { "BufReadPre .env*", "BufNewFile .env*" },
  opts = {
    cloak_character = "*",
    highlight_group = "Comment",
    patterns = {
      -- `.dev.vars` is wrangler's local secrets file -- same shape as .env.
      { file_pattern = { ".env*", ".dev.vars" }, cloak_pattern = "=.+" },
    },
  },
  keys = {
    { "<leader>tc", "<cmd>CloakToggle<cr>", desc = "Toggle .env cloak" },
    { "<leader>tv", "<cmd>CloakPreviewLine<cr>", desc = "Reveal .env line under cursor" },
  },
}
