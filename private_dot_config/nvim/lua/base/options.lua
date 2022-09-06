-- Settings
local opt = vim.opt
opt.syntax = 'on'
opt.errorbells = false
opt.smartcase = true
opt.showmode = true
opt.backup = false
opt.undofile = true
opt.incsearch = true
opt.hidden = true
opt.completeopt='menuone,noinsert,noselect'
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.number = true
opt.relativenumber = true

-- Colorscheme
opt.termguicolors = true
opt.background = 'light'

-- activate dracula theme
vim.cmd [[colorscheme dracula]]

local bo = vim.bo
bo.swapfile = false
bo.autoindent = true
bo.smartindent = true

local wo = vim.wo
wo.signcolumn = 'yes'
wo.wrap = false

