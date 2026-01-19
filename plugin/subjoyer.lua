-- subjoyer.nvim - Plugin commands
-- Prevent loading twice
if vim.g.loaded_subjoyer then
  return
end
vim.g.loaded_subjoyer = true

-- Create user commands
vim.api.nvim_create_user_command('SubjoyerStart', function()
  require('subjoyer').start()
end, {
  desc = 'Start receiving subtitles from asbplayer-streamer',
})

vim.api.nvim_create_user_command('SubjoyerStop', function()
  require('subjoyer').stop()
end, {
  desc = 'Stop receiving subtitles',
})

vim.api.nvim_create_user_command('SubjoyerToggle', function()
  require('subjoyer').toggle()
end, {
  desc = 'Toggle subtitle reception on/off',
})

vim.api.nvim_create_user_command('SubjoyerStatus', function()
  require('subjoyer').print_status()
end, {
  desc = 'Show plugin status',
})

-- Anki mining command (asbplayer integration)
vim.api.nvim_create_user_command('SubjoyerMineAnki', function()
  require('subjoyer').mine_anki()
end, {
  desc = 'Create Anki note from current subtitle',
})
