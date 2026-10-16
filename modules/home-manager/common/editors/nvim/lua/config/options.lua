-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()

vim.opt.relativenumber = false
vim.g.autoformat = false
-- LazyVim 对 markdown 等文本类文件默认开启 spell，且 spelllang 只有 "en"，
-- 中文整片不在英文词表里会被标成 SpellBad 波浪线；加 cjk 让 CJK 字符免检
vim.opt.spelllang = { "en", "cjk" }
