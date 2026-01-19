-- subjoyer.nvim - Main plugin module
local M = {}

local config = require('subjoyer.config')
local websocket = require('subjoyer.websocket')
local display = require('subjoyer.display')
local renderer = require('subjoyer.renderer')

-- Plugin state
M.is_started = false

-- Setup plugin with user configuration
function M.setup(user_config)
  -- Initialize configuration
  config.setup(user_config or {})
  local cfg = config.get()

  -- Setup incline display
  local ok = display.setup(cfg)
  if not ok then
    vim.notify('[subjoyer] Failed to setup incline.nvim integration', vim.log.levels.ERROR)
    return
  end

  -- Setup callbacks
  M.setup_callbacks()

  -- Setup autocommands
  M.setup_autocommands()

  -- Auto-start if configured
  if cfg.behavior.auto_start then
    vim.defer_fn(function()
      M.start()
    end, 100)
  end
end

-- Setup WebSocket callbacks
function M.setup_callbacks()
  local cfg = config.get()

  -- Server ready (silent unless debug)
  websocket.on('ready', function(data)
    if cfg.behavior.debug then
      vim.notify(
        string.format('[subjoyer] Server ready on %s:%d', data.host, data.port),
        vim.log.levels.INFO
      )
    end
  end)

  -- Extension connected (silent unless debug)
  websocket.on('connected', function(data)
    if cfg.behavior.debug then
      vim.notify(
        string.format('[subjoyer] Extension connected (v%s)', data.version or 'unknown'),
        vim.log.levels.INFO
      )
    end
  end)

  -- Extension disconnected (silent - not an error)
  websocket.on('disconnected', function(_)
    -- Disconnection is normal, only log in debug mode
    if cfg.behavior.debug then
      vim.notify('[subjoyer] Extension disconnected', vim.log.levels.INFO)
    end
  end)

  -- Error occurred (only show critical errors)
  websocket.on('error', function(error_msg)
    -- Only show if debug mode (websocket.lua already filtered it)
    if cfg.behavior.debug then
      vim.notify('[subjoyer] Error: ' .. error_msg, vim.log.levels.ERROR)
    end
  end)

  -- Subtitle received (silent - just update display)
  websocket.on('subtitle', function(data)
    M.handle_subtitle(data)
  end)
end

-- Setup autocommands
function M.setup_autocommands()
  local cfg = config.get()

  -- Create augroup
  local group = vim.api.nvim_create_augroup('Subjoyer', { clear = true })

  -- Hide on insert mode
  if cfg.behavior.hide_on_insert then
    vim.api.nvim_create_autocmd('InsertEnter', {
      group = group,
      callback = function()
        display.hide()
      end,
    })

    vim.api.nvim_create_autocmd('InsertLeave', {
      group = group,
      callback = function()
        if M.is_started then
          display.show(cfg)
        end
      end,
    })
  end

  -- Cleanup on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.stop()
    end,
  })
end

-- Handle subtitle data
function M.handle_subtitle(data)
  local cfg = config.get()

  -- Check if updates should be paused
  if cfg.video.pause_updates and data.video and data.video.paused then
    return
  end

  -- Render subtitle
  local formatted_lines = renderer.render(data, cfg)

  -- Update display
  display.update(formatted_lines, cfg)
end

-- Start receiving subtitles
function M.start()
  if M.is_started then
    return
  end

  local cfg = config.get()

  -- Start WebSocket server
  websocket.start(cfg)

  -- Show display
  if cfg.display.enabled then
    display.show(cfg)
  end

  M.is_started = true
end

-- Stop receiving subtitles
function M.stop()
  if not M.is_started then
    return
  end

  -- Stop WebSocket server
  websocket.stop()

  -- Hide display
  display.hide()

  M.is_started = false
end

-- Toggle plugin on/off
function M.toggle()
  if M.is_started then
    M.stop()
  else
    M.start()
  end
end

-- Show display bar
function M.show()
  local cfg = config.get()
  display.show(cfg)
end

-- Hide display bar
function M.hide()
  display.hide()
end

-- Toggle display visibility
function M.toggle_display()
  local cfg = config.get()
  display.toggle(cfg)
end

-- Get connection status
function M.status()
  local ws_status = websocket.status()
  return {
    plugin_started = M.is_started,
    server_running = ws_status.is_running,
    display_visible = display.is_visible_func(),
    job_id = ws_status.job_id,
    reconnect_count = ws_status.reconnect_count,
  }
end

-- Print status
function M.print_status()
  local status = M.status()
  local cfg = config.get()

  local lines = {
    'subjoyer.nvim Status:',
    '  Plugin: ' .. (status.plugin_started and 'Running' or 'Stopped'),
    '  Server: ' .. (status.server_running and 'Running' or 'Stopped'),
    '  Display: ' .. (status.display_visible and 'Visible' or 'Hidden'),
    '  Connection: ' .. cfg.connection.host .. ':' .. cfg.connection.port,
    '  Job ID: ' .. (status.job_id or 'none'),
    '  Reconnects: ' .. status.reconnect_count,
  }

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

-- Reconnect
function M.reconnect()
  websocket.stop()
  vim.defer_fn(function()
    local cfg = config.get()
    websocket.start(cfg)
  end, 100)
end

-- Set track filter
function M.set_track(track)
  -- Parse track input
  local parsed_track
  if track == 'all' then
    parsed_track = 'all'
  elseif tonumber(track) then
    parsed_track = tonumber(track)
  else
    -- Try to parse as JSON array
    local ok, result = pcall(vim.json.decode, track)
    if ok and type(result) == 'table' then
      parsed_track = result
    else
      vim.notify('[subjoyer] Invalid track: ' .. track, vim.log.levels.ERROR)
      return
    end
  end

  -- Update config
  config.update({
    subtitle = {
      tracks = parsed_track,
    },
  })

  -- Refresh display
  display.refresh()

  vim.notify('[subjoyer] Track set to: ' .. vim.inspect(parsed_track), vim.log.levels.INFO)
end

-- Set position (vertical placement)
function M.set_position(position)
  local valid_positions = { 'top', 'bottom' }
  if not vim.tbl_contains(valid_positions, position) then
    vim.notify('[subjoyer] Invalid position: ' .. position .. ' (use: top, bottom)', vim.log.levels.ERROR)
    return
  end

  -- Update config
  config.update({
    incline = {
      options = {
        window = {
          placement = {
            vertical = position,
          },
        },
      },
    },
  })

  -- Need to reload incline for position change
  vim.notify('[subjoyer] Position set to: ' .. position .. ' (restart plugin for effect)', vim.log.levels.INFO)
end

-- Toggle debug mode
function M.toggle_debug()
  local cfg = config.get()
  local new_debug = not cfg.behavior.debug

  config.update({
    behavior = {
      debug = new_debug,
    },
  })

  vim.notify('[subjoyer] Debug: ' .. (new_debug and 'ON' or 'OFF'), vim.log.levels.INFO)
end

return M
