-- 让 LazyVim 用 Nix 装在 PATH 上的 LSP，而不是让 mason 在运行时联网下载。
--
-- LazyVim 默认把每个语言服务器都挂在 mason.nvim 名下（lsp/init.lua 里对能装的
-- server 调 mason-lspconfig.setup，由它 vim.lsp.enable）。mason 只会启用自己装进
-- ~/.local/share/nvim/mason 的二进制，PATH 上的（gopls/clangd/nil/…）被跳过，
-- 于是「语言不支持」——实际是 mason 拿不到、又没回退到 Nix 提供的那份。
-- servers.*.mason=false 让 LazyVim 走 else 分支直接 vim.lsp.enable，用 PATH 上的。
-- 连 * 一起关，避免任何 server 再进 mason 的运行时下载。对应命令由各 lang extra
-- 声明、二进制由 cli/dev/*.nix 提供，两边各自独立、都需要在。
--
-- 系统级装齐了配套二进制：typescript-language-server→ts_ls、pylsp/python-lsp-server、
-- gopls、clangd、nil、marksman、docker-compose-language-service、taplo、
-- vscode-langservers-extracted→jsonls/yamlls。缺的话补进对应的 cli/dev 模块。
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      for name, server in pairs(opts.servers) do
        if name ~= "*" and type(server) == "table" then
          server.mason = false
        end
      end
      -- lang.typescript 默认走 vtsls（本机没有）；改用系统已装的 tsserver，
      -- 免得为同样的能力再多一个包。
      local ts = opts.servers.ts_ls or opts.servers.tsserver
      if ts then
        ts.enabled = true
      end
      if opts.servers.vtsls then
        opts.servers.vtsls.enabled = false
      end
    end,
  },
}
