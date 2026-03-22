return {
  "levouh/tint.nvim",
  event = "WinNew",
  opts = {
    tint = -55, -- how much to dim (-100 = black, 0 = no change)
    saturation = 0.7, -- reduce saturation in inactive windows
  },
}
