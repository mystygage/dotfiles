-- Try some key mappings, see
-- https://bryankegley.me/posts/nvim-getting-started/

local silent = { silent = true, noremap = true }
local map = vim.api.nvim_set_keymap

-- map('', '<up>', '<nop>', silent)
-- map('', '<down>', '<nop>', silent)
-- map('', '<left>', '<nop>', silent)
-- map('', '<right>', '<nop>', silent)
map('i', 'jk', '<ESC>', silent)
map('i', 'JK', '<ESC>', silent)
map('i', 'jK', '<ESC>', silent)
map('v', 'jk', '<ESC>', silent)
map('v', 'JK', '<ESC>', silent)
map('v', 'jK', '<ESC>', silent)
