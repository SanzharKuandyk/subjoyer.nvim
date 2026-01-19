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

vim.api.nvim_create_user_command('SubjoyerShow', function()
  require('subjoyer').show()
end, {
  desc = 'Show subtitle display window',
})

vim.api.nvim_create_user_command('SubjoyerHide', function()
  require('subjoyer').hide()
end, {
  desc = 'Hide subtitle display window',
})

vim.api.nvim_create_user_command('SubjoyerToggleDisplay', function()
  require('subjoyer').toggle_display()
end, {
  desc = 'Toggle subtitle display visibility',
})

vim.api.nvim_create_user_command('SubjoyerStatus', function()
  require('subjoyer').print_status()
end, {
  desc = 'Show connection and plugin status',
})

vim.api.nvim_create_user_command('SubjoyerReconnect', function()
  require('subjoyer').reconnect()
end, {
  desc = 'Reconnect to WebSocket server',
})

vim.api.nvim_create_user_command('SubjoyerSetTrack', function(opts)
  require('subjoyer').set_track(opts.args)
end, {
  nargs = 1,
  desc = 'Set track filter (0, 1, all, or [0,1])',
})

vim.api.nvim_create_user_command('SubjoyerSetPosition', function(opts)
  require('subjoyer').set_position(opts.args)
end, {
  nargs = 1,
  complete = function()
    return { 'top', 'bottom' }
  end,
  desc = 'Set bar position (top = above statusline, bottom = below statusline)',
})

vim.api.nvim_create_user_command('SubjoyerDebug', function()
  require('subjoyer').toggle_debug()
end, {
  desc = 'Toggle debug mode',
})
