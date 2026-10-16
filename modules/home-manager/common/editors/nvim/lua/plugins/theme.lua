-- 取自 omarchy 的 themes/catppuccin/neovim.lua（Omarchy 3.8 遗留格式）。上游把
-- colorscheme 写成 "catppuccin-nvim"，但 catppuccin 注册的配色名是 catppuccin /
-- catppuccin-frappe 等，LazyVim 会因 pcall 失败而回落到 tokyonight，故在此修正。
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    -- 亮/暗跟随桌面：读 theme-apply 翻软链过来的那份 mode 文件（见本文件下面 opts 的
    -- 注释），据此设 vim.o.background，再让 catppuccin 的 flavour="auto" 自己选
    -- frappe / latte。两个名字只在模块里写一次：appearance.switchTargets。
    opts = function()
      local ok, mode = pcall(dofile, vim.fn.expand("~/.config/theme-variants/nvim/mode.lua"))
      if ok and (mode == "light" or mode == "dark") then
        vim.o.background = mode
      end
      return {
        -- auto = 按 vim.o.background 选（catppuccin 的约定）
        flavour = "auto",
      }
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
